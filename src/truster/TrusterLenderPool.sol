// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {Test, console} from "forge-std/Test.sol";
import "../../lib/SharedGlobalData.sol";


contract TrusterLenderPool is ReentrancyGuard {
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0002));
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(uint256 amount, address borrower, address target, uint256 data_id)
        external
        nonReentrant
        returns (bool)
    {
        console.log("flashloan start");
        bytes memory data = shared_data.get_known_data(data_id);
        target = shared_data.get_known_address(target);
        console.log("target_flashloan is ", target);
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}
