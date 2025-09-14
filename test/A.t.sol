pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {JsmnSolLib} from "../src/library/JsmnSolLib.sol";
import {StringUtils} from "../src/library/StringUtils.sol";

import {console} from "forge-std/console.sol";

contract ATest is Test {
    using StringUtils for string;

    function testParseContext() external pure {
        string memory json = unicode"{\"extractedParameters\":{\"data\":\"{\\\"data\\\":{\\\"type\\\":\\\"MESSAGE_TYPE_CAST_ADD\\\",\\\"fid\\\":99,\\\"timestamp\\\":148325112,\\\"network\\\":\\\"FARCASTER_NETWORK_MAINNET\\\",\\\"castAddBody\\\":{\\\"embedsDeprecated\\\":[],\\\"mentions\\\":[],\\\"parentCastId\\\":null,\\\"parentUrl\\\":null,\\\"text\\\":\\\"what miniapps should we play with on the flight to basecamp?\\\",\\\"embeds\\\":[{\\\"url\\\":\\\"zoraCoin://0xa7f6334696e652196e352f880cafd13fd74874f4\\\"}],\\\"mentionsPositions\\\":[],\\\"type\\\":\\\"CAST\\\"}},\\\"hash\\\":\\\"0x0fedfbac29f8cac8a2f8fa1eea5da8a8e15571ee\\\",\\\"hashScheme\\\":\\\"HASH_SCHEME_BLAKE3\\\",\\\"signature\\\":\\\"B2HPGHvHrsulJG7WrAkMNVLVTyeqvn81BZcsU2NltPUiVKeyoYQ1atS31NWhpu00fb/Rvn1t9xE/KxG94+UtAg==\\\",\\\"signatureScheme\\\":\\\"SIGNATURE_SCHEME_ED25519\\\",\\\"signer\\\":\\\"0xa430a1c686444f31fc1c7635d8f8284e0cd947ad664a665783de3a1eabd05aea\\\"}\"},\"providerHash\":\"0xf7c08da4fc8d54e84565d20610bdb2b42e3cfddcfb552d7eb9f9cf74e1417ae0\"}";
        (
            uint256 exitCode,
            JsmnSolLib.Token[] memory tokens,
            uint256 ntokens
        ) = JsmnSolLib.parse(json, 256);

        console.log("exitCode", exitCode);
        console.log("ntokens", ntokens);
        for (uint256 i = 0; i < ntokens; i++) {
            console.log(
                "Token",
                i,
                json.substring(
                    tokens[i].start,
                    tokens[i].end
                )
            );
        }
        
        string memory data = json.substring(
            tokens[4].start,
            tokens[4].end
        ).unescape();
        console.log("unescapedData", data);

        (
            uint256 dataExitCode,
            JsmnSolLib.Token[] memory dataTokens,
            uint256 dataNtokens
        ) = JsmnSolLib.parse(data, 256);

        console.log("dataExitCode", dataExitCode);
        console.log("dataNtokens", dataNtokens);
        for (uint256 i = 0; i < dataNtokens; i++) {
            console.log(
                "Data Token",
                i,
                data.substring(
                    dataTokens[i].start,
                    dataTokens[i].end
                )
            );
        }
    }

    function testParseUrl() external pure {
        string memory json = unicode"{\"body\":\"\",\"headers\":{\"User-Agent\":\"reclaim/0.0.1\",\"accept\":\"application/json, text/plain, */*\"},\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"(?<data>.*)\"}],\"responseRedactions\":[],\"url\":\"https://snapchain-api.neynar.com/v1/castById?hash=0x1ca479648eced5ad23ad58bd28c91efe5bd486f3&fid=576\"}";
        (uint256 exitCode, JsmnSolLib.Token[] memory tokens, uint256 ntokens) = JsmnSolLib
            .parse(json, 80);

        require(exitCode == 0, "Failed to parse JSON");

        for (uint256 i = 0; i < ntokens; i++) {
            console.log(
                "Token",
                i,
                json.substring(
                    tokens[i].start,
                    tokens[i].end
                )
            );
        }

        string memory url = json
            .substring(tokens[21].start, tokens[21].end).unescape().substring(0, 44);

        console.log("url", url);
        
    }
}
