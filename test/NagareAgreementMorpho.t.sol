// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {NagareAgreement} from "../src/NagareAgreementMorpho.sol";
import {INagareAgreement, Agreement} from "../src/interface/INagareAgreement.sol";
import {INagareVerifier} from "../src/interface/INagareVerifier.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "MUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC4626 is ERC4626 {
    uint256 private _yieldRate = 1000; // 10% yield (in basis points)
    uint256 private _totalYield = 0;

    constructor(IERC20 asset_) ERC4626(asset_) ERC20("Mock Vault", "MVT") {}

    function setYieldRate(uint256 newRate) external {
        _yieldRate = newRate;
    }

    function simulateYield() external {
        uint256 currentAssets = IERC20(asset()).balanceOf(address(this));
        uint256 yield = (currentAssets * _yieldRate) / 10000;
        _totalYield += yield;
        MockERC20(asset()).mint(address(this), yield);
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
}

contract MockVerifier is INagareVerifier {
    mapping(uint256 => bool) public shouldApproveCheckpoint;
    mapping(uint256 => bool) public shouldApproveTermination;
    mapping(uint256 => bytes) public registeredContracts;

    function registerAgreement(bytes memory contractInfo, uint256 agreementId) external {
        registeredContracts[agreementId] = contractInfo;
    }

    function verifyCheckpoint(
        uint256 agreementId,
        uint256 checkpointId,
        bytes memory auxiliaryData
    ) external view returns (bool) {
        return shouldApproveCheckpoint[agreementId];
    }

    function verifyTermination(
        uint256 agreementId,
        bytes memory auxiliaryData
    ) external view returns (bool) {
        return shouldApproveTermination[agreementId];
    }

    function setCheckpointApproval(uint256 agreementId, bool approval) external {
        shouldApproveCheckpoint[agreementId] = approval;
    }

    function setTerminationApproval(uint256 agreementId, bool approval) external {
        shouldApproveTermination[agreementId] = approval;
    }
}

contract NagareAgreementMorphoTest is Test {
    NagareAgreement public nagareAgreement;
    MockERC20 public mockUSDC;
    MockERC4626 public mockVault;
    MockVerifier public mockVerifier;

    address public owner = address(this);
    address public client = address(0x1);
    address public contractor = address(0x2);
    address public provider = address(0x3);

    uint256 public constant TOTAL_AMOUNT = 1000e6; // 1000 USDC
    uint256 public constant CHECKPOINT_1 = 300e6;  // 300 USDC
    uint256 public constant CHECKPOINT_2 = 700e6;  // 700 USDC

    event AgreementStarted(uint256 indexed agreementId);
    event CheckpointCompleted(uint256 indexed agreementId, uint256 indexed checkpointId);
    event AgreementTerminated(uint256 indexed agreementId);

    function setUp() public {
        // Deploy mock contracts
        mockUSDC = new MockERC20();
        mockVault = new MockERC4626(IERC20(address(mockUSDC)));
        mockVerifier = new MockVerifier();
        
        // Deploy NagareAgreement
        nagareAgreement = new NagareAgreement(address(mockVault));

        // Setup balances
        mockUSDC.mint(client, TOTAL_AMOUNT * 10);
        mockUSDC.mint(contractor, TOTAL_AMOUNT);
        mockUSDC.mint(provider, TOTAL_AMOUNT);

        // Setup approvals
        vm.prank(client);
        mockUSDC.approve(address(nagareAgreement), type(uint256).max);
    }

    function createTestAgreement() internal returns (Agreement memory) {
        uint256[] memory checkpointSizes = new uint256[](2);
        checkpointSizes[0] = CHECKPOINT_1;
        checkpointSizes[1] = CHECKPOINT_2;

        return Agreement({
            verifier: INagareVerifier(address(mockVerifier)),
            contractInfo: abi.encode("Test contract info"),
            totalSize: TOTAL_AMOUNT,
            checkpointSize: checkpointSizes,
            receiver: contractor,
            provider: provider
        });
    }

    function testStartAgreement() public {
        Agreement memory agreement = createTestAgreement();
        
        uint256 initialBalance = mockUSDC.balanceOf(client);
        
        vm.expectEmit(true, false, false, false);
        emit AgreementStarted(1);
        
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        // Check balances
        assertEq(mockUSDC.balanceOf(client), initialBalance - TOTAL_AMOUNT);
        assertEq(mockUSDC.balanceOf(address(mockVault)), TOTAL_AMOUNT);
        
        // Check agreement storage
        Agreement memory storedAgreement = nagareAgreement.agreements(1);
        assertEq(address(storedAgreement.verifier), address(mockVerifier));
        assertEq(storedAgreement.totalSize, TOTAL_AMOUNT);
        assertEq(storedAgreement.receiver, contractor);
        assertEq(storedAgreement.provider, provider);
        
        // Check verifier registration
        assertEq(mockVerifier.registeredContracts(1), abi.encode("Test contract info"));
    }

    function testStartAgreementInvalidCheckpointSum() public {
        uint256[] memory invalidCheckpointSizes = new uint256[](2);
        invalidCheckpointSizes[0] = CHECKPOINT_1;
        invalidCheckpointSizes[1] = CHECKPOINT_2 + 100e6; // Invalid sum

        Agreement memory agreement = Agreement({
            verifier: INagareVerifier(address(mockVerifier)),
            contractInfo: abi.encode("Test contract info"),
            totalSize: TOTAL_AMOUNT,
            checkpointSize: invalidCheckpointSizes,
            receiver: contractor,
            provider: provider
        });

        vm.prank(client);
        vm.expectRevert();
        nagareAgreement.startAgreement(agreement);
    }

    function testCheckpointSuccess() public {
        // Setup agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        // Simulate some yield
        mockVault.simulateYield();

        // Approve checkpoint
        mockVerifier.setCheckpointApproval(1, true);

        uint256 initialContractorBalance = mockUSDC.balanceOf(contractor);
        uint256 initialProviderBalance = mockUSDC.balanceOf(provider);
        uint256 initialOwnerBalance = mockUSDC.balanceOf(owner);

        vm.expectEmit(true, true, false, false);
        emit CheckpointCompleted(1, 0);

        // Execute checkpoint
        nagareAgreement.checkpoint(1, 0, abi.encode("proof"));

        // Check that contractor received the checkpoint amount
        assertEq(mockUSDC.balanceOf(contractor), initialContractorBalance + CHECKPOINT_1);
        
        // Check that yield was distributed (owner and provider should receive some)
        assertGt(mockUSDC.balanceOf(owner), initialOwnerBalance);
        assertGt(mockUSDC.balanceOf(provider), initialProviderBalance);
    }

    function testCheckpointVerificationFailed() public {
        // Setup agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        // Don't approve checkpoint (default is false)
        vm.expectRevert();
        nagareAgreement.checkpoint(1, 0, abi.encode("invalid proof"));
    }

    function testCheckpointAlreadyCompleted() public {
        // Setup and complete first checkpoint
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        mockVerifier.setCheckpointApproval(1, true);
        nagareAgreement.checkpoint(1, 0, abi.encode("proof"));

        // Try to complete same checkpoint again
        vm.expectRevert();
        nagareAgreement.checkpoint(1, 0, abi.encode("proof"));
    }

    function testCheckpointInvalidId() public {
        // Setup agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        mockVerifier.setCheckpointApproval(1, true);
        
        // Try invalid checkpoint ID
        vm.expectRevert();
        nagareAgreement.checkpoint(1, 5, abi.encode("proof"));
    }

    function testTerminateSuccess() public {
        // Setup agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        // Complete first checkpoint
        mockVerifier.setCheckpointApproval(1, true);
        nagareAgreement.checkpoint(1, 0, abi.encode("proof"));

        // Simulate yield
        mockVault.simulateYield();

        // Approve termination
        mockVerifier.setTerminationApproval(1, true);

        uint256 initialProviderBalance = mockUSDC.balanceOf(provider);
        uint256 initialOwnerBalance = mockUSDC.balanceOf(owner);

        vm.expectEmit(true, false, false, false);
        emit AgreementTerminated(1);

        // Execute termination
        nagareAgreement.terminate(1, abi.encode("termination proof"));

        // Check that provider received remaining funds (at least CHECKPOINT_2)
        assertGe(mockUSDC.balanceOf(provider), initialProviderBalance + CHECKPOINT_2);
        
        // Check that owner received protocol fee
        assertGt(mockUSDC.balanceOf(owner), initialOwnerBalance);
    }

    function testTerminateVerificationFailed() public {
        // Setup agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        // Don't approve termination
        vm.expectRevert();
        nagareAgreement.terminate(1, abi.encode("invalid proof"));
    }

    function testTerminateAlreadyTerminated() public {
        // Setup and terminate agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        mockVerifier.setTerminationApproval(1, true);
        nagareAgreement.terminate(1, abi.encode("proof"));

        // Try to terminate again
        vm.expectRevert();
        nagareAgreement.terminate(1, abi.encode("proof"));
    }

    function testCheckpointAfterTermination() public {
        // Setup and terminate agreement
        Agreement memory agreement = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement);

        mockVerifier.setTerminationApproval(1, true);
        nagareAgreement.terminate(1, abi.encode("proof"));

        // Try to checkpoint after termination
        mockVerifier.setCheckpointApproval(1, true);
        vm.expectRevert();
        nagareAgreement.checkpoint(1, 0, abi.encode("proof"));
    }

    function testVaultGetter() public {
        assertEq(address(nagareAgreement.vault()), address(mockVault));
    }

    function testMultipleAgreements() public {
        // Create first agreement
        Agreement memory agreement1 = createTestAgreement();
        vm.prank(client);
        nagareAgreement.startAgreement(agreement1);

        // Create second agreement with different parameters
        uint256[] memory checkpointSizes2 = new uint256[](1);
        checkpointSizes2[0] = 500e6;

        Agreement memory agreement2 = Agreement({
            verifier: INagareVerifier(address(mockVerifier)),
            contractInfo: abi.encode("Second contract"),
            totalSize: 500e6,
            checkpointSize: checkpointSizes2,
            receiver: address(0x4),
            provider: address(0x5)
        });

        vm.prank(client);
        nagareAgreement.startAgreement(agreement2);

        // Check both agreements exist
        Agreement memory stored1 = nagareAgreement.agreements(1);
        Agreement memory stored2 = nagareAgreement.agreements(2);

        assertEq(stored1.totalSize, TOTAL_AMOUNT);
        assertEq(stored2.totalSize, 500e6);
        assertEq(stored1.receiver, contractor);
        assertEq(stored2.receiver, address(0x4));
    }
}