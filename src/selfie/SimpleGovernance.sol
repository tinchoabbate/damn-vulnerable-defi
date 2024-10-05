// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableVotes} from "../DamnValuableVotes.sol";
import {ISimpleGovernance} from "./ISimpleGovernance.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/Test.sol";

contract SimpleGovernance is ISimpleGovernance, Test {
    using Address for address;

    uint256 private constant ACTION_DELAY_IN_SECONDS = 2 days;

    DamnValuableVotes private _votingToken;
    uint256 private _actionCounter;
    mapping(uint256 => GovernanceAction) private _actions;
    bool anti_recursion = false;

    constructor(DamnValuableVotes votingToken) {
        _votingToken = votingToken;
        _actionCounter = 1;
    }

    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId) {
        console.log("q action");
        console.log("q 1");
        console.log(msg.sender);

        if (!_hasEnoughVotes(msg.sender)) {
            revert NotEnoughVotes(msg.sender);
        }
        console.log("q 2");
        if (target == address(this)) {
            revert InvalidTarget();
        }
        console.log("q 3");
        if (data.length > 0 && target.code.length == 0) {
            revert TargetMustHaveCode();
        }

        actionId = _actionCounter;

        _actions[actionId] = GovernanceAction({
            target: target,
            value: value,
            proposedAt: uint64(block.timestamp),
            executedAt: 0,
            data: data
        });

        unchecked {
            _actionCounter++;
        }
        console.log(_actionCounter);

        emit ActionQueued(actionId, msg.sender);
    }

    function executeAction(uint256 actionId) external payable returns (bytes memory) {
        if (anti_recursion == true)
        {
            revert();
        }
        anti_recursion = true;
        console.log("execute action");
        console.log("e 1");
        if (!_canBeExecuted(actionId)) {
            revert CannotExecute(actionId);
        }
        console.log("e 2");
        GovernanceAction storage actionToExecute = _actions[actionId];
        actionToExecute.executedAt = uint64(block.timestamp);
        console.log("e 3");
        emit ActionExecuted(actionId, msg.sender);
        console.log("e 4");
        vm.assume(actionToExecute.target != address(0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496)); // Not testing contract
        bytes memory ret = actionToExecute.target.functionCallWithValue(actionToExecute.data, actionToExecute.value);
        anti_recursion = false;
        return ret;
    }

    function getActionDelay() external pure returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }

    function getVotingToken() external view returns (address) {
        return address(_votingToken);
    }

    function getAction(uint256 actionId) external view returns (GovernanceAction memory) {
        return _actions[actionId];
    }

    function getActionCounter() external view returns (uint256) {
        return _actionCounter;
    }

    /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
    function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute;
        console.log("cbe 1");
        console.log(_actionCounter);
        for (uint256 i = 1; i < _actionCounter; i++)
        {
            if (i == actionId)
            {
                actionToExecute = _actions[i];
                console.log("actionID is ");
                console.log(i);
            }
        }
        console.log("cbe 2");
        if (actionToExecute.proposedAt == 0) return false;
        console.log("cbe 3");
        uint64 timeDelta;
        unchecked {
            timeDelta = uint64(block.timestamp) - actionToExecute.proposedAt;
        }
        console.log("cbe 4");
        return actionToExecute.executedAt == 0 && timeDelta >= ACTION_DELAY_IN_SECONDS;
    }

    function _hasEnoughVotes(address who) private view returns (bool) {
        uint256 balance = _votingToken.getVotes(who);
        console.log(balance);
        uint256 halfTotalSupply = _votingToken.totalSupply() / 2;
        console.log(halfTotalSupply);
        return balance > halfTotalSupply;
    }
}
