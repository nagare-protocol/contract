// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INagareVerifier} from "../interface/INagareVerifier.sol";
import {IReclaim} from "../interface/Reclaim/IReclaim.sol";
import {JsmnSolLib} from "../library/JsmnSolLib.sol";
import {StringUtils} from "../library/StringUtils.sol";

contract NagareVerifierReclaimFarcast is INagareVerifier, Ownable {
    using StringUtils for string;

    struct VerifierConfig {
        uint256 fid;
        string[] checkpointTexts;
        uint256 deadline;
    }

    mapping(uint256 => VerifierConfig) _verifierConfigs;
    mapping(address => bool) _agreementContracts;
    IReclaim public reclaim;

    error Unauthorized();

    constructor(address reclaimAddress_) Ownable(msg.sender) {
        reclaim = IReclaim(reclaimAddress_);
    }

    function registerAgreement(
        bytes memory contractInfo,
        uint256 agreementId
    ) external {
        require(_agreementContracts[msg.sender], Unauthorized());

        (uint256 fid, string[] memory checkpointTexts, uint256 deadline) = abi
            .decode(contractInfo, (uint256, string[], uint256));
        _verifierConfigs[agreementId] = VerifierConfig(
            fid,
            checkpointTexts,
            deadline
        );
    }

    function setAgreementContract(
        address agreementContract,
        bool allowed
    ) external onlyOwner {
        _agreementContracts[agreementContract] = allowed;
    }

    function verifyCheckpoint(
        uint256 agreementId,
        uint256 checkpointId,
        bytes memory auxiliaryData
    ) external view returns (bool) {
        IReclaim.Proof memory proof = abi.decode(
            auxiliaryData,
            (IReclaim.Proof)
        );

        try reclaim.verifyProof(proof) {} catch {
            return false;
        }

        return
            _checkUrl(proof.claimInfo.parameters) &&
            _checkCast(
                proof.claimInfo.context,
                _verifierConfigs[agreementId].fid,
                _verifierConfigs[agreementId].checkpointTexts[checkpointId]
            );
    }

    function verifyTermination(
        uint256 agreementId,
        bytes memory
    ) external view returns (bool) {
        VerifierConfig memory config = _verifierConfigs[agreementId];
        return block.timestamp >= config.deadline;
    }

    function _checkUrl(string memory parameters) internal pure returns (bool) {
        (uint256 exitCode, JsmnSolLib.Token[] memory tokens, ) = JsmnSolLib
            .parse(parameters, 256);

        if (exitCode != 0) return false;

        // we assume the request config is fixed, so we can access the url directly
        // in production version, we need to more carefully parse the necessary data
        string memory url = parameters
            .substring(tokens[21].start, tokens[21].end)
            .unescape();

        return
            url.substring(0, 44).areEqual(
                "https://snapchain-api.neynar.com/v1/castById"
            );
    }

    function _checkCast(
        string memory context,
        uint256 fid,
        string memory text
    ) internal pure returns (bool) {
        (uint256 exitCode, JsmnSolLib.Token[] memory tokens, ) = JsmnSolLib
            .parse(context, 8);

        if (exitCode != 0) return false;

        string memory data = context
            .substring(tokens[4].start, tokens[4].end)
            .unescape();

        (
            uint256 dataExitCode,
            JsmnSolLib.Token[] memory dataTokens,

        ) = JsmnSolLib.parse(data, 256);

        if (dataExitCode != 0) return false;

        // because the api response is fixed, we can access the fid and text directly
        // in production version, we need to more carefully parse the necessary data
        return
            fid ==
            uint256(
                JsmnSolLib.parseInt(
                    data.substring(dataTokens[6].start, dataTokens[6].end)
                )
            ) &&
            data.substring(dataTokens[22].start, dataTokens[22].end).areEqual(
                text
            );
    }
}
