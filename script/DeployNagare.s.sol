// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {NagareAgreement} from "../src/NagareAgreementMorpho.sol";
import {NagareVerifierReclaimFarcast} from "../src/verifiers/NagareVerifierReclaimFarcast.sol";

contract DeployNagare is Script {
    // Base Sepolia addresses
    address constant RECLAIM_ADDRESS =
        0xF90085f5Fd1a3bEb8678623409b3811eCeC5f6A5;
    // You'll need to replace this with the actual Morpho vault address on Base Sepolia
    address constant MORPHO_VAULT_ADDRESS =
        0x6F1910eCeE70BaBdADF38843a6975B8e6fC85E4d; // TODO: Replace with actual vault address

    function run() public {
        vm.startBroadcast();

        // Deploy the verifier first
        console.log("Deploying NagareVerifierReclaimFarcast...");
        NagareVerifierReclaimFarcast verifier = new NagareVerifierReclaimFarcast(
                RECLAIM_ADDRESS
            );
        console.log(
            "NagareVerifierReclaimFarcast deployed at:",
            address(verifier)
        );

        // Deploy the agreement contract
        console.log("Deploying NagareAgreement...");
        NagareAgreement agreement = new NagareAgreement(MORPHO_VAULT_ADDRESS);
        console.log("NagareAgreement deployed at:", address(agreement));

        // Set the agreement contract as authorized in the verifier
        console.log("Setting agreement contract as authorized...");
        verifier.setAgreementContract(address(agreement), true);
        console.log("Agreement contract authorized");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Verifier Address:", address(verifier));
        console.log("Agreement Address:", address(agreement));
        console.log("Reclaim Address:", RECLAIM_ADDRESS);
        console.log("Morpho Vault Address:", MORPHO_VAULT_ADDRESS);
    }
}
