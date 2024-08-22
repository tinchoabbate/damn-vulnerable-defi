// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Test, console} from "forge-std/Test.sol";
import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "./NaiveReceiverPool.sol";
import "../../lib/SharedGlobalData.sol";

abstract contract Multicall is Context, SymTest {
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0002));
    bool anti_recursion = false;

    function multicall(uint256 data_id /*bytes[] calldata data*/) external virtual returns (bytes[] memory results) {
        if (anti_recursion == false)
            anti_recursion = true;
        else {
            revert();
        }
        console.log ("multicall");
        bytes[1] memory data;
        results = new bytes[](data.length);
        //bytes memory call = abi.encodeCall(NaiveReceiverPool.withdraw, (100, payable(address(0x00000000000000000000000000000000000000000000000000000000a77ac3e5))));
        for (uint256 i = 0; i < data.length; i++) {
            console.log ("loop");
            console.log (i);
            console.log(data_id);
            data[i] = shared_data.get_known_data(data_id);
            //data[i] = svm.createBytes(100, 'multicall_data');
            results[i] = Address.functionDelegateCall(address(this), data[i]);
            //results[i] = Address.functionDelegateCall(address(this), call);
        }
        anti_recursion = false;
        return results;
    }
}
