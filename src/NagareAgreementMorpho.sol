// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {INagareAgreement, Agreement} from "./interface/INagareAgreement.sol";

contract NagareAgreement is INagareAgreement, Ownable {
    using SafeERC20 for IERC20;

    uint256 _agreementCount = 0;
    mapping(uint256 => Agreement) _agreements;
    mapping(uint256 => uint256) _agreementBalances;
    mapping(uint256 => bool) _terminatedAgreements;
    mapping(uint256 => mapping(uint256 => bool)) _completedCheckpoints;
    IERC4626 _vault;
    IERC20 _asset;

    event AgreementStarted(uint256 indexed agreementId);
    event CheckpointCompleted(
        uint256 indexed agreementId,
        uint256 indexed checkpointId
    );
    event AgreementTerminated(uint256 indexed agreementId);

    error InvalidAgreement();
    error AgreementAlreadyTerminated();
    error InvalidCheckpoint();
    error CheckpointAlreadyCompleted();
    error CheckpointVerificationFailed();
    error TerminationVerificationFailed();

    constructor(address vault_) Ownable(msg.sender) {
        _vault = IERC4626(vault_);
        _asset = IERC20(_vault.asset());
    }

    function startAgreement(Agreement memory agreement) external {
        _agreementCount += 1;
        _agreements[_agreementCount] = agreement;

        // validate sum(checkpointSize) == totalSize
        uint256 sum = 0;
        for (uint256 i = 0; i < agreement.checkpointSize.length; i++) {
            sum += agreement.checkpointSize[i];
        }
        require(sum == agreement.totalSize, InvalidAgreement());

        // deposit to morpho
        _asset.safeTransferFrom(msg.sender, address(this), agreement.totalSize);
        _asset.forceApprove(address(_vault), agreement.totalSize);
        _agreementBalances[_agreementCount] = _vault.deposit(
            agreement.totalSize,
            address(this)
        );

        agreement.verifier.registerAgreement(
            agreement.contractInfo,
            _agreementCount
        );

        emit AgreementStarted(_agreementCount);
    }

    function checkpoint(
        uint256 agreementId,
        uint256 checkpointId,
        bytes memory auxiliaryData
    ) external {
        Agreement memory agreement = _agreements[agreementId];
        require(
            !_terminatedAgreements[agreementId],
            AgreementAlreadyTerminated()
        );
        require(
            checkpointId < agreement.checkpointSize.length,
            InvalidCheckpoint()
        );
        require(
            !_completedCheckpoints[agreementId][checkpointId],
            CheckpointAlreadyCompleted()
        );
        require(
            agreement.verifier.verifyCheckpoint(
                agreementId,
                checkpointId,
                auxiliaryData
            ),
            CheckpointVerificationFailed()
        );

        // transfer to receiver
        uint256 amount = agreement.checkpointSize[checkpointId];
        uint256 shares = (amount * _agreementBalances[agreementId]) /
            agreement.totalSize;
        _agreementBalances[agreementId] -= shares;
        _completedCheckpoints[agreementId][checkpointId] = true;
        uint256 withdrawal = _vault.redeem(
            shares,
            address(this),
            address(this)
        );
        uint256 interest = withdrawal - amount;

        // -- distribute interest, 50% to protocol, 50% to provider
        if (interest > 0) {
            _asset.safeTransfer(owner(), interest / 2);
            _asset.safeTransfer(agreement.provider, interest / 2);
        }
        _asset.safeTransfer(agreement.receiver, amount);

        emit CheckpointCompleted(agreementId, checkpointId);
    }

    function terminate(
        uint256 agreementId,
        bytes memory auxiliaryData
    ) external {
        Agreement memory agreement = _agreements[agreementId];
        require(
            !_terminatedAgreements[agreementId],
            AgreementAlreadyTerminated()
        );
        require(
            agreement.verifier.verifyTermination(agreementId, auxiliaryData),
            TerminationVerificationFailed()
        );

        // transfer remaining to provider
        uint256 shares = _agreementBalances[agreementId];
        _agreementBalances[agreementId] = 0;
        _terminatedAgreements[agreementId] = true;
        uint256 remainSize = agreement.totalSize;
        for (uint256 i = 0; i < agreement.checkpointSize.length; i++) {
            if (_completedCheckpoints[agreementId][i]) {
                remainSize -= agreement.checkpointSize[i];
            }
        }
        uint256 withdrawal = _vault.redeem(
            shares,
            address(this),
            address(this)
        );
        uint256 interest = withdrawal - remainSize;

        // -- distribute interest, 50% to protocol, 50% to provider
        if (interest > 0) {
            _asset.safeTransfer(owner(), interest / 2);
        }
        _asset.safeTransfer(agreement.provider, withdrawal - interest);

        emit AgreementTerminated(agreementId);
    }

    function vault() external view returns (IERC4626) {
        return _vault;
    }

    function agreements(
        uint256 agreementId
    ) external view returns (Agreement memory) {
        return _agreements[agreementId];
    }

    function agreementBalance(
        uint256 agreementId
    ) external view returns (uint256) {
        return _agreementBalances[agreementId];
    }

    function isCheckpointCompleted(
        uint256 agreementId,
        uint256 checkpointId
    ) external view returns (bool) {
        return _completedCheckpoints[agreementId][checkpointId];
    }

    function isAgreementTerminated(
        uint256 agreementId
    ) external view returns (bool) {
        return _terminatedAgreements[agreementId];
    }
}
