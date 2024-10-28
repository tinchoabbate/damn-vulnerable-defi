// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";

contract SymbolicAttacker is Test, SymTest {
	function attack() public {
        address target = svm.createAddress("target");
        vm.assume (target != address(this)); // Avoid recursion
        bytes memory data = svm.createBytes(100, 'data');
        target.call(data);
    }
}
