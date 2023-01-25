# Changelog

## v3.0.0

- Two new levels: Puppet v3 and ABI Smuggling
- Heavy rework of Safe Miners challenge. Now called "Wallet mining".
- Unstoppable challenge now uses a tokenized vault following [ERC4626](https://eips.ethereum.org/EIPS/eip-4626).
- Some challenges now explicitly require to be solved in a single transaction.
- Now using [ERC3156](https://eips.ethereum.org/EIPS/eip-3156) for some flashloan pools.
- Now the Damn Valuable Token uses [ERC2612](https://eips.ethereum.org/EIPS/eip-2612). Therefore, added [eth-permit](https://github.com/dmihal/eth-permit) as a dependency to ease signing permit data. 
- Welcome [solady](https://github.com/Vectorized/solady) and [solmate](https://github.com/transmissions11/solmate)!
- Migrate from Waffle to Hardhat Chai Matchers (following [this guide](https://hardhat.org/hardhat-chai-matchers/docs/migrate-from-waffle))
- Change final assertion in Puppet challenge [following PR#9](https://github.com/tinchoabbate/damn-vulnerable-defi/pull/9).
- Remove unnecessary `await`s in "The Rewarder" challenge [following PR#12](https://github.com/tinchoabbate/damn-vulnerable-defi/pull/12)
- Remove the `WETH9` contract, and import it from solmate instead.
- Change timestamp comparison in `ClimberTimelock` contract [following PR#16](https://github.com/tinchoabbate/damn-vulnerable-defi/pull/16) and additional refactors.
- The player now plays with the `player` account.
- _Lots_ of quality of life changes in dependencies, custom errors, error messages, variable names, docs, gas optimizations (assembly, yay!) and code organization.

## v2.2.0

- Change name of challenge "Junior Miners" to "Safe Miners".

## v2.1.0

- New level: Junior Miners.

## v2.0.0

- Refactor testing environment. Now using Hardhat, Ethers and Waffle. This should give players a better debugging experience, and allow them to familiarize with up-to-date JavaScript tooling for smart contract testing.
- New levels:
    - Backdoor
    - Climber
    - Free Rider
    - Puppet v2
- New integrations with Gnosis Safe wallets, Uniswap v2, WETH9 and the upgradebale version of OpenZeppelin Contracts.
- Tweaks in existing challenges after community feedback
    - Upgraded most contracts to Solidity 0.8
    - Changes in internal libraries around low-level calls and transfers of ETH. Now mostly using OpenZeppelin Contracts utilities.
    - In existing Puppet and The Rewarder challenges, better encapsulate issues to avoid repetitions.
    - Reorganization of some files
- Changed from `npm` to `yarn` as dependency manager

## v1.0.0

Initial version
