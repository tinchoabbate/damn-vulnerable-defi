// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";

contract AbstractAttacker is Test, SymTest {
    mapping (uint256 => address) known_addresses;
    uint256 known_next_index = 0;

    function add_known_address(address known) public {
        known_addresses[known_next_index] = known;
        known_next_index++;
    }

	function attack() public {
        uint256 contract_index = svm.createUint256('contract_index');
        vm.assume(contract_index < known_next_index);
        for (uint256 i = 0; i < known_next_index; i++) { // brootforce is happening here
            if (i == contract_index) {
                address to_call = known_addresses[i]; // contract address is not symbolic now
                bytes memory data = svm.createBytes(100, 'data');
                (bool success, ) = to_call.call(data);
                if (!success) {
                    revert(); // attack function is guaranted to success
                }
            }
        }
    }
}