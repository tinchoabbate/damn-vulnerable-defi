![](cover.png)

**A set of challenges to hack implementations of DeFi in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

Created by [@tinchoabbate](https://twitter.com/tinchoabbate)
Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## My solutions

Code's solution are in ./test/... and if needed, in ./contracts/attacker-contracts/...

### 1 Unstoppable 

There's a lending pool with a million DVT tokens in balance, offering flash loans for free.
If only there was a way to attack and stop the pool from offering flash loans ...
You start with 100 DVT tokens in balance.

Solution: ./test/unstoppable/unstoppable.challenge.js

on this.token:

using transfer() instead of depositTokens() 

> poolBalance = poolBalance.add(amount); is not trigger

then, when calling function flashloan:

> assert(poolBalance == balanceBefore); // is now False

### 2 Naive receiver

There's a lending pool offering quite expensive flash loans of Ether, which has 1000 ETH in balance.

You also see that a user has deployed a contract with 10 ETH in balance, capable of interacting with the lending pool and receiveing flash loans of ETH.

Drain all ETH funds from the user's contract. Doing it in a single transaction is a big plus ;)

Solution:

Anyone call call the flashloan function, and then, choose the naive receiver...
Fix: 

### 3 Truster

More and more lending pools are offering flash loans. In this case, a new pool has launched that is offering flash loans of DVT tokens for free.

Currently the pool has 1 million DVT tokens in balance. And you have nothing.

But don't worry, you might be able to take them all from the pool. In a single transaction.

Solution:

The flashloan function calls an external function we can code.

This function will approve our smart contract address to transfer token token.

Then our smart contract transfer token from the pool to attacker's address

### 4 Side Entrance


Solution:

The function flashloan do a flashloan that do a deposit of all the tokens (pool) to the attackercontract.

Then, the attacker contract sends all these tokens to the attacker.

### 5 The Rewarder

There's a pool offering rewards in tokens every 5 days for those who deposit their DVT tokens into it.

Alice, Bob, Charlie and David have already deposited some DVT tokens, and have won their rewards!

You don't have any DVT tokens. But in the upcoming round, you must claim most rewards for yourself.

Solution:

Create a contract that calls the function flashLoan:
- that calls receiveFlashLoan, it will do:
  - a deposit of the amount loaned, which generate a reward 
  - withdraw the amount
  - transfer back tokens loaned
- then transfer token from rewardToken to the attacker

(take care to have approve transfer from theRewarderPool to flashLoanPool)

### 6 Selfie

A new cool lending pool has launched! It's now offering flash loans of DVT tokens.

Wow, and it even includes a really fancy governance mechanism to control it.

You start with no DVT tokens in balance, and the pool has 1.5 million. Your objective: take them all.

Solution:

Create a contract that calls the function flashLoan:
- thats call receiveFlashLoan, it will do:
  - have a lot of governance tokens (same as the pool tokens) 
  - do a snapshot of the governance token -> it gives & remembers vote rights 
  - throught queueAction function, use the function drainAllFunds to send the tokens to the attackerEOA (in 2days)
  - store the actionId to use it later
  - transfer back the tokens to the pool flashloan
- "wait" 2 days and then activate executeAction from governance smart contract