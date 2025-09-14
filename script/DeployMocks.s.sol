// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/mock/MockUSDC.sol";
import {MockVault} from "../src/mock/MockVault.sol";

contract DeployMocks is Script {
    function run() public {
        vm.startBroadcast();

        // Deploy Mock USDC
        console.log("Deploying Mock USDC...");
        MockUSDC mockUSDC = new MockUSDC();
        console.log("Mock USDC deployed at:", address(mockUSDC));

        // Deploy Mock Vault with Mock USDC as the underlying asset
        console.log("Deploying Mock Vault...");
        MockVault mockVault = new MockVault(
            mockUSDC,
            "Mock Vault Token",
            "mvUSDC"
        );
        console.log("Mock Vault deployed at:", address(mockVault));

        // Mint some initial USDC to the deployer for testing
        console.log("Minting 1M USDC to deployer for testing...");
        mockUSDC.mint(msg.sender, 1_000_000 * 10**6); // 1M USDC (6 decimals)

        vm.stopBroadcast();

        console.log("\n=== Mock Deployment Summary ===");
        console.log("Mock USDC Address:", address(mockUSDC));
        console.log("Mock Vault Address:", address(mockVault));
        console.log("Vault Asset (should match USDC):", address(mockVault.asset()));
        console.log("Deployer USDC Balance:", mockUSDC.balanceOf(msg.sender) / 10**6, "USDC");

        console.log("\n=== Testing Instructions ===");
        console.log("1. Anyone can mint USDC by calling: mockUSDC.mint(amount)");
        console.log("2. To use the vault:");
        console.log("   - Approve USDC: mockUSDC.approve(vaultAddress, amount)");
        console.log("   - Deposit: mockVault.deposit(amount, receiver)");
        console.log("   - Withdraw: mockVault.withdraw(amount, receiver, owner)");
        console.log("3. The vault simulates 5% APY interest");
    }
}