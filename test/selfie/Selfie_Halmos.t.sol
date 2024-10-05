// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract SelfieChallenge is Test {
    address deployer = address(0xde4107e4);
    address player = address(0x44E97aF4418b7a17AABD8090bEA0A471a366305C);
    address recovery = address(0xa77ac3e5);

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    SharedGlobalData shared_data;
    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        console.log("setUp");
        startHoax(deployer);

        shared_data = new SharedGlobalData();

        // Deploy token
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        console.log("shared_data", address(shared_data));
        console.log("token", address(token));
        console.log("governance", address(governance));
        console.log("pool", address(pool));

        //shared_data.add_known_address_with_name(address(token), "DamnValuableVotes");
        shared_data.add_known_address_with_name(address(governance), "SimpleGovernance");
        shared_data.add_known_address_with_name(address(pool), "SelfiePool");

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_selfie() public checkSolvedByPlayer {
        console.log(address(this));
        console.log("check_selfie");
        token.approve(address(pool), 2**256 - 1); // unlimited approve
        AbstractAttacker attacker = new AbstractAttacker();
        attacker.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assert(token.balanceOf(address(pool)) != 0);
        //assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        //assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
