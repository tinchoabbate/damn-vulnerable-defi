// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title AuthorizedExecutor
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
abstract contract AuthorizedExecutor is ReentrancyGuard {
    using Address for address;

    bool public initialized;

    // action identifier => allowed
    mapping(bytes32 => bool) public permissions;

    error NotAllowed();
    error AlreadyInitialized();

    event Initialized(address who, bytes32[] ids);

    /**
     * @notice Allows first caller to set permissions for a set of action identifiers
     * @param ids array of action identifiers
     */
    function setPermissions(bytes32[] memory ids) external {
        if (initialized) {
            revert AlreadyInitialized();
        }

        for (uint256 i = 0; i < ids.length;) {
            unchecked {
                permissions[ids[i]] = true;
                ++i;
            }
        }
        initialized = true;

        emit Initialized(msg.sender, ids);
    }

    /**
     * @notice Performs an arbitrary function call on a target contract, if the caller is authorized to do so.
     * @param target account where the action will be executed
     * @param actionData abi-encoded calldata to execute on the target
     */
    function execute(address target, bytes calldata actionData) external nonReentrant returns (bytes memory) {
        // Read the 4-bytes selector at the beginning of `actionData`
        bytes4 selector;
        uint256 calldataOffset = 4 + 32 * 3; // calldata position where `actionData` begins
        assembly {
            selector := calldataload(calldataOffset)
        }

        if (!permissions[getActionId(selector, msg.sender, target)]) {
            revert NotAllowed();
        }

        _beforeFunctionCall(target, actionData);

        return target.functionCall(actionData);
    }

    function _beforeFunctionCall(address target, bytes memory actionData) internal virtual;

    function getActionId(bytes4 selector, address executor, address target) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(selector, executor, target));
    }
}
