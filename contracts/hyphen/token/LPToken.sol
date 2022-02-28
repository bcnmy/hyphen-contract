// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "../interfaces/IWhiteListPeriodManager.sol";
import "../structures/LpTokenMetadata.sol";

contract LPToken is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721PausableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC2771ContextUpgradeable
{
    address public liquidityPoolAddress;
    IWhiteListPeriodManager public whiteListPeriodManager;
    mapping(uint256 => LpTokenMetadata) public tokenMetadata;

    event LiquidityPoolUpdated(address indexed lpm);
    event WhiteListPeriodManagerUpdated(address indexed manager);

    function initialize(
        string memory _name,
        string memory _symbol,
        address _trustedForwarder
    ) public initializer {
        __Ownable_init();
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC721Pausable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __ERC2771Context_init(_trustedForwarder);
    }

    modifier onlyHyphenPools() {
        require(_msgSender() == liquidityPoolAddress, "ERR_UNAUTHORIZED");
        _;
    }

    function setLiquidityPool(address _lpm) external onlyOwner {
        require(_lpm != address(0), "ERR_INVALID_LPM");
        liquidityPoolAddress = _lpm;
        emit LiquidityPoolUpdated(_lpm);
    }

    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
        require(_whiteListPeriodManager != address(0), "ERR_INVALID_WHITELIST_PERIOD_MANAGER");
        whiteListPeriodManager = IWhiteListPeriodManager(_whiteListPeriodManager);
        emit WhiteListPeriodManagerUpdated(_whiteListPeriodManager);
    }

    function getAllNftIdsByUser(address _owner) public view returns (uint256[] memory) {
        uint256[] memory nftIds = new uint256[](balanceOf(_owner));
        for (uint256 i = 0; i < nftIds.length; ++i) {
            nftIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return nftIds;
    }

    function mint(address _to) external onlyHyphenPools whenNotPaused nonReentrant returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(_to, tokenId);
        return tokenId;
    }

    function updateTokenMetadata(uint256 _tokenId, LpTokenMetadata memory _lpTokenMetadata)
        external
        onlyHyphenPools
        whenNotPaused
    {
        require(_exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        tokenMetadata[_tokenId] = _lpTokenMetadata;
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);

        // Only call whitelist period manager for NFT Transfers, not mint and burns
        if (from != address(0) && to != address(0)) {
            whiteListPeriodManager.beforeLiquidityTransfer(
                from,
                to,
                tokenMetadata[tokenId].token,
                tokenMetadata[tokenId].suppliedLiquidity
            );
        }
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        ERC721URIStorageUpgradeable._burn(tokenId);
    }
}
