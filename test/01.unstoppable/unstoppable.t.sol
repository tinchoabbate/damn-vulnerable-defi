// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "src/01.unstoppable/UnstoppableVault.sol";
import "src/01.unstoppable/ReceiverUnstoppable.sol";
import "src/DamnValuableToken.sol";

contract ChallengeUnstoppable is Test {
  DamnValuableToken public token;
  UnstoppableVault public vault;
  ReceiverUnstoppable public receiver;
  uint256 public constant TOKENS_IN_VAULT = 1_000_000 ether;
  uint256 public constant INITIAL_PLAYER_TOKEN_BALANCE = 10 ether;

  address public deployer = makeAddr("deployer");
  address public player = makeAddr("player");
  address public someUser = makeAddr("someUser");

  function setUp() public {
    /**
     * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
     */
    changePrank(deployer);
    token = new DamnValuableToken();
    vault = new UnstoppableVault(token, deployer, deployer);

    assertEq(address(vault.asset()), address(token));

    token.approve(address(vault), TOKENS_IN_VAULT);
    vault.deposit(TOKENS_IN_VAULT, deployer);

    assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
    assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
    assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
    assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50000 ether);

    token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);
    assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

    // Show it's possible for someUser to take out a flash loan
    changePrank(someUser);
    receiver = new ReceiverUnstoppable(address(vault));
    receiver.executeFlashLoan(100 ether);
  }

  function test_solution() public {
    /**
     * CODE YOUR SOLUTION HERE
     */
    changePrank(player);
    /**
     * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
     */
    changePrank(someUser);
    vm.expectRevert();
    receiver.executeFlashLoan(100 ether);
    // It is no longer possible to execute flash loans
  }
}
