// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "base64-sol/base64.sol";
import "../../security/Pausable.sol";
import "../interfaces/IWhiteListPeriodManager.sol";
import "../structures/LpTokenMetadata.sol";

contract LPToken is OwnableUpgradeable, Pausable, ERC721EnumerableUpgradeable, ERC2771ContextUpgradeable {
    using StringsUpgradeable for uint256;

    address public liquidityPoolAddress;
    IWhiteListPeriodManager public whiteListPeriodManager;
    mapping(uint256 => LpTokenMetadata) public tokenMetadata;

    event LiquidityPoolUpdated(address indexed lpm);
    event WhiteListPeriodManagerUpdated(address indexed manager);

    function initialize(
        string memory _name,
        string memory _symbol,
        address _trustedForwarder,
        address _pauser
    ) public initializer {
        __Ownable_init();
        __Pausable_init(_pauser);
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC2771Context_init(_trustedForwarder);
    }

    modifier onlyHyphenPools() {
        require(_msgSender() == liquidityPoolAddress, "ERR_UNAUTHORIZED");
        _;
    }

    function setLiquidtyPool(address _lpm) external onlyOwner {
        liquidityPoolAddress = _lpm;
        emit LiquidityPoolUpdated(_lpm);
    }

    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
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
        string memory svgData = getTokenSvg(tokenId);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name(),
                        '", "description": "", "image_data": "',
                        bytes(svgData),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function getTokenSvg(uint256 tokenId) public view returns (string memory) {
        require(exists(tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        string[6] memory lines;
        lines[0] = "<svg height='90' width='200'>";
        lines[1] = "<text x='10' y='20' style='fill:red;'>";
        lines[2] = string(
            abi.encodePacked(
                "<tspan x='10' y='45'>Total Supplied Liquidity: ",
                tokenMetadata[tokenId].suppliedLiquidity.toString(),
                "</tspan>"
            )
        );
        lines[3] = string(
            abi.encodePacked(
                "<tspan x='10' y='45'>Total Shares: ",
                tokenMetadata[tokenId].shares.toString(),
                "</tspan>"
            )
        );
        lines[4] = "</text>";
        lines[5] = "</svg>";
        return string(abi.encodePacked(lines[0], lines[1], lines[2], lines[3], lines[4], lines[5]));
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
