// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleGovernance {
    struct GovernanceAction {
        uint128 value;
        uint64 proposedAt;
        uint64 executedAt;
        address target;
        bytes data;
    }

    error NotEnoughVotes(address who);
    error CannotExecute(uint256 actionId);
    error InvalidTarget();
    error TargetMustHaveCode();
    error ActionFailed(uint256 actionId);

    event ActionQueued(uint256 actionId, address indexed caller);
    event ActionExecuted(uint256 actionId, address indexed caller);

    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId);
    function executeAction(uint256 actionId) external payable returns (bytes memory returndata);
    function getActionDelay() external view returns (uint256 delay);
    function getGovernanceToken() external view returns (address token);
    function getAction(uint256 actionId) external view returns (GovernanceAction memory action);
    function getActionCounter() external view returns (uint256);
}
