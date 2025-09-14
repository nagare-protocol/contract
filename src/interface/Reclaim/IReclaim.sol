// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Claims.sol";

interface IReclaim {
    struct Witness {
        /** ETH address of the witness */
        address addr;
        /** Host to connect to the witness */
        string host;
    }

    struct Epoch {
        /** Epoch number */
        uint32 id;
        /** when the epoch changed */
        uint32 timestampStart;
        /** when the epoch will change */
        uint32 timestampEnd;
        /** Witnesses for this epoch */
        Witness[] witnesses;
        /**
         * Minimum number of witnesses
         * required to create a claim
         * */
        uint8 minimumWitnessesForClaimCreation;
    }

    struct Proof {
        Claims.ClaimInfo claimInfo;
        Claims.SignedClaim signedClaim;
    }

    /**
     * Call the function to assert
     * the validity of several claims proofs
     */
    function verifyProof(Proof memory proof) external view;
}
