// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import "./halmos-cheatcodes/src/SymTest.sol";
import {Test, console} from "forge-std/Test.sol";

contract SharedGlobalData is SymTest {
    mapping (uint256 => bytes) known_data;
    uint256 data_list_size = 0;
    mapping (uint256 => address) known_addresses;
    uint256 addresses_list_size = 0;

    function add_known_address(address known) public {
        known_addresses[addresses_list_size] = known;
        addresses_list_size++;
    }

    function get_known_data(uint256 data_id) public returns (bytes memory)
    {
        if (data_id == data_list_size)
        {
            known_data[data_id] = svm.createBytes(100, 'known_data');
            data_list_size++;
            return known_data[data_id];
        }
        for (uint256 i = 0; i < data_list_size; i++)
        {
            if (data_id == i)
            {
                return known_data[data_id];
            }
        }
        revert();
    }

    function get_known_address(address addr) public view returns (address ret){
        for (uint256 i = 0; i < addresses_list_size; i++)
        {
            if (addr == known_addresses[i])
            {
                ret = known_addresses[i];
                return ret;
            }
        }
        revert (); //some address should be returned
    }
}