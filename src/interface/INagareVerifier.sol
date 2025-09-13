// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INagareVerifier {
    function registerAgreement(
        bytes memory contractInfo,
        uint256 agreementId
    ) external;

    function verifyCheckpoint(
        uint256 agreementId,
        uint256 checkpointId,
        bytes memory auxiliaryData
    ) external view returns (bool);

    function verifyTermination(
        uint256 agreementId,
        bytes memory auxiliaryData
    ) external view returns (bool);
}
