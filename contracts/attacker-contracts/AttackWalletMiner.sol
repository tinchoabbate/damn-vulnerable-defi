pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "hardhat/console.sol";

contract AttackWalletMiner {
  GnosisSafe public safe;

  constructor () {

  }

  function deploySafe() external  {

    address predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7,
            bytes32(0),
            keccak256(abi.encodePacked(
                type(GnosisSafe).creationCode
            ))
        )))));
    console.log(predictedAddress);
     safe = new GnosisSafe{salt: 0}();
  }
}