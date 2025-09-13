// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {INagareVerifier} from "./INagareVerifier.sol";

struct Agreement {
    INagareVerifier verifier;
    bytes contractInfo;
    uint256 totalSize;
    uint256[] checkpointSize;
    address receiver;
}

interface INagareAgreement {
    function startAgreement(Agreement memory agreement) external;

    function vault() external view returns (IERC4626);

    function getAgreement(
        uint256 agreementId
    ) external view returns (Agreement memory);

    function checkpoint(
        uint256 agreementId,
        uint256 checkpointId,
        bytes memory auxiliaryData
    ) external;

    function terminate(
        uint256 agreementId,
        bytes memory auxiliaryData
    ) external;
}
