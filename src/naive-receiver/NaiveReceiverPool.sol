// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashLenderSymbolic} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {FlashLoanReceiver} from "./FlashLoanReceiver.sol";
import {Multicall} from "./Multicall.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import "forge-std/console.sol";
import {Test, console} from "forge-std/Test.sol";
import "../../lib/halmos-cheatcodes/src/SymTest.sol";
import "../../lib/SharedGlobalData.sol";

contract NaiveReceiverPool is Multicall, IERC3156FlashLenderSymbolic, /*SymTest,*/ Test {
    uint256 private constant FIXED_FEE = 1e18; // not the cheapest flash loan
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    WETH public immutable weth;
    address public immutable trustedForwarder;
    address public immutable feeReceiver;

    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    error RepayFailed();
    error UnsupportedCurrency();
    error CallbackFailed();

    constructor(address _trustedForwarder, address payable _weth, address _feeReceiver) payable {
        weth = WETH(_weth);
        trustedForwarder = _trustedForwarder;
        feeReceiver = _feeReceiver;
        _deposit(msg.value);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (token == address(weth)) return weth.balanceOf(address(this));
        return 0;
    }

    function flashFee(address token, uint256) external view returns (uint256) {
        if (token != address(weth)) revert UnsupportedCurrency();
        return FIXED_FEE;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount/*, bytes calldata data*/)
        external
        returns (bool)
    {
        receiver = IERC3156FlashBorrower(shared_data.get_known_address(address(receiver)));
        bytes memory data1 = svm.createBytes(100, 'data1');
        if (token != address(weth)) revert UnsupportedCurrency();
        weth.transfer(address(receiver), amount);
        totalDeposits -= amount;
        if (receiver.onFlashLoan(msg.sender, address(weth), amount, FIXED_FEE, data1) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }
        uint256 amountWithFee = amount + FIXED_FEE;
        weth.transferFrom(address(receiver), address(this), amountWithFee);
        totalDeposits += amountWithFee;
        deposits[feeReceiver] += FIXED_FEE;
        return true;
    }

    function withdraw(/*uint256 amount,*/ address payable receiver) external {
        uint256 amount = svm.createUint256('withdraw_amount');
        console.log ("withdraw");
        // Reduce deposits
        deposits[_msgSender()] -= amount;
        totalDeposits -= amount;

        // Transfer ETH to designated receiver
        weth.transfer(receiver, amount);
    }

    function pseudo_withdraw(address payable receiver) external {
        console.log("pseudo withdraw");
    }

    function deposit() external payable {
        console.log("deposit");
        _deposit(msg.value);
    }

    function _deposit(uint256 amount) private {
        weth.deposit{value: amount}();
        deposits[_msgSender()] += amount;
        totalDeposits += amount;
    }

    function _msgSender() internal view override returns (address) {
        if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            console.log("forwarded from ", address(bytes20(msg.data[msg.data.length - 20:])));
            return address(bytes20(msg.data[msg.data.length - 20:]));
        } else {
            return super._msgSender();
        }
    }
}
