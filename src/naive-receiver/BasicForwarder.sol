// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/Test.sol";
import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "../../lib/SharedGlobalData.sol";

interface IHasTrustedForwarder {
    function trustedForwarder() external view returns (address);
}

contract BasicForwarder is EIP712, SymTest, Test {
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0002)); // We can hardcode it
    struct Request {
        address from;
        address target;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
        uint256 deadline;
    }
    Request request1;
    bytes signature = svm.createBytes(100, 'signature');

    constructor(){
        console.log("constructor");
        request1.from = svm.createAddress('request_from');
        console.log("constructor 2");
        request1.target = svm.createAddress('request_target');
        request1.value - svm.createUint256('request_value');
        request1.gas = svm.createUint256('request_gas');
        request1.nonce = svm.createUint256('request_nonce');
        request1.data = svm.createBytes(100, 'request_data');
        request1.deadline = svm.createUint256('request_deadline');
        console.log("constructor 3");
    }

    error InvalidSigner();
    error InvalidNonce();
    error OldRequest();
    error InvalidTarget();
    error InvalidValue();

    bytes32 private constant _REQUEST_TYPEHASH = keccak256(
        "Request(address from,address target,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 deadline"
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
    function _checkRequest(Request memory _request, bytes memory _signature) private view {
        if (_request.value != msg.value) revert InvalidValue();
        if (block.timestamp > _request.deadline) revert OldRequest();
        if (nonces[_request.from] != _request.nonce) revert InvalidNonce();
        if (IHasTrustedForwarder(_request.target).trustedForwarder() != address(this)) revert InvalidTarget();

        //address signer = ECDSA.recover(_hashTypedData(getDataHash(request)), signature);
        //if (signer != request.from) revert InvalidSigner();

    }

    function execute(/*Request calldata request*//*, bytes calldata signature*/) public payable returns (bool success) {
        console.log("forwarder execute");
        vm.assume (request1.target != address(0x00000000000000000000000000000000000000000000000000000000aaaa0004)); // Avoid recursion
        request1.target = shared_data.get_known_address(request1.target);
        _checkRequest(request1, signature);

        nonces[request1.from]++;

        uint256 gasLeft;
        uint256 value = request1.value; // in wei
        address target = request1.target;
        bytes memory payload = abi.encodePacked(request1.data, request1.from);
        uint256 forwardGas = request1.gas;
        assembly {
            success := call(forwardGas, target, value, add(payload, 0x20), mload(payload), 0, 0) // don't copy returndata
            gasLeft := gas()
        }

        if (gasLeft < request1.gas / 63) {
            assembly {
                invalid()
            }
        }
        console.log("end forwarder execute");
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "BasicForwarder";
        version = "1";
    }

    /*function getDataHash(Request memory request) public pure returns (bytes32) {
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
    }*/

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function getRequestTypehash() external pure returns (bytes32) {
        return _REQUEST_TYPEHASH;
    }
}
