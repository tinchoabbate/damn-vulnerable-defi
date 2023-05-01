// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ClimberTimelockBase
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
abstract contract ClimberTimelockBase is AccessControl {
    // Possible states for an operation in this timelock contract
    enum OperationState {
        Unknown,
        Scheduled,
        ReadyForExecution,
        Executed
    }

    // Operation data tracked in this contract
    struct Operation {
        uint64 readyAtTimestamp; // timestamp at which the operation will be ready for execution
        bool known; // whether the operation is registered in the timelock
        bool executed; // whether the operation has been executed
    }

    // Operations are tracked by their bytes32 identifier
    mapping(bytes32 => Operation) public operations;

    uint64 public delay;

    function getOperationState(bytes32 id) public view returns (OperationState state) {
        Operation memory op = operations[id];

        if (op.known) {
            if (op.executed) {
                state = OperationState.Executed;
            } else if (block.timestamp < op.readyAtTimestamp) {
                state = OperationState.Scheduled;
            } else {
                state = OperationState.ReadyForExecution;
            }
        } else {
            state = OperationState.Unknown;
        }
    }

    function getOperationId(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(targets, values, dataElements, salt));
    }

    receive() external payable {}
}
