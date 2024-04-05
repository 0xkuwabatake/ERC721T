// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721T} from "src/ERC721T.sol";

contract SimpleERC721T is ERC721T {
    error ArrayLengthsMismatch();

    constructor() ERC721T("Simple ERC721T", "S721T") {}

    function getTierId(uint256 tokenId) public view returns (uint256) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _tierId[tokenId];
    }

    function getTierURI(uint256 tierId) public view returns (string memory) {
        if (bytes(_tierURI[tierId]).length == 0) revert TierDoesNotExist();
        return _tierURI[tierId];
    }

    function mint(address to, uint256 tierId) public {
        _mintTier(to, tierId);
    }

    function airdrop(address[] calldata receivers, uint256 tierId) public {
        for (uint256 i = 0; i < receivers.length;) {
            if (bytes(_tierURI[tierId]).length == 0) revert TierDoesNotExist();
            _mintTier(receivers[i], tierId);
            unchecked { ++i; }   
        }
    }

    function burn(address owner, uint256 tokenId) public {
        _burnTier(owner, tokenId);
    }

    function batchBurn(address[] calldata owners, uint256[] calldata tokenIds) public {
        if (owners.length != tokenIds.length) revert ArrayLengthsMismatch();
        for (uint256 i = 0; i < owners.length;) {
            _burnTier(owners[i], tokenIds[i]);
            unchecked { ++i; }   
        }
    }

    function setTierURI(uint256 tierId, string calldata tierURI) public {
        _setTierURI(tierId, tierURI);
    }
}