// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockVault is ERC4626 {
    using Math for uint256;

    uint256 private constant INTEREST_RATE = 500; // 5% APY (500 basis points)
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    
    mapping(address => uint256) private _lastDepositTime;
    mapping(address => uint256) private _userAssets;
    uint256 private _totalManagedAssets;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC4626(asset_) ERC20(name_, symbol_) {}

    function totalAssets() public view override returns (uint256) {
        // Calculate accrued interest for the entire vault
        if (_totalManagedAssets == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - _getVaultLastUpdateTime();
        uint256 interest = (_totalManagedAssets * INTEREST_RATE * timeElapsed) 
                          / (10000 * SECONDS_PER_YEAR);
        
        return _totalManagedAssets + interest;
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);
        
        _lastDepositTime[receiver] = block.timestamp;
        _userAssets[receiver] += assets;
        _totalManagedAssets += assets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // Calculate user's share of accrued interest
        uint256 timeElapsed = block.timestamp - _lastDepositTime[owner];
        uint256 userBaseAssets = _userAssets[owner];
        
        if (userBaseAssets > 0 && timeElapsed > 0) {
            // Calculate interest (not used in this simple mock)
            // uint256 userInterest = (userBaseAssets * INTEREST_RATE * timeElapsed) 
            //                       / (10000 * SECONDS_PER_YEAR);
            
            // In a real implementation, you would mint interest here
            // For this mock, we just simulate the calculation
        }

        // Update tracking before calling parent
        uint256 userShares = balanceOf(owner);
        if (userShares > 0) {
            uint256 assetsToReduce = (_userAssets[owner] * shares) / userShares;
            _userAssets[owner] -= Math.min(_userAssets[owner], assetsToReduce);
            _totalManagedAssets -= Math.min(_totalManagedAssets, assetsToReduce);
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _getVaultLastUpdateTime() private view returns (uint256) {
        // Simplified: use current block timestamp minus 1 day for mock purposes
        return block.timestamp > 1 days ? block.timestamp - 1 days : 0;
    }

    // Helper functions for testing
    function getUserAssets(address user) external view returns (uint256) {
        return _userAssets[user];
    }

    function getUserLastDepositTime(address user) external view returns (uint256) {
        return _lastDepositTime[user];
    }

    function getTotalManagedAssets() external view returns (uint256) {
        return _totalManagedAssets;
    }

    // Mock function to simulate time-based interest accrual
    function simulateTimePass(uint256 /* timeInSeconds */) external view {
        // In a real vault, this wouldn't exist - time passes naturally
        // This is just for testing purposes - currently a no-op
        // In a more complex implementation, this could update internal state
    }
}