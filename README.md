![](cover.png)

**A set of challenges to hack implementations of DeFi in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

Created by [@tinchoabbate](https://twitter.com/tinchoabbate)

## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.


## My solution:

* Unstoppable 
There's a lending pool with a million DVT tokens in balance, offering flash loans for free.
If only there was a way to attack and stop the pool from offering flash loans ...
You start with 100 DVT tokens in balance.

Solution: ./test/unstoppable/unstoppable.challenge.js
on this.token:
using transfer() instead of depositTokens() 
-> poolBalance = poolBalance.add(amount); is not trigger
then, when calling function flashloan:
-> assert(poolBalance == balanceBefore); // is now False

