// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";
import "../../lib/SharedGlobalData.sol";
import {WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";

contract AbstractAttacker is Test, SymTest {
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0002)); // We can hardcode it

    function single_transaction(string memory data_id, string memory target_id) private {
        bool success;
        bytes memory data = svm.createBytes(200, data_id);
        address target = svm.createAddress(target_id);
        target = shared_data.get_known_address(target); // Get some concrete contract address
        (success, ) = target.call(data);
        if (!success) {
            revert(); // attack function is guaranted to success
        }
    }

    function similar_transactions(string memory data_id, string memory target_id) private {
        bool success;
        bytes memory data = svm.createBytes(100, data_id);
        address target = svm.createAddress(target_id);
        target = shared_data.get_known_address(target); // Get some concrete contract address
        console.log("target is similar ", target);
        for (int i = 0; i < 10; i++) {
            (success, ) = target.call(data);
            if (!success) {
                revert(); // attack function is guaranted to success
            }
        }
    }

	function attack() public {
        single_transaction("data1", "target1");
        single_transaction("data2", "target2");
    }
}