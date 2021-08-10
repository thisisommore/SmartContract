//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract NetSepio is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable
{
    using Counters for Counters.Counter;

    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;

    struct WebsiteReview {
        string domainName;
        string websiteURL;
        string websiteType;
        string websiteTag;
        string websiteSafety;
        string metadataHash;
    }

    mapping(uint256 => WebsiteReview) public WebsiteReviews;

    event ReviewCreation(address indexed minter, uint256 indexed tokenId, uint256 indexed timestamp);
    event ReviewDeletion(address indexed ownerOrApproved, uint256 indexed tokenId, uint256 indexed timestamp);
    event ReviewUpdate(address indexed ownerOrApproved, uint256 indexed tokenId, string oldMetadataHash, string newMetadatHash, uint256 indexed timestamp);

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `VOTER_ROLE` and `MODERATOR_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(VOTER_ROLE, _msgSender());
        _setupRole(MODERATOR_ROLE, _msgSender());
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_safeMint}.
     *
     * Requirements:
     *
     * - the caller must have the `VOTER_ROLE`.
     */
    function createReview(string memory _domainName, string memory _websiteURL, string memory _websiteType, string memory _websiteTag, string memory _websiteSafety, string memory _metadataHash) public virtual {
        require(hasRole(VOTER_ROLE, _msgSender()), "NetSepio: must have voter role to submit review");

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(_msgSender(), tokenId);
        
        // Create Mapping
        WebsiteReview memory websiteReview = WebsiteReview({
            domainName: _domainName,
            websiteURL: _websiteURL,
            websiteType: _websiteType,
            websiteTag: _websiteTag,
            websiteSafety: _websiteSafety,
            metadataHash: _metadataHash
        });
        WebsiteReviews[tokenId] = websiteReview;

        _tokenIdTracker.increment();
        emit ReviewCreation(_msgSender(), tokenId, block.timestamp);
    }

    /**
     * @dev Destroys (Burns) an existing `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function deleteReview(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NetSepio: caller is not owner nor approved to delete review");
        
        // destroy (burn) the token.
        _burn(tokenId);
        emit ReviewDeletion(_msgSender(), tokenId, block.timestamp);
    }

    /**
    * @dev Reads the metadata of a specified token. Returns the current data in
    * storage of `tokenId`.
    *
    * @param tokenId The token to read the data off.
    *
    * @return A string representing the current metadataHash mapped with the tokenId.
    */
    function readMetadata(uint256 tokenId) public virtual view returns (string memory) {
        return WebsiteReviews[tokenId].metadataHash;
    }

    /**
    * @dev Updates the metadata of a specified token. Writes `newMetadataHash` into storage
    * of `tokenId`.
    *
    * @param tokenId The token to write metadata to.
    * @param newMetadataHash The metadata to be written to the token.
    *
    * Emits a `ReviewUpdate` event.
    */
    function updateReview(uint256 tokenId, string memory newMetadataHash) public virtual {
        require(hasRole(VOTER_ROLE, _msgSender()), "NetSepio: caller is not owner nor approved to update review");

        emit ReviewUpdate(_msgSender(), tokenId, WebsiteReviews[tokenId].metadataHash, newMetadataHash, block.timestamp);
        WebsiteReviews[tokenId].metadataHash = newMetadataHash;
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `MODERATOR_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(MODERATOR_ROLE, _msgSender()), "NetSepio: must have moderator role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `MODERATOR_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(MODERATOR_ROLE, _msgSender()), "NetSepio: must have moderator role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
