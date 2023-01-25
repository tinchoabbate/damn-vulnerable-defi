// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "solady/src/auth/OwnableRoles.sol";

/**
 * @title DamnValuableNFT
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice Implementation of a mintable and burnable NFT with role-based access controls
 */
contract DamnValuableNFT is ERC721, ERC721Burnable, OwnableRoles {
    uint256 public constant MINTER_ROLE = _ROLE_0;
    uint256 public tokenIdCounter;

    constructor() ERC721("DamnValuableNFT", "DVNFT") {
        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, MINTER_ROLE);
    }

    function safeMint(address to) public onlyRoles(MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = tokenIdCounter;
        _safeMint(to, tokenId);
        ++tokenIdCounter;
    }
}
