// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";

contract AbstractAttacker is Test, SymTest {
	function attack(address[] calldata targets) public {
        address target = svm.createAddress("target");

        for (uint i = 0; i < targets.length; i++) {
            if (target == targets[i]) {
                bytes memory data = svm.createBytes(100, 'data');
                (bool success, ) = target.call(data);
                vm.assume(success);
            }
        }
    }
}
