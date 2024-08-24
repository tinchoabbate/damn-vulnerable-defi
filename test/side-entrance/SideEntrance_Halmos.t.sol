// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract SideEntranceChallenge is Test {
    address deployer = address(0xde4107e4);
    address recovery = address(0xa77ac3e5);
    address player = address(0xa77ac3e4);

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SharedGlobalData shared_data;
    SideEntranceLenderPool pool;

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
        pool = new SideEntranceLenderPool();

        vm.deal(address(pool), 0);
        console.log("balance pool 1");
        console.log(address(pool).balance);

        console.log("shared_data", address(shared_data));
        console.log("pool", address(pool));

        shared_data.add_known_address(address(pool));

        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_sideEntrance() public checkSolvedByPlayer {
        AbstractAttacker attacker = new AbstractAttacker();
        vm.deal(address(attacker), 0);
        attacker.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assert (address(pool).balance != 0);
        //assertEq(address(pool).balance, 0, "Pool still has ETH");
        //assertEq(recovery.balance, ETHER_IN_POOL, "Not enough ETH in recovery account");
    }
}
