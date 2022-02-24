// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "base64-sol/base64.sol";
import "../../security/Pausable.sol";
import "../interfaces/IWhiteListPeriodManager.sol";
import "../interfaces/ILiquidityProviders.sol";
import "../interfaces/INFTSVG.sol";
import "../structures/LpTokenMetadata.sol";

contract LPToken is OwnableUpgradeable, Pausable, ERC721EnumerableUpgradeable, ERC2771ContextUpgradeable {
    using StringsUpgradeable for uint256;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public liquidityPoolAddress;
    string public description;
    ILiquidityProviders public liquidityProviders;
    IWhiteListPeriodManager public whiteListPeriodManager;
    mapping(uint256 => LpTokenMetadata) public tokenMetadata;
    mapping(address => ISVGNFT) public svgHelpers;

    event LiquidityPoolUpdated(address indexed lpm);
    event LiquidityProvidersUpdated(address indexed lpm);
    event WhiteListPeriodManagerUpdated(address indexed manager);
    event DescriptionUpdated(string indexed description);
    event SvgHelperUpdated(address indexed tokenAddress, ISVGNFT indexed svgHelper);

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _description,
        address _trustedForwarder,
        address _pauser
    ) public initializer {
        __Ownable_init();
        __Pausable_init(_pauser);
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC2771Context_init(_trustedForwarder);
        description = _description;
    }

    function setSvgHelper(address _tokenAddress, ISVGNFT _svgHelper) public onlyOwner {
        svgHelpers[_tokenAddress] = _svgHelper;
        emit SvgHelperUpdated(_tokenAddress, _svgHelper);
    }

    modifier onlyHyphenPools() {
        require(_msgSender() == liquidityPoolAddress, "ERR_UNAUTHORIZED");
        _;
    }

    function setLiquidtyPool(address _lpm) external onlyOwner {
        liquidityPoolAddress = _lpm;
        emit LiquidityPoolUpdated(_lpm);
    }

    function setLiquidtyProviders(address _lp) external onlyOwner {
        liquidityProviders = ILiquidityProviders(_lp);
        emit LiquidityProvidersUpdated(_lp);
    }

    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
        whiteListPeriodManager = IWhiteListPeriodManager(_whiteListPeriodManager);
        emit WhiteListPeriodManagerUpdated(_whiteListPeriodManager);
    }

    function setDescription(string memory _description) external onlyOwner {
        description = _description;
        emit DescriptionUpdated(_description);
    }

    function getAllNftIdsByUser(address _owner) public view returns (uint256[] memory) {
        uint256[] memory nftIds = new uint256[](balanceOf(_owner));
        for (uint256 i = 0; i < nftIds.length; ++i) {
            nftIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return nftIds;
    }

    function mint(address _to) external onlyHyphenPools whenNotPaused returns (uint256) {
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

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable) returns (string memory) {
        address tokenAddress = tokenMetadata[tokenId].token;
        require(svgHelpers[tokenAddress] != ISVGNFT(address(0)), "ERR__SVG_HELPER_NOT_REGISTERED");

        string memory svgData = svgHelpers[tokenAddress].getTokenSvg(
            tokenId,
            tokenMetadata[tokenId].suppliedLiquidity,
            liquidityProviders.totalReserve(tokenAddress)
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name(),
                        '", "description": "',
                        description,
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svgData)),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function updateLiquidityPoolAddress(address _liquidityPoolAddress) external onlyOwner {
        liquidityPoolAddress = _liquidityPoolAddress;
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
    ) internal virtual override(ERC721EnumerableUpgradeable) whenNotPaused {
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

    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable) {
        super._burn(tokenId);
    }
}
