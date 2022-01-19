// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./metatx/ERC2771ContextUpgradeable.sol";
import "./interfaces/ILiquidityPool.sol";

contract WhitelistPeriodManager is Initializable, OwnableUpgradeable, PausableUpgradeable, ERC2771ContextUpgradeable {
    ILiquidityPool public liquidityPool;
    bool public areWhiteListRestrictionsEnabled;

    /* LP Status */
    // EOA? -> status
    mapping(address => bool) public isInstitutionalLp;
    // Token -> Community EOA -> TVL
    mapping(address => mapping(address => uint256)) public liquidityAddedByCommunityLp;
    // Token -> TVL
    mapping(address => uint256) public totalLiquidityAddedByCommunityLps;
    // Token -> TVL
    mapping(address => uint256) public totalLiquidityAddedByInstitutionalLps;

    /* Caps */
    // Token Address -> Limit
    mapping(address => uint256) public perTokenTotalCap;
    // Token Address -> Limit
    mapping(address => uint256) public perTokenCommunityCap;
    // Token Address -> Limit
    mapping(address => uint256) public perWalletTotalCapForCommunityLp;

    event InstitutionalLpStatusUpdated(address indexed lp, bool indexed status);
    event TotalCapUpdated(address indexed token, uint256 totalCap);
    event TotalCommunityCapUpdated(address indexed token, uint256 communityCap);
    event PerWalletTotalCapForCommunityLpUpdated(address indexed token, uint256 perCommunityWalletCap);
    event WhiteListStatusUpdated(bool status);

    modifier onlyLiquidityPool() {
        require(_msgSender() == address(liquidityPool), "ERR__UNAUTHORIZED");
        _;
    }

    modifier onlyLpNft() {
        require(_msgSender() == liquidityPool.lpToken(), "ERR__UNAUTHORIZED");
        _;
    }

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function initialize(address _trustedForwarder, address _liquidityPool) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        __Pausable_init();
        liquidityPool = ILiquidityPool(_liquidityPool);
        areWhiteListRestrictionsEnabled = true;
    }

    /**
     * @dev Internal Function which checks for various caps before allowing LP to add liqudity
     */
    function _beforeLiquidityAddition(
        address _lp,
        address _token,
        uint256 _amount
    ) internal {
        // Per Token Total Cap or PTTC
        require(
            ifEnabled(
                totalLiquidityAddedByCommunityLps[_token] + totalLiquidityAddedByInstitutionalLps[_token] + _amount <=
                    perTokenTotalCap[_token]
            ),
            "ERR__LIQUIDITY_EXCEEDS_PTTC"
        );
        if (isInstitutionalLp[_lp]) {
            totalLiquidityAddedByInstitutionalLps[_token] += _amount;
        } else {
            // Community Per Wallet Cap or CPWC
            require(
                ifEnabled(
                    liquidityAddedByCommunityLp[_token][_lp] + _amount <= perWalletTotalCapForCommunityLp[_token]
                ),
                "ERR__LIQUIDITY_EXCEEDS_CPWC"
            );
            // Community Total Cap or CTC
            require(
                ifEnabled(totalLiquidityAddedByCommunityLps[_token] + _amount <= perTokenCommunityCap[_token]),
                "ERR__LIQUIDITY_EXCEEDS_CTC"
            );
            liquidityAddedByCommunityLp[_token][_lp] += _amount;
            totalLiquidityAddedByCommunityLps[_token] += _amount;
        }
    }

    /**
     * @dev External Function which checks for various caps before allowing LP to add liqudity. Only callable by LiquidityPoolManager
     */
    function beforeLiquidityAddition(
        address _lp,
        address _token,
        uint256 _amount
    ) external onlyLiquidityPool whenNotPaused {
        _beforeLiquidityAddition(_lp, _token, _amount);
    }

    /**
     * @dev Internal Function which checks for various caps before allowing LP to remove liqudity
     */
    function _beforeLiquidityRemoval(
        address _lp,
        address _token,
        uint256 _amount
    ) internal {
        if (isInstitutionalLp[_lp]) {
            totalLiquidityAddedByInstitutionalLps[_token] -= _amount;
        } else {
            liquidityAddedByCommunityLp[_token][_lp] -= _amount;
            totalLiquidityAddedByCommunityLps[_token] -= _amount;
        }
    }

    /**
     * @dev External Function which checks for various caps before allowing LP to remove liqudity. Only callable by LiquidityPoolManager
     */
    function beforeLiquidityRemoval(
        address _lp,
        address _token,
        uint256 _amount
    ) external onlyLiquidityPool whenNotPaused {
        _beforeLiquidityRemoval(_lp, _token, _amount);
    }

    /**
     * @dev External Function which checks for various caps before allowing LP to transfer their LpNFT. Only callable by LpNFT contract
     */
    function beforeLiquidityTransfer(
        address _from,
        address _to,
        address _token,
        uint256 _amount
    ) external onlyLpNft whenNotPaused {
        // Release limit from  _from
        _beforeLiquidityRemoval(_from, _token, _amount);

        // Block limit of _to
        _beforeLiquidityAddition(_to, _token, _amount);
    }

    function setLiquidityPool(ILiquidityPool _liquidityPool) external onlyOwner {
        liquidityPool = _liquidityPool;
    }

    function setInstitutionalLpStatus(address[] memory _addresses, bool[] memory _status) external onlyOwner {
        require(_addresses.length == _status.length, "ERR__LENGTH_MISMATCH");
        for (uint256 i = 0; i < _addresses.length; ++i) {
            isInstitutionalLp[_addresses[i]] = _status[i];
            emit InstitutionalLpStatusUpdated(_addresses[i], _status[i]);
        }
    }

    function setTotalCap(address _token, uint256 _totalCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        require(
            totalLiquidityAddedByCommunityLps[_token] + totalLiquidityAddedByInstitutionalLps[_token] <= _totalCap,
            "ERR__TOTAL_CAP_LESS_THAN_SL"
        );
        if (perTokenTotalCap[_token] != _totalCap) {
            perTokenTotalCap[_token] = _totalCap;
            emit TotalCapUpdated(_token, _totalCap);
        }
    }

    function setCommunityCap(address _token, uint256 _communityCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        require(totalLiquidityAddedByCommunityLps[_token] <= _communityCap, "ERR__TOTAL_CAP_LESS_THAN_CSL");
        if (perTokenCommunityCap[_token] != _communityCap) {
            perTokenCommunityCap[_token] = _communityCap;
            emit TotalCommunityCapUpdated(_token, _communityCap);
        }
    }

    /**
     * @dev Special care must be taken when calling this function
     *      There are no checks for _perCommunityWalletCap (since it's onlyOwner), but it's essential that it 
     *      should be >= max lp provided by a community lp
     *      Checking this on chain will probably require implementing a binary max heap, which needs more bandwidth
     *      Call the view function getMaxCommunityLpPositon() separately before changing this value
     */
    function setPerCommunityWalletCap(address _token, uint256 _perCommunityWalletCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        if (perWalletTotalCapForCommunityLp[_token] != _perCommunityWalletCap) {
            perWalletTotalCapForCommunityLp[_token] = _perCommunityWalletCap;
            emit PerWalletTotalCapForCommunityLpUpdated(_token, _perCommunityWalletCap);
        }
    }

    function setCap(
        address _token,
        uint256 _totalCap,
        uint256 _communityCap,
        uint256 _perCommunityWalletCap
    ) public onlyOwner {
        setTotalCap(_token, _totalCap);
        setCommunityCap(_token, _communityCap);
        setPerCommunityWalletCap(_token, _perCommunityWalletCap);
    }

    function setCaps(
        address[] memory _tokens,
        uint256[] memory _totalCaps,
        uint256[] memory _communityCaps,
        uint256[] memory _perCommunityWalletCaps
    ) external onlyOwner {
        require(
            _tokens.length == _totalCaps.length &&
                _totalCaps.length == _communityCaps.length &&
                _communityCaps.length == _perCommunityWalletCaps.length,
            "ERR__LENGTH_MISMACH"
        );
        for (uint256 i = 0; i < _tokens.length; ++i) {
            setCap(_tokens[i], _totalCaps[i], _communityCaps[i], _perCommunityWalletCaps[i]);
        }
    }

    /**
     * @dev Enables (or disables) reverts if liquidity exceeds caps. 
     *      Even if this is disabled, the contract will continue to track LP's positions
     */
    function setAreWhiteListRestrictionsEnabled(bool _status) external onlyOwner {
        areWhiteListRestrictionsEnabled = _status;
        emit WhiteListStatusUpdated(_status);
    }

    /**
     * @dev returns the value of if (areWhiteListEnabled) then (_cond)
     */
    function ifEnabled(bool _cond) private view returns (bool) {
        return !areWhiteListRestrictionsEnabled || (areWhiteListRestrictionsEnabled && _cond);
    }

    /**
     * @dev Meta-Transaction Helper, returns msgSender
     */
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgData
     */
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}
