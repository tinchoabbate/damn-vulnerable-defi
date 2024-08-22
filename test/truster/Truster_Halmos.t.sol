// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract TrusterChallenge is Test {
    address deployer = address(0xde4107e4);
    address recovery = address(0xa77ac3e5);
    address player = address(0xa77ac3e4);
    
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    SharedGlobalData shared_data;
    DamnValuableToken public token;
    TrusterLenderPool public pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer, 1 << 80);
        shared_data = new SharedGlobalData();
        // Deploy token
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        console.log("shared_data", address(shared_data));
        console.log("token", address(token));
        console.log("pool", address(pool));

        shared_data.add_known_address(address(pool));
        shared_data.add_known_address(address(token));

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_truster() public checkSolvedByPlayer {
        AbstractAttacker attacker = new AbstractAttacker();
        attacker.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        //assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account

        assert(token.balanceOf(address(pool)) != 0 || token.balanceOf(recovery) != TOKENS_IN_POOL);


      //  assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
      //  assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
