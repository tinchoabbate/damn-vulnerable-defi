# Challenge #11 - Backdoor

To incentivize the creation of more secure wallets in their team, someone has deployed a registry of (Gnosis Safe wallets)[https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/GnosisSafe.sol]. When someone in the team deploys and registers a wallet, they will earn 10 DVT tokens.

To make sure everything is safe and sound, the registry tightly integrates with the legitimate (Gnosis Safe Proxy Factory)[https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/proxies/GnosisSafeProxyFactory.sol], and has some additional safety checks.

Currently there are four people registered as beneficiaries: Alice, Bob, Charlie and David. The registry has 40 DVT tokens in balance to be distributed among them.

Your goal is to take all funds from the registry. In a single transaction. 