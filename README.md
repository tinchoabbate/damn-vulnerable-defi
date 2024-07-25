# Damn Vulnerable DeFi

Damn Vulnerable DeFi is _the_ smart contract security playground for developers, security researchers and educators.

Perhaps the most sophisticated vulnerable set of Solidity smart contracts ever witnessed, it features flashloans, price oracles, governance, NFTs, DEXs, lending pools, smart contract wallets, timelocks, vaults, meta-transactions, token distributions, upgradeability and more.

Use Damn Vulnerable DeFi to:

- Sharpen your auditing and bug-hunting skills.
- Learn how to detect, test and fix flaws in realistic scenarios to become a security-minded developer.
- Benchmark smart contract security tooling.
- Create educational content on smart contract security with articles, tutorials, talks, courses, workshops, trainings, CTFs, etc.

## Install

1. Clone the repository.
2. Checkout the latest release (for example, `git checkout v4.0.0`)
3. Rename the `.env.sample` file to `.env` and add a valid RPC URL. This is only needed for the challenges that fork mainnet state.
4. Either install [Foundry](https://book.getfoundry.sh/getting-started/installation), or use the [provided devcontainer](./.devcontainer/) (In VSCode, open the repository as a devcontainer with the command "Devcontainer: Open Folder in Container...")
5. Run `forge build` to initialize the project.

## Usage

Each challenge is made up of:

- A prompt located in `src/<challenge-name>/README.md`.
- A set of contracts located in `src/<challenge-name>/`.
- A [Foundry test](https://book.getfoundry.sh/forge/tests) located in `test/<challenge-name>/<ChallengeName>.t.sol`.

To solve a challenge:

1. Read the challenge's prompt.
2. Uncover the flaw(s) in the challenge's smart contracts.
3. Code your solution in the corresponding test file.
4. Try your solution with `forge test --mp test/<challenge-name>/<ChallengeName>.t.sol`.
   If the test passes, you've solved the challenge!

Challenges may have more than one possible solution.

### Rules

- You must always use the `player` account.
- You must not modify the challenges' initial nor final conditions.
- You can code and deploy your own smart contracts.
- You can use Foundry's cheatcodes to advance time when necessary.
- You can import external libraries that aren't installed, although it shouldn't be necessary.

## Troubleshooting

You can ask the community for help in [the discussions section](https://github.com/theredguild/damn-vulnerable-defi/discussions).

## Disclaimer

All code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.

# Solve

- [x] 1. [Unstoppable](https://www.damnvulnerabledefi.xyz/challenges/unstoppable/)
- [ ] 2. [Naive receiver](https://www.damnvulnerabledefi.xyz/challenges/naive-receiver/)
- [ ] 3. [Truster](https://www.damnvulnerabledefi.xyz/challenges/truster/)
- [ ] 4. [ Side Entrance](https://www.damnvulnerabledefi.xyz/challenges/side-entrance/)
- [ ] 5. [The Rewarder](https://www.damnvulnerabledefi.xyz/challenges/the-rewarder/)
- [ ] 6. [Selfie](https://www.damnvulnerabledefi.xyz/challenges/selfie/)
- [ ] 7. [Compromised](https://www.damnvulnerabledefi.xyz/challenges/compromised/)
- [ ] 8. [Puppet](https://www.damnvulnerabledefi.xyz/challenges/puppet/)
- [ ] 9. [Puppet V2](https://www.damnvulnerabledefi.xyz/challenges/puppet-v2/)
- [ ] 10. [Free Rider](https://www.damnvulnerabledefi.xyz/challenges/free-rider/)
- [ ] 11. [Backdoor](https://www.damnvulnerabledefi.xyz/challenges/backdoor/)
- [ ] 12. [Climber](https://www.damnvulnerabledefi.xyz/challenges/climber/)
- [ ] 13. [Wallet Mining](https://www.damnvulnerabledefi.xyz/challenges/wallet-mining/)
- [ ] 14. [Puppet V3](https://www.damnvulnerabledefi.xyz/challenges/puppet-v3/)
- [x] 15. [ABI Smuggling](https://www.damnvulnerabledefi.xyz/challenges/abi-smuggling/)
- [ ] 16. [Shards](https://www.damnvulnerabledefi.xyz/challenges/shards/)
- [ ] 17. [Curvy Puppet](https://www.damnvulnerabledefi.xyz/challenges/curvy-puppet/)
- [ ] 18. [Withdrawal](https://www.damnvulnerabledefi.xyz/challenges/withdrawal/)
