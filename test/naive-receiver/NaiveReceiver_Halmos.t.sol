// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = address(0xde4107e4);
    address recovery = address(0xa77ac3e5);
    address player = address(0xa77ac3e4);
    //uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    SharedGlobalData shared_data;
    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

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
        //(player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer, 1 << 80);
        shared_data = new SharedGlobalData();
        // Deploy WETH
        weth = new WETH();
        // Deploy forwarder
        forwarder = new BasicForwarder();
        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);
        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        console.log("shared_data", address(shared_data));
        console.log("weth", address(weth));
        console.log("forwarder", address(forwarder));
        console.log("pool", address(pool));
        console.log("receiver", address(receiver));
        console.log("deployer", address(deployer));
        console.log("recovery", address(recovery));
        console.log("player", address(player));

        // Add known contracts to list
        shared_data.add_known_address(address(weth));
        shared_data.add_known_address(address(forwarder));
        shared_data.add_known_address(address(pool));
        shared_data.add_known_address(address(receiver));

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(0x48f5c3ed);
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_naiveReceiver() public checkSolvedByPlayer {
        console.log (address(645326474426547203313410069153905908525362434349));
        AbstractAttacker attacker = new AbstractAttacker();
        attacker.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        //assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        //assert(weth.balanceOf(address(receiver)) > 7e18);
        //assert(weth.balanceOf(address(receiver)) != 0);
        //assert(weth.balanceOf(address(receiver)) != 0 || weth.balanceOf(address(pool)) != 0);

        // Pool is empty too
        assert (weth.balanceOf(address(pool)) != 0);

        // All funds sent to recovery account
        //assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}
