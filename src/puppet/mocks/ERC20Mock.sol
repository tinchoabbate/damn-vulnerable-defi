pragma solidity =0.8.25;

import "../tokens/ERC20.sol";


contract ERC20Mock is ERC20 {

  bytes32 public name;
  bytes32 public symbol;
  uint256 public decimals;

  constructor (bytes32 _name, bytes32 _symbol, uint256 _decimals, uint256 _supply) public {
    address _sender = msg.sender;
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    _balances[_sender] = _supply;
    _totalSupply = _supply;
    emit Transfer(address(0), _sender, _supply);
  }

}