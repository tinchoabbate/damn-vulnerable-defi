// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";
import {IUniswapV1Factory} from "../../src/puppet/IUniswapV1Factory.sol";

import {UniswapExchange} from "../../src/puppet/uniswap/UniswapExchange.sol";
import {UniswapFactory} from "../../src/puppet/uniswap/UniswapFactory.sol";

import "../../lib/SharedGlobalData.sol";
import "./AbstractAttacker.sol";

contract PuppetChallenge is Test {
    address deployer = address(0xde4107e4);
    address player = address(0x44E97aF4418b7a17AABD8090bEA0A471a366305C);
    address recovery = address(0xa77ac3e5);
    uint256 playerPrivateKey;

    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    SharedGlobalData shared_data;
    DamnValuableToken token;
    PuppetPool lendingPool;
    IUniswapV1Exchange uniswapV1Exchange;
    IUniswapV1Factory uniswapV1Factory;

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
        startHoax(deployer, 1 << 80);

        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);


        // Deploy a exchange that will be used as the factory template
        UniswapExchange uniswapV1ExchangeTemplate = new UniswapExchange();
            //IUniswapV1Exchange(deployCode(string.concat(vm.projectRoot(), "/builds/uniswap/UniswapV1Exchange.json")));
        // Deploy factory, initializing it with the address of the template exchange
        UniswapFactory uniswapV1Factory = new UniswapFactory();
        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));
        // Deploy token to be traded in Uniswap V1
        shared_data = new SharedGlobalData();
        token = new DamnValuableToken();

        // Create a new exchange for the token
        uniswapV1Exchange = IUniswapV1Exchange(uniswapV1Factory.createExchange(address(token)));

        // Deploy the lending pool
        lendingPool = new PuppetPool(address(token), address(uniswapV1Exchange));

        // Add initial token and ETH liquidity to the pool
        token.approve(address(uniswapV1Exchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV1Exchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            block.timestamp * 2 // deadline
        );

        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        console.log("shared_data", address(shared_data));
        console.log("token", address(token));
        console.log("lendingPool", address(lendingPool));
        console.log("uniswapV1Factory", address(uniswapV1Factory));
        console.log("uniswapV1Exchange", address(uniswapV1Exchange));

        shared_data.add_known_address_with_name(address(uniswapV1Exchange),  "IUniswapV1Exchange");
        shared_data.add_known_address_with_name(address(lendingPool),  "PuppetPool");

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(uniswapV1Exchange.factoryAddress(), address(uniswapV1Factory));
        assertEq(uniswapV1Exchange.tokenAddress(), address(token));
        assertEq(
            uniswapV1Exchange.getTokenToEthInputPrice(1e18),
            _calculateTokenToEthInputPrice(1e18, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
        );
        assertEq(lendingPool.calculateDepositRequired(1e18), 2e18);
        assertEq(lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE), POOL_INITIAL_TOKEN_BALANCE * 2);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function check_puppet() public checkSolvedByPlayer {
        AbstractAttacker attacker = new AbstractAttacker();
        vm.deal(address(attacker), PLAYER_INITIAL_ETH_BALANCE);
        token.transfer(address(attacker), PLAYER_INITIAL_TOKEN_BALANCE);
        attacker.attack();
    }

    // Utility function to calculate Uniswap prices
    function _calculateTokenToEthInputPrice(uint256 tokensSold, uint256 tokensInReserve, uint256 etherInReserve)
        private
        pure
        returns (uint256)
    {
        return (tokensSold * 997 * etherInReserve) / (tokensInReserve * 1000 + tokensSold * 997);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player executed a single transaction
        //assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All tokens of the lending pool were deposited into the recovery account
        assert (token.balanceOf(address(lendingPool)) != 0);
        //assertEq(token.balanceOf(address(lendingPool)), 0, "Pool still has tokens");
        //assertGe(token.balanceOf(recovery), POOL_INITIAL_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
