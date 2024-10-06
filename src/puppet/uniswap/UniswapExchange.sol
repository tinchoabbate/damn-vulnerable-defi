pragma solidity =0.8.25;
import "../tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapFactory.sol";
import "../interfaces/IUniswapExchange.sol";
import "../utils/SafeMath.sol";


contract UniswapExchange is ERC20 {
  using SafeMath for uint256;
  /***********************************|
  |        Variables && Events        |
  |__________________________________*/

  // Variables
  bytes32 public name;         // Uniswap V1
  bytes32 public symbol;       // UNI-V1
  uint256 public decimals;     // 18
  IERC20 token;                // address of the ERC20 token traded on this contract
  IUniswapFactory factory;     // interface for the factory that created this contract
  
  // Events
  event TokenPurchase(address indexed buyer, uint256 indexed eth_sold, uint256 indexed tokens_bought);
  event EthPurchase(address indexed buyer, uint256 indexed tokens_sold, uint256 indexed eth_bought);
  event AddLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);
  event RemoveLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);


  /***********************************|
  |            Constsructor           |
  |__________________________________*/

  /**  
   * @dev This function acts as a contract constructor which is not currently supported in contracts deployed
   *      using create_with_code_of(). It is called once by the factory during contract creation.
   */
  function setup(address token_addr) public {
    require( 
      address(factory) == address(0) && address(token) == address(0) && token_addr != address(0), 
      "INVALID_ADDRESS"
    );
    factory = IUniswapFactory(msg.sender);
    token = IERC20(token_addr);
    name = 0x556e697377617020563100000000000000000000000000000000000000000000;
    symbol = 0x554e492d56310000000000000000000000000000000000000000000000000000;
    decimals = 18;
  }


  /***********************************|
  |        Exchange Functions         |
  |__________________________________*/


  /**
   * @notice Convert ETH to Tokens.
   * @dev User specifies exact input (msg.value).
   * @dev User cannot specify minimum output or deadline.
   */
  receive () external payable {
    ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
  }

 /**
   * @dev Pricing function for converting between ETH && Tokens.
   * @param input_amount Amount of ETH or Tokens being sold.
   * @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
   * @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
   * @return Amount of ETH or Tokens bought.
   */
  function getInputPrice(uint256 input_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
    require(input_reserve > 0 && output_reserve > 0, "INVALID_VALUE");
    uint256 input_amount_with_fee = input_amount * 997;
    uint256 numerator = input_amount_with_fee * output_reserve;
    uint256 denominator = input_reserve * 1000 + input_amount_with_fee;
    return numerator / denominator;
  }

 /**
   * @dev Pricing function for converting between ETH && Tokens.
   * @param output_amount Amount of ETH or Tokens being bought.
   * @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
   * @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
   * @return Amount of ETH or Tokens sold.
   */
  function getOutputPrice(uint256 output_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
    require(input_reserve > 0 && output_reserve > 0);
    uint256 numerator = input_reserve.mul(output_amount).mul(1000);
    uint256 denominator = (output_reserve.sub(output_amount)).mul(997);
    return (numerator / denominator).add(1);
  }

  function ethToTokenInput(uint256 eth_sold, uint256 min_tokens, uint256 deadline, address buyer, address recipient) private returns (uint256) {
    require(deadline >= block.timestamp && eth_sold > 0 && min_tokens > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 tokens_bought = getInputPrice(eth_sold, address(this).balance.sub(eth_sold), token_reserve);
    require(tokens_bought >= min_tokens);
    require(token.transfer(recipient, tokens_bought));
    emit TokenPurchase(buyer, eth_sold, tokens_bought);
    return tokens_bought;
  }

  /** 
   * @notice Convert ETH to Tokens.
   * @dev User specifies exact input (msg.value) && minimum output.
   * @param min_tokens Minimum Tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of Tokens bought.
   */ 
  function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) public payable returns (uint256) {
    return ethToTokenInput(msg.value, min_tokens, deadline, msg.sender, msg.sender);
  }

  /** 
   * @notice Convert ETH to Tokens && transfers Tokens to recipient.
   * @dev User specifies exact input (msg.value) && minimum output
   * @param min_tokens Minimum Tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output Tokens.
   * @return  Amount of Tokens bought.
   */
  function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) public payable returns(uint256) {
    require(recipient != address(this) && recipient != address(0));
    return ethToTokenInput(msg.value, min_tokens, deadline, msg.sender, recipient);
  }

  function ethToTokenOutput(uint256 tokens_bought, uint256 max_eth, uint256 deadline, address payable buyer, address recipient) private returns (uint256) {
    require(deadline >= block.timestamp && tokens_bought > 0 && max_eth > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_sold = getOutputPrice(tokens_bought, address(this).balance.sub(max_eth), token_reserve);
    // Throws if eth_sold > max_eth
    uint256 eth_refund = max_eth.sub(eth_sold);
    if (eth_refund > 0) {
      buyer.transfer(eth_refund);
    }
    require(token.transfer(recipient, tokens_bought));
    emit TokenPurchase(buyer, eth_sold, tokens_bought);
    return eth_sold;
  }

  /** 
   * @notice Convert ETH to Tokens.
   * @dev User specifies maximum input (msg.value) && exact output.
   * @param tokens_bought Amount of tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of ETH sold.
   */
  function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) public payable returns(uint256) {
    return ethToTokenOutput(tokens_bought, msg.value, deadline, payable(msg.sender), msg.sender);
  }

  /** 
   * @notice Convert ETH to Tokens && transfers Tokens to recipient.
   * @dev User specifies maximum input (msg.value) && exact output.
   * @param tokens_bought Amount of tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output Tokens.
   * @return Amount of ETH sold.
   */
  function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) public payable returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return ethToTokenOutput(tokens_bought, msg.value, deadline, payable(msg.sender), recipient);
  }

  function tokenToEthInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address buyer, address payable recipient) private returns (uint256) {
    require(deadline >= block.timestamp && tokens_sold > 0 && min_eth > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);
    uint256 wei_bought = eth_bought;
    require(wei_bought >= min_eth);
    recipient.transfer(wei_bought);
    require(token.transferFrom(buyer, address(this), tokens_sold));
    emit EthPurchase(buyer, tokens_sold, wei_bought);
    return wei_bought;
  }

  /** 
   * @notice Convert Tokens to ETH.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_eth Minimum ETH purchased.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of ETH bought.
   */
  function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) public returns (uint256) {
    return tokenToEthInput(tokens_sold, min_eth, deadline, msg.sender, payable(msg.sender));
  }

  /** 
   * @notice Convert Tokens to ETH && transfers ETH to recipient.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_eth Minimum ETH purchased.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @return  Amount of ETH bought.
   */
  function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address payable recipient) public returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return tokenToEthInput(tokens_sold, min_eth, deadline, msg.sender, recipient);
  }

  
  function tokenToEthOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address buyer, address payable recipient) private returns (uint256) {
    require(deadline >= block.timestamp && eth_bought > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 tokens_sold = getOutputPrice(eth_bought, token_reserve, address(this).balance);
    // tokens sold is always > 0
    require(max_tokens >= tokens_sold);
    recipient.transfer(eth_bought);
    require(token.transferFrom(buyer, address(this), tokens_sold));
    emit EthPurchase(buyer, tokens_sold, eth_bought);
    return tokens_sold;
  }

  /** 
   * @notice Convert Tokens to ETH.
   * @dev User specifies maximum input && exact output.
   * @param eth_bought Amount of ETH purchased.
   * @param max_tokens Maximum Tokens sold.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of Tokens sold.
   */
  function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) public returns (uint256) {
    return tokenToEthOutput(eth_bought, max_tokens, deadline, msg.sender, payable(msg.sender));
  }

  /**
   * @notice Convert Tokens to ETH && transfers ETH to recipient.
   * @dev User specifies maximum input && exact output.
   * @param eth_bought Amount of ETH purchased.
   * @param max_tokens Maximum Tokens sold.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @return Amount of Tokens sold.
   */
  function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address payable recipient) public returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return tokenToEthOutput(eth_bought, max_tokens, deadline, msg.sender, recipient);
  }

  function tokenToTokenInput(
    uint256 tokens_sold, 
    uint256 min_tokens_bought, 
    uint256 min_eth_bought, 
    uint256 deadline,
    address buyer, 
    address recipient, 
    address payable exchange_addr) 
    private returns (uint256) 
  {
    require(deadline >= block.timestamp && tokens_sold > 0 && min_tokens_bought > 0 && min_eth_bought > 0);
    require(exchange_addr != address(this) && exchange_addr != address(0));
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);
    uint256 wei_bought = eth_bought;
    require(wei_bought >= min_eth_bought);
    require(token.transferFrom(buyer, address(this), tokens_sold));
    uint256 tokens_bought = IUniswapExchange(exchange_addr).ethToTokenTransferInput{value: wei_bought}(min_tokens_bought, deadline, recipient);
    emit EthPurchase(buyer, tokens_sold, wei_bought);
    return tokens_bought;
  }

  /**
   * @notice Convert Tokens (token) to Tokens (token_addr).
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
   * @param min_eth_bought Minimum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param token_addr The address of the token being purchased.
   * @return Amount of Tokens (token_addr) bought.
   */
  function tokenToTokenSwapInput(
    uint256 tokens_sold, 
    uint256 min_tokens_bought, 
    uint256 min_eth_bought, 
    uint256 deadline, 
    address token_addr) 
    public returns (uint256) 
  {
    address payable exchange_addr = factory.getExchange(token_addr);
    return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, msg.sender, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
   *         Tokens (token_addr) to recipient.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
   * @param min_eth_bought Minimum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @param token_addr The address of the token being purchased.
   * @return Amount of Tokens (token_addr) bought.
   */
  function tokenToTokenTransferInput(
    uint256 tokens_sold, 
    uint256 min_tokens_bought, 
    uint256 min_eth_bought, 
    uint256 deadline, 
    address recipient, 
    address token_addr) 
    public returns (uint256) 
  {
    address payable exchange_addr = factory.getExchange(token_addr);
    return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, recipient, exchange_addr);
  }

  function tokenToTokenOutput(
    uint256 tokens_bought, 
    uint256 max_tokens_sold, 
    uint256 max_eth_sold, 
    uint256 deadline, 
    address buyer, 
    address recipient, 
    address payable exchange_addr) 
    private returns (uint256) 
  {
    require(deadline >= block.timestamp && (tokens_bought > 0 && max_eth_sold > 0));
    require(exchange_addr != address(this) && exchange_addr != address(0));
    uint256 eth_bought = IUniswapExchange(exchange_addr).getEthToTokenOutputPrice(tokens_bought);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 tokens_sold = getOutputPrice(eth_bought, token_reserve, address(this).balance);
    // tokens sold is always > 0
    require(max_tokens_sold >= tokens_sold && max_eth_sold >= eth_bought);
    require(token.transferFrom(buyer, address(this), tokens_sold));
    uint256 eth_sold = IUniswapExchange(exchange_addr).ethToTokenTransferOutput{value: eth_bought}(tokens_bought, deadline, recipient);
    emit EthPurchase(buyer, tokens_sold, eth_bought);
    return tokens_sold;
  }

  /**
   * @notice Convert Tokens (token) to Tokens (token_addr).
   * @dev User specifies maximum input && exact output.
   * @param tokens_bought Amount of Tokens (token_addr) bought.
   * @param max_tokens_sold Maximum Tokens (token) sold.
   * @param max_eth_sold Maximum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param token_addr The address of the token being purchased.
   * @return Amount of Tokens (token) sold.
   */
  function tokenToTokenSwapOutput(
    uint256 tokens_bought, 
    uint256 max_tokens_sold, 
    uint256 max_eth_sold, 
    uint256 deadline, 
    address token_addr) 
    public returns (uint256) 
  {
    address payable exchange_addr = factory.getExchange(token_addr);
    return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, msg.sender, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
   *         Tokens (token_addr) to recipient.
   * @dev User specifies maximum input && exact output.
   * @param tokens_bought Amount of Tokens (token_addr) bought.
   * @param max_tokens_sold Maximum Tokens (token) sold.
   * @param max_eth_sold Maximum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @param token_addr The address of the token being purchased.
   * @return Amount of Tokens (token) sold.
   */
  function tokenToTokenTransferOutput(
    uint256 tokens_bought, 
    uint256 max_tokens_sold, 
    uint256 max_eth_sold, 
    uint256 deadline, 
    address recipient, 
    address token_addr) 
    public returns (uint256) 
  {
    address payable exchange_addr = factory.getExchange(token_addr);
    return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, recipient, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
   * @dev Allows trades through contracts that were not deployed from the same factory.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
   * @param min_eth_bought Minimum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param exchange_addr The address of the exchange for the token being purchased.
   * @return Amount of Tokens (exchange_addr.token) bought.
   */
  function tokenToExchangeSwapInput(
    uint256 tokens_sold, 
    uint256 min_tokens_bought, 
    uint256 min_eth_bought, 
    uint256 deadline, 
    address payable exchange_addr) 
    public returns (uint256) 
  {
    return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, msg.sender, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
   *         Tokens (exchange_addr.token) to recipient.
   * @dev Allows trades through contracts that were not deployed from the same factory.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
   * @param min_eth_bought Minimum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @param exchange_addr The address of the exchange for the token being purchased.
   * @return Amount of Tokens (exchange_addr.token) bought.
   */
  function tokenToExchangeTransferInput(
    uint256 tokens_sold, 
    uint256 min_tokens_bought, 
    uint256 min_eth_bought, 
    uint256 deadline, 
    address recipient, 
    address payable exchange_addr) 
    public returns (uint256) 
  {
    require(recipient != address(this));
    return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, recipient, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
   * @dev Allows trades through contracts that were not deployed from the same factory.
   * @dev User specifies maximum input && exact output.
   * @param tokens_bought Amount of Tokens (token_addr) bought.
   * @param max_tokens_sold Maximum Tokens (token) sold.
   * @param max_eth_sold Maximum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param exchange_addr The address of the exchange for the token being purchased.
   * @return Amount of Tokens (token) sold.
   */
  function tokenToExchangeSwapOutput(
    uint256 tokens_bought, 
    uint256 max_tokens_sold, 
    uint256 max_eth_sold, 
    uint256 deadline, 
    address payable exchange_addr) 
    public returns (uint256) 
  {
    return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, msg.sender, exchange_addr);
  }

  /**
   * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
   *         Tokens (exchange_addr.token) to recipient.
   * @dev Allows trades through contracts that were not deployed from the same factory.
   * @dev User specifies maximum input && exact output.
   * @param tokens_bought Amount of Tokens (token_addr) bought.
   * @param max_tokens_sold Maximum Tokens (token) sold.
   * @param max_eth_sold Maximum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @param exchange_addr The address of the exchange for the token being purchased.
   * @return Amount of Tokens (token) sold.
   */
  function tokenToExchangeTransferOutput(
    uint256 tokens_bought, 
    uint256 max_tokens_sold, 
    uint256 max_eth_sold, 
    uint256 deadline, 
    address recipient, 
    address payable exchange_addr) 
    public returns (uint256) 
  {
    require(recipient != address(this));
    return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, recipient, exchange_addr);
  }


  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @notice Public price function for ETH to Token trades with an exact input.
   * @param eth_sold Amount of ETH sold.
   * @return Amount of Tokens that can be bought with input ETH.
   */
  function getEthToTokenInputPrice(uint256 eth_sold) public view returns (uint256) {
    require(eth_sold > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    return getInputPrice(eth_sold, address(this).balance, token_reserve);
  }

  /**
   * @notice Public price function for ETH to Token trades with an exact output.
   * @param tokens_bought Amount of Tokens bought.
   * @return Amount of ETH needed to buy output Tokens.
   */
  function getEthToTokenOutputPrice(uint256 tokens_bought) public view returns (uint256) {
    require(tokens_bought > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_sold = getOutputPrice(tokens_bought, address(this).balance, token_reserve);
    return eth_sold;
  }

  /**
   * @notice Public price function for Token to ETH trades with an exact input.
   * @param tokens_sold Amount of Tokens sold.
   * @return Amount of ETH that can be bought with input Tokens.
   */
  function getTokenToEthInputPrice(uint256 tokens_sold) public view returns (uint256) {
    require(tokens_sold > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);
    return eth_bought;
  }

  /**
   * @notice Public price function for Token to ETH trades with an exact output.
   * @param eth_bought Amount of output ETH.
   * @return Amount of Tokens needed to buy output ETH.
   */
  function getTokenToEthOutputPrice(uint256 eth_bought) public view returns (uint256) {
    require(eth_bought > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    return getOutputPrice(eth_bought, token_reserve, address(this).balance);
  }

  /** 
   * @return Address of Token that is sold on this exchange.
   */
  function tokenAddress() public view returns (address) {
    return address(token);
  }

  /**
   * @return Address of factory that created this exchange.
   */
  function factoryAddress() public view returns (address) {
    return address(factory);
  }


  /***********************************|
  |        Liquidity Functions        |
  |__________________________________*/

  /** 
   * @notice Deposit ETH && Tokens (token) at current ratio to mint UNI tokens.
   * @dev min_liquidity does nothing when total UNI supply is 0.
   * @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
   * @param max_tokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return The amount of UNI minted.
   */
  function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) public payable returns (uint256) {
    require(deadline > block.timestamp && max_tokens > 0 && msg.value > 0, 'UniswapExchange#addLiquidity: INVALID_ARGUMENT');
    uint256 total_liquidity = _totalSupply;

    if (total_liquidity > 0) {
      require(min_liquidity > 0);
      uint256 eth_reserve = address(this).balance.sub(msg.value);
      uint256 token_reserve = token.balanceOf(address(this));
      uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(1);
      uint256 liquidity_minted = msg.value.mul(total_liquidity) / eth_reserve;
      require(max_tokens >= token_amount && liquidity_minted >= min_liquidity);
      _balances[msg.sender] = _balances[msg.sender].add(liquidity_minted);
      _totalSupply = total_liquidity.add(liquidity_minted);
      require(token.transferFrom(msg.sender, address(this), token_amount));
      emit AddLiquidity(msg.sender, msg.value, token_amount);
      emit Transfer(address(0), msg.sender, liquidity_minted);
      return liquidity_minted;

    } else {
      require(address(factory) != address(0) && address(token) != address(0) && msg.value >= 1000000000, "INVALID_VALUE");
      require(factory.getExchange(address(token)) == address(this));
      uint256 token_amount = max_tokens;
      uint256 initial_liquidity = address(this).balance;
      _totalSupply = initial_liquidity;
      _balances[msg.sender] = initial_liquidity;
      require(token.transferFrom(msg.sender, address(this), token_amount));
      emit AddLiquidity(msg.sender, msg.value, token_amount);
      emit Transfer(address(0), msg.sender, initial_liquidity);
      return initial_liquidity;
    }
  }

  /**
   * @dev Burn UNI tokens to withdraw ETH && Tokens at current ratio.
   * @param amount Amount of UNI burned.
   * @param min_eth Minimum ETH withdrawn.
   * @param min_tokens Minimum Tokens withdrawn.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return The amount of ETH && Tokens withdrawn.
   */
  function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) public returns (uint256, uint256) {
    require(amount > 0 && deadline > block.timestamp && min_eth > 0 && min_tokens > 0);
    uint256 total_liquidity = _totalSupply;
    require(total_liquidity > 0);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_amount = amount.mul(address(this).balance) / total_liquidity;
    uint256 token_amount = amount.mul(token_reserve) / total_liquidity;
    require(eth_amount >= min_eth && token_amount >= min_tokens);

    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    _totalSupply = total_liquidity.sub(amount);
    payable(msg.sender).transfer(eth_amount);
    require(token.transfer(msg.sender, token_amount));
    emit RemoveLiquidity(msg.sender, eth_amount, token_amount);
    emit Transfer(msg.sender, address(0), amount);
    return (eth_amount, token_amount);
  }


}
