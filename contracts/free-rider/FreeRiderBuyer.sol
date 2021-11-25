// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title FreeRiderBuyer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderBuyer is ReentrancyGuard, IERC721Receiver {
    using Address for address payable;
    address private immutable partner;
    IERC721 private immutable nft;
    uint256 private constant JOB_PAYOUT = 45 ether;
    uint256 private received;

    constructor(address _partner, address _nft) payable {
        require(msg.value == JOB_PAYOUT);
        partner = _partner;
        nft = IERC721(_nft);
        IERC721(_nft).setApprovalForAll(msg.sender, true);
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) external override nonReentrant returns (bytes4) {
        require(msg.sender == address(nft));
        require(tx.origin == partner);
        require(_tokenId >= 0 && _tokenId <= 5);
        require(nft.ownerOf(_tokenId) == address(this));

        received++;
        if (received == 6) {
            payable(partner).sendValue(JOB_PAYOUT);
        }

        return IERC721Receiver.onERC721Received.selector;
    }
}
