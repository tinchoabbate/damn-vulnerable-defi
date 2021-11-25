// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./TrustfulOracle.sol";
import "../DamnValuableNFT.sol";

/**
 * @title Exchange
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Exchange is ReentrancyGuard {
    using Address for address payable;

    DamnValuableNFT public immutable token;
    TrustfulOracle public immutable oracle;

    event TokenBought(address indexed buyer, uint256 tokenId, uint256 price);
    event TokenSold(address indexed seller, uint256 tokenId, uint256 price);

    constructor(address oracleAddress) payable {
        token = new DamnValuableNFT();
        oracle = TrustfulOracle(oracleAddress);
    }

    function buyOne() external payable nonReentrant returns (uint256) {
        uint256 amountPaidInWei = msg.value;
        require(amountPaidInWei > 0, "Amount paid must be greater than zero");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(amountPaidInWei >= currentPriceInWei, "Amount paid is not enough");

        uint256 tokenId = token.safeMint(msg.sender);

        payable(msg.sender).sendValue(amountPaidInWei - currentPriceInWei);

        emit TokenBought(msg.sender, tokenId, currentPriceInWei);

        return tokenId;
    }

    function sellOne(uint256 tokenId) external nonReentrant {
        require(msg.sender == token.ownerOf(tokenId), "Seller must be the owner");
        require(token.getApproved(tokenId) == address(this), "Seller must have approved transfer");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(address(this).balance >= currentPriceInWei, "Not enough ETH in balance");

        token.transferFrom(msg.sender, address(this), tokenId);
        token.burn(tokenId);

        payable(msg.sender).sendValue(currentPriceInWei);

        emit TokenSold(msg.sender, tokenId, currentPriceInWei);
    }

    receive() external payable {}
}
