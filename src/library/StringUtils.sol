// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * Utilities for string manipulation & conversion
 */
library StringUtils {
	function address2str(address x) internal pure returns (string memory) {
		bytes memory s = new bytes(40);
		for (uint i = 0; i < 20; i++) {
			bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
			bytes1 hi = bytes1(uint8(b) / 16);
			bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
			s[2 * i] = getChar(hi);
			s[2 * i + 1] = getChar(lo);
		}
		return string(abi.encodePacked("0x", s));
	}

	function bytes2str(bytes memory buffer) internal pure returns (string memory) {
		// Fixed buffer size for hexadecimal convertion
		bytes memory converted = new bytes(buffer.length * 2);
		bytes memory _base = "0123456789abcdef";

		for (uint256 i = 0; i < buffer.length; i++) {
			converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
			converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
		}

		return string(abi.encodePacked("0x", converted));
	}

	function getChar(bytes1 b) internal pure returns (bytes1 c) {
		if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
		else return bytes1(uint8(b) + 0x57);
	}

	function bool2str(bool _b) internal pure returns (string memory _uintAsString) {
		if (_b) {
			return "true";
		} else {
			return "false";
		}
	}

	function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
		if (_i == 0) {
			return "0";
		}
		uint j = _i;
		uint len;
		while (j != 0) {
			len++;
			j /= 10;
		}
		bytes memory bstr = new bytes(len);
		uint k = len;
		while (_i != 0) {
			k = k - 1;
			uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
			bytes1 b1 = bytes1(temp);
			bstr[k] = b1;
			_i /= 10;
		}
		return string(bstr);
	}

	function areEqual(
		string calldata _a,
		string storage _b
	) internal pure returns (bool) {
		return keccak256(abi.encodePacked((_a))) == keccak256(abi.encodePacked((_b)));
	}

	function areEqual(string memory _a, string memory _b) internal pure returns (bool) {
		return keccak256(abi.encodePacked((_a))) == keccak256(abi.encodePacked((_b)));
	}

	function toLower(string memory str) internal pure returns (string memory) {
		bytes memory bStr = bytes(str);
		bytes memory bLower = new bytes(bStr.length);
		for (uint i = 0; i < bStr.length; i++) {
			// Uppercase character...
			if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
				// So we add 32 to make it lowercase
				bLower[i] = bytes1(uint8(bStr[i]) + 32);
			} else {
				bLower[i] = bStr[i];
			}
		}
		return string(bLower);
	}

	function substring(
		string memory str,
		uint startIndex,
		uint endIndex
	) internal pure returns (string memory) {
		bytes memory strBytes = bytes(str);
		bytes memory result = new bytes(endIndex - startIndex);
		for (uint i = startIndex; i < endIndex; i++) {
			result[i - startIndex] = strBytes[i];
		}
		return string(result);
	}

	function unescape(string memory str) internal pure returns (string memory) {
		bytes memory input = bytes(str);
		bytes memory output = new bytes(input.length);
		uint outputIndex = 0;
		
		for (uint i = 0; i < input.length; i++) {
			if (input[i] == 0x5C && i + 1 < input.length) { // backslash
				bytes1 nextChar = input[i + 1];
				if (nextChar == 0x22) { // \"
					output[outputIndex++] = 0x22; // "
				} else if (nextChar == 0x5C) { // \\
					output[outputIndex++] = 0x5C; // \
				} else if (nextChar == 0x2F) { // \/
					output[outputIndex++] = 0x2F; // /
				} else if (nextChar == 0x62) { // \b
					output[outputIndex++] = 0x08; // backspace
				} else if (nextChar == 0x66) { // \f
					output[outputIndex++] = 0x0C; // form feed
				} else if (nextChar == 0x6E) { // \n
					output[outputIndex++] = 0x0A; // newline
				} else if (nextChar == 0x72) { // \r
					output[outputIndex++] = 0x0D; // carriage return
				} else if (nextChar == 0x74) { // \t
					output[outputIndex++] = 0x09; // tab
				} else {
					output[outputIndex++] = input[i];
					continue;
				}
				i++; // skip the next character
			} else {
				output[outputIndex++] = input[i];
			}
		}
		
		// resize output to actual length
		bytes memory result = new bytes(outputIndex);
		for (uint i = 0; i < outputIndex; i++) {
			result[i] = output[i];
		}
		
		return string(result);
	}
}
