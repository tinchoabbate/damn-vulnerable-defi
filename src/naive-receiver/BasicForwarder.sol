// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IHasTrustedForwarder {
    function trustedForwarder() external view returns (address);
}

contract BasicForwarder is EIP712 {
    struct Request {
        address from;
        address target;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
        uint256 deadline;
    }

    error InvalidSigner();
    error InvalidNonce();
    error OldRequest();
    error InvalidTarget();
    error InvalidValue();

    bytes32 private constant _REQUEST_TYPEHASH = keccak256(
        "Request(address from,address target,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 deadline)"
    );

    mapping(address => uint256) public nonces;

    /**
     * @notice Check request and revert when not valid. A valid request must:
     * - Include the expected value
     * - Not be expired
     * - Include the expected nonce
     * - Target a contract that accepts this forwarder
     * - Be signed by the original sender (`from` field)
     */
    function _checkRequest(Request calldata request, bytes calldata signature) private view {
        if (request.value != msg.value) revert InvalidValue();
        if (block.timestamp > request.deadline) revert OldRequest();
        if (nonces[request.from] != request.nonce) revert InvalidNonce();

        if (IHasTrustedForwarder(request.target).trustedForwarder() != address(this)) revert InvalidTarget();

        address signer = ECDSA.recover(_hashTypedData(getDataHash(request)), signature);
        if (signer != request.from) revert InvalidSigner();
    }

    function execute(Request calldata request, bytes calldata signature) public payable returns (bool success) {
        _checkRequest(request, signature);

        nonces[request.from]++;

        uint256 gasLeft;
        uint256 value = request.value; // in wei
        address target = request.target;
        bytes memory payload = abi.encodePacked(request.data, request.from);
        uint256 forwardGas = request.gas;
        assembly {
            success := call(forwardGas, target, value, add(payload, 0x20), mload(payload), 0, 0) // don't copy returndata
            gasLeft := gas()
        }

        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "BasicForwarder";
        version = "1";
    }

    function getDataHash(Request memory request) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _REQUEST_TYPEHASH,
                request.from,
                request.target,
                request.value,
                request.gas,
                request.nonce,
                keccak256(request.data),
                request.deadline
            )
        );
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function getRequestTypehash() external pure returns (bytes32) {
        return _REQUEST_TYPEHASH;
    }
}
