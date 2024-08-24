// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";
import "../../lib/SharedGlobalData.sol";
import {WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {IFlashLoanEtherReceiver} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract AbstractAttacker is Test, SymTest, IFlashLoanEtherReceiver {
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0002)); // We can hardcode it

    receive() external payable {
    }

    function execute () external payable
    {
        single_transaction("execute_data", "execute_target", "execute_value");
    }

    function single_transaction(string memory data_id, string memory target_id, string memory value_id) private {
        bool success;
        uint256 val = svm.createUint256(value_id);
        bytes memory data = svm.createBytes(200, data_id);
        address target = svm.createAddress(target_id);
        target = shared_data.get_known_address(target); // Get some concrete contract address
        (success, ) = target.call{value: val}(data);
        if (!success) {
            revert(); // attack function is guaranted to success
        }
    }

    function actual_transaction() public {
        address target = address(0x00000000000000000000000000000000000000000000000000000000aaaa0003);
        bytes memory executePayload = abi.encodeWithSignature("flashLoan(uint256)", 1000e18);
        target.call(executePayload);
    }

	function attack() public {
        single_transaction("data1", "target1", "value1");
        single_transaction("data2", "target2", "value2");
    }
}