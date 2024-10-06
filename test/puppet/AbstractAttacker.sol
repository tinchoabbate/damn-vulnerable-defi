// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "forge-std/Test.sol";
import "../../lib/SharedGlobalData.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";

import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {IUniswapV1Exchange} from "../../src/puppet/IUniswapV1Exchange.sol";

contract AbstractAttacker is Test, SymTest, IERC3156FlashBorrower {
    bool anti_recursion = false;
    SharedGlobalData shared_data = SharedGlobalData(address(0x00000000000000000000000000000000000000000000000000000000aaaa0004)); // We can hardcode it
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        console.log("onFlashLoan aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        single_tx_with_calldata("flashloan");
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function single_transaction(string memory data_id, string memory target_id) private {
        bool success;
        bytes memory data = svm.createBytes(100, data_id);
        address target = svm.createAddress(target_id);
        target = shared_data.get_known_address(target); // Get some concrete contract address
        console.log("target is single ", target);
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

    function single_tx_with_calldata(string memory target_id) private {
        bool success;
        address target = svm.createAddress(target_id);
        string memory name;
        (target, name) = shared_data.get_known_address_with_name(target); // Get some concrete contract address and name
        console.log(target_id);
        console.log("target is single ", target);
        console.log("name is single ", name);
        bytes memory data = svm.createCalldata(name);
        uint256 val = svm.createUint256("val");
        (success, ) = target.call{value: val}(data);
        if (!success) {
            revert(); // attack function is guaranted to success
        }
    }

	function attack() public {
        DamnValuableToken token = DamnValuableToken(address(0x00000000000000000000000000000000000000000000000000000000aaaa0005));
        IUniswapV1Exchange exchange = IUniswapV1Exchange(address(0x00000000000000000000000000000000000000000000000000000000aaaa0006));
        console.log("attack start");
        token.approve(address(exchange), 2**256-1);
        single_tx_with_calldata("target_1");
        single_tx_with_calldata("target_2");
    }
}