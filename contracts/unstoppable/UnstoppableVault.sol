// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/src/utils/FixedPointMathLib.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import {SafeTransferLib, ERC4626, ERC20} from "solmate/src/mixins/ERC4626.sol";
import "solmate/src/auth/Owned.sol";
import {IERC3156FlashBorrower, IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156.sol";

/**
 * @title UnstoppableVault
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract UnstoppableVault is
    IERC3156FlashLender,
    ReentrancyGuard,
    Owned,
    ERC4626
{
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 public constant FEE_FACTOR = 0.05 ether;
    uint64 public constant GRACE_PERIOD = 30 days;

    uint64 public immutable end = uint64(block.timestamp) + GRACE_PERIOD;

    address public feeRecipient;

    error InvalidAmount(uint256 amount);
    error InvalidBalance();
    error CallbackFailed();
    error UnsupportedCurrency();

    event FeeRecipientUpdated(address indexed newFeeRecipient);

    constructor(
        ERC20 _token,
        address _owner,
        address _feeRecipient
    )
        /**
         * asset = _token;
         * */
        ERC4626(_token, "Oh Damn Valuable Token", "oDVT")
        Owned(_owner)
    {
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @return balanceof[#UNS] from #DVT
     */
    function maxFlashLoan(address _token) public view returns (uint256) {
        if (address(asset) != _token) return 0;

        return totalAssets();
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @return fee = 5 * 10^22 wei if _amount is balanceof[#UNS] from #DVT else 0 wei
     */
    function flashFee(
        address _token, // #DVT
        uint256 _amount // amount to be taken for loan
    ) public view returns (uint256 fee) {
        if (address(asset) != _token) revert UnsupportedCurrency();

        if (block.timestamp < end && _amount < maxFlashLoan(_token)) {
            return 0;
        } else {
            /**
             *
             * @return 5 * 10 ** 22 or 5 * 10^22 wei
             */
            return _amount.mulWadUp(FEE_FACTOR);
        }
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient != address(this)) {
            feeRecipient = _feeRecipient;
            emit FeeRecipientUpdated(_feeRecipient);
        }
    }

    /**
     * @inheritdoc ERC4626
     * @return balanceof[#UNS] from #DVT
     */
    function totalAssets() public view override returns (uint256) {
        assembly {
            // better safe than sorry
            if eq(sload(0), 2) {
                mstore(0x00, 0xed3ba6a6)
                revert(0x1c, 0x04)
            }
        }
        return asset.balanceOf(address(this));
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @dev checks :
     * 1) amount can not be zero,
     * 2) asset = #DVT(enforce ERC3156 requirement)
     * 3) token.balanceOf[this(#UNS)]
     * 4) converts totalSupply to shares // might need to look into it to_hack.
     * 5) fee is mostly 0, will look later in detail.
     * 6) token.balanceOf[#UNS] - amount && token.balanceOf[reciever] + amount
     * 7) token.allowance(msg.sender, pool(#UNS)) -> amount
     * 8) token.balanceOF(this(#UNS)) + amount
     * below value doesnot go to negative 0 is the end :
     * 9) balanceOf(receiver) - (amount + fee) (100)
     * 10) token.allowance(receiver, this(#UNS)) - (amount + fee) (100)
     * 11) adds fee to balanceOf(feeRecipient) from token.
     * 12) removes fee from balanceOf(caller) from token.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address _token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        if (amount == 0) revert InvalidAmount(0); // fail early

        if (address(asset) != _token) revert UnsupportedCurrency(); // enforce ERC3156 requirement

        uint256 balanceBefore = totalAssets();

        if (convertToShares(totalSupply) != balanceBefore)
            revert InvalidBalance(); // enforce ERC4626 requirement

        uint256 fee = flashFee(_token, amount);

        // transfer tokens out + execute callback on receiver
        // transfers tokens from callers address to address(receiver)
        // because here assumption made caller is owner.
        // 1)token.balanceOf[caller(#UNS)] - amount
        // 2)token.balanceOf[receiver] + amount
        ERC20(_token).safeTransfer(address(receiver), amount);

        // callback must return magic value, otherwise assume it failed
        /**
         * @dev
         * 1) msg.sender needs to be #REC
         * 2) caller has to be #UNS
         * 3) token needs to be #DVT
         * 4) fee should be 0
         * 5) token.allowance(initiator, pool(#UNS)) -> amount
         */
        if (
            receiver.onFlashLoan(
                msg.sender,
                address(asset),
                amount,
                fee,
                data
            ) != keccak256("IERC3156FlashBorrower.onFlashLoan")
        ) revert CallbackFailed();

        // pull amount + fee from receiver, then pay the fee to the recipient
        /**
         * @dev 1) token.balanceOF(this(#UNS)) + (amount)
         * below value doesnot go to negative 0 is the end :
         * 2) token.balanceOf(receiver) - (amount + fee) (100)
         * 3) token.allowance(receiver, this(#UNS)) - (amount + fee) (100)
         */
        ERC20(_token).safeTransferFrom(
            address(receiver),
            address(this),
            amount + fee
        );

        /**
         * @dev 1) adds fee to balanceOf(feeRecipient) from token.
         *      2) removes fee from balanceOf(caller) from token.
         */
        ERC20(_token).safeTransfer(feeRecipient, fee);
        return true;
    }

    /**
     * @inheritdoc ERC4626
     */
    function beforeWithdraw(
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant {}

    /**
     * @inheritdoc ERC4626
     */
    function afterDeposit(
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant {}
}
