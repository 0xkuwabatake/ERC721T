// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721} from "solady/tokens/ERC721.sol";

/// @title ERC721-T
/// @author 0xkuwabatake (@0xkuwabatake)
/// @notice Abstract ERC721 contract with tier-based structure and sequential minting, 
///         using extra data packing for efficiency.
/// @dev    Extends Solady's ERC721 and modifies it to support sequential minting 
///         while mapping tokens to tiers via bitwise operations.
abstract contract ERC721T is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Maximum tier ID is 72057594037927935.
    uint56 internal constant _MAX_TIER_ID = 0xFFFFFFFFFFFFFF;

    /// @dev Bit position for tier ID in extra data.
    uint96 private constant _BITPOS_TIER_ID = 56;

    /// @dev Bit position for number of minted tokens in aux data.
    uint224 private constant _BITPOS_NUMBER_MINTED = 32;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Tracks the next token ID to be minted.
    uint256 private _currentIndex;

    /// @dev Tracks the number of burned tokens.
    uint256 internal _burnCounter;

    /// @dev Name of the token collection.
    string private _name;

    /// @dev Symbol of the token collection.
    string private _symbol;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when a token is set to a tier.
    event TierSet(uint256 indexed tokenId, uint56 indexed tierId, uint40 atTimestamp);

    /// @dev Emitted when multiple tokens are set to a tier in batch minting.
    event BatchTierSet(
        uint256 indexed startId,
        uint256 indexed endId,
        uint56 indexed tierId,
        uint40 atTimestamp
    );

    /// @dev Emitted when a token's tier is reset (burned).
    event TierReset(uint256 indexed tokenId, uint56 indexed tierId);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Unable to cast to the target type due to overflow.
    error Overflow();

    /// @dev Reverts if the tier ID is zero.
    error TierCanNotBeZero();

    /// @dev Reverts if the tier ID exceeds maximum tier ID.
    error TierExceedsMaximumTierID();

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @dev Ensures the tier ID is not zero.
    modifier OnlyValidTier(uint56 tier) {
        _validateTierId(tier);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @dev Returns the token URI for a given token ID.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _rv(uint32(TokenDoesNotExist.selector));
        return "";
    }

    /// @dev Returns the tier ID associated with a token.
    function tierId(uint256 tokenId) public view returns (uint56) {
        return _toUint56FromUint96(_getExtraData(tokenId));
    }

    /// @dev Returns the timestamp when the token was minted.
    function mintTimestamp(uint256 tokenId) public view returns (uint40) {
        return _toUint40FromUint96(_getExtraData(tokenId) >> _BITPOS_TIER_ID);
    }

    /// @dev Returns the number of tokens minted by an address.
    function numberMinted(address addr) public view returns (uint32) {
        return _toUint32FromUint224(_getAux(addr));
    }

    /// @dev Returns the total supply of tokens in circulation.
    function totalSupply() public view returns (uint256) {
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints multiple tokens with the same tier in a single batch.
    function _batchMintTier(
        address to,
        uint56 tier,
        uint256 quantity
    ) internal OnlyValidTier(tier) {
        uint256 startTokenId = _currentIndex;  
        uint256 endTokenId = startTokenId + quantity;

        unchecked { _currentIndex += quantity; }

        for (uint256 i = 0; i < quantity;) {
            _mint(to, startTokenId + i);
            unchecked { ++i; }
        }

        for (uint256 i = 0; i < quantity;) {
            _setMintExtraData(startTokenId + i, tier);
            unchecked { ++i; }
        }

        emit BatchTierSet(startTokenId, endTokenId, tier, _toUint40FromUint256(block.timestamp));
    }

    /// @dev Safely mints multiple tokens with the same tier in a single batch.
    function _batchSafeMintTier(
        address to,
        uint56 tier,
        uint256 quantity
    ) internal OnlyValidTier(tier) {
        uint256 startTokenId = _currentIndex;  
        uint256 endTokenId = startTokenId + quantity;

        unchecked { _currentIndex += quantity; }

        for (uint256 i = 0; i < quantity;) {
            _safeMint(to, startTokenId + i);
            unchecked { ++i; }
        }

        for (uint256 i = 0; i < quantity;) {
            _setMintExtraData(startTokenId + i, tier);
            unchecked { ++i; }
        }

        emit BatchTierSet(startTokenId, endTokenId, tier, _toUint40FromUint256(block.timestamp));
    }

    /// @dev Mints a token and assigns it a tier.
    function _mintTier(address to, uint56 tier) internal OnlyValidTier(tier) {
        uint256 tokenId = _currentIndex;
        unchecked { ++tokenId; }
        _mint(to, tokenId);
        _setMintExtraData(tokenId, tier);
        emit TierSet(tokenId, tier, _toUint40FromUint256(block.timestamp));
    }

    /// @dev Safely mints a token and assigns it a tier.
    function _safeMintTier(address to, uint56 tier) internal OnlyValidTier(tier) {
        uint256 tokenId = _currentIndex;
        unchecked { ++tokenId; }
        _safeMint(to, tokenId);
        _setMintExtraData(tokenId, tier);
        emit TierSet(tokenId, tier, _toUint40FromUint256(block.timestamp));
    }

    /// @dev Burns a token and resets its tier data.
    function _burnTier(uint256 tokenId) internal {
        unchecked { ++_burnCounter; }
        _resetMintExtraData(tokenId);
        _burn(tokenId);
        emit TierReset(tokenId, tierId(tokenId));
    }

    /// @dev Burns a token on behalf of an address and resets its tier data.
    function _burnTier(address by, uint256 tokenId) internal {
        unchecked { ++_burnCounter; }
        _resetMintExtraData(tokenId);
        _burn(by, tokenId);
        emit TierReset(tokenId, tierId(tokenId));
    }

    /// @dev Sets the extra data for a token to store tier and timestamp.
    function _setMintExtraData(uint256 tokenId, uint56 tier) internal {
        uint96 packed = uint96(tier) | uint96(block.timestamp) << _BITPOS_TIER_ID; 
        _setExtraData(tokenId, packed);
    }

    /// @dev Resets the extra data of a token.
    function _resetMintExtraData(uint256 tokenId) internal {
        _setExtraData(tokenId, 0);
    }

    /// @dev Sets the number of tokens minted by an address.
    function _setNumberMinted(address addr, uint32 value) internal {
        _setAux(addr, value);
    }

    /// @dev Returns the starting token ID. Override this function to change the starting token ID.
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /// @dev Returns the next token ID to be minted.
    function _nextTokenId() internal view returns (uint256) {
        return _currentIndex;
    }

    /// @dev Returns the total number of burned tokens.
    function _totalBurned() internal view returns (uint256) {
        return _burnCounter;
    }

    /// @dev Reverts if the tier ID is zero or bigger than maximum tier ID.
    function _validateTierId(uint56 tier) internal pure {
        if (tier == 0) _rv(uint32(TierCanNotBeZero.selector));
        if (tier > _MAX_TIER_ID) _rv(uint32(TierExceedsMaximumTierID.selector));
    }

    /// @dev Converts a uint256 value to a string.
    function _toString(uint256 value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20))
            mstore(result, 0)
            let end := result
            let w := not(0)
            for { let temp := value } 1 {} {
                result := add(result, w)
                mstore8(result, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let n := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, n)
        }
    }

    /// @dev Efficient way to revert with a specific error code.
    function _rv(uint32 s) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, s)
            revert(0x1c, 0x04)
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Safely casts `x` to uint32. Reverts on overflow.
    function _toUint32FromUint224(uint224 x) private pure returns (uint32) {
        if (x >= 1 << 32) _rv(uint32(Overflow.selector));
        return uint32(x);
    }

    /// @dev Safely casts `x` to uint40. Reverts on overflow.
    function _toUint40FromUint96(uint96 x) private pure returns (uint40) {
        if (x >= 1 << 40) _rv(uint32(Overflow.selector));
        return uint40(x);
    }

    /// @dev Safely casts `x` to uint40. Reverts on overflow.
    function _toUint40FromUint256(uint256 x) private pure returns (uint40) {
        if (x >= 1 << 40) _rv(uint32(Overflow.selector));
        return uint40(x);
    }

    /// @dev Safely casts `x` to uint56. Reverts on overflow.
    function _toUint56FromUint96(uint96 x) private pure returns (uint56) {
        if (x >= 1 << 56) _rv(uint32(Overflow.selector));
        return uint56(x);
    }
}