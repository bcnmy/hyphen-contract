// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./metatx/ERC2771ContextUpgradeable.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/ILPToken.sol";
import "hardhat/console.sol";

contract WhitelistPeriodManager is Initializable, OwnableUpgradeable, PausableUpgradeable, ERC2771ContextUpgradeable {
    ILiquidityPool public liquidityPool;
    bool public areWhiteListRestrictionsEnabled;

    /* LP Status */
    // EOA? -> status
    mapping(address => bool) public isInstitutionalLp;
    // EOA? -> status, stores addresses that we want to ignore, like staking contracts.
    mapping(address => bool) public isExcludedAddress;
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
    mapping(address => uint256) public perWalletCapForCommunityLp;

    event InstitutionalLpStatusUpdated(address indexed lp, bool indexed status);
    event ExcludedAddressStatusUpdated(address indexed lp, bool indexed status);
    event TotalCapUpdated(address indexed token, uint256 totalCap);
    event TotalCommunityCapUpdated(address indexed token, uint256 communityCap);
    event PerWalletCapForCommunityLpUpdated(address indexed token, uint256 perCommunityWalletCap);
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
        if (isExcludedAddress[_lp]) {
            return;
        }
        // Per Token Total Cap or PTTC
        require(
            ifEnabled(
                totalLiquidityAddedByCommunityLps[_token] + totalLiquidityAddedByInstitutionalLps[_token] + _amount <=
                    perTokenTotalCap[_token]
            ),
            "ERR__LIQUIDITY_EXCEEDS_PTTC"
        );
        if (isInstitutionalLp[_lp]) {
            // Institution Total Cap or ITT
            require(
                ifEnabled(
                    totalLiquidityAddedByInstitutionalLps[_token] + _amount <=
                        perTokenTotalCap[_token] - perTokenCommunityCap[_token]
                ),
                "ERR_LIQUIDITY_EXCEEDS_ITC"
            );
            totalLiquidityAddedByInstitutionalLps[_token] += _amount;
        } else {
            // Community Per Wallet Cap or CPWC
            require(
                ifEnabled(liquidityAddedByCommunityLp[_token][_lp] + _amount <= perWalletCapForCommunityLp[_token]),
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
        if (isExcludedAddress[_lp]) {
            return;
        } else if (isInstitutionalLp[_lp]) {
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

    function setisExcludedAddressStatus(address[] memory _addresses, bool[] memory _status) external onlyOwner {
        require(_addresses.length == _status.length, "ERR__LENGTH_MISMATCH");
        for (uint256 i = 0; i < _addresses.length; ++i) {
            isExcludedAddress[_addresses[i]] = _status[i];
            emit ExcludedAddressStatusUpdated(_addresses[i], _status[i]);
        }
    }

    function setTotalCap(address _token, uint256 _totalCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        require(
            totalLiquidityAddedByCommunityLps[_token] + totalLiquidityAddedByInstitutionalLps[_token] <= _totalCap,
            "ERR__TOTAL_CAP_LESS_THAN_SL"
        );
        require(_totalCap >= perTokenCommunityCap[_token], "ERR__TOTAL_CAP_LT_PTCC");
        require(_totalCap >= perWalletCapForCommunityLp[_token], "ERR__TOTAL_CAP_LT_PWCFCL");
        if (perTokenTotalCap[_token] != _totalCap) {
            perTokenTotalCap[_token] = _totalCap;
            emit TotalCapUpdated(_token, _totalCap);
        }
    }

    function setCommunityCap(address _token, uint256 _communityCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        require(totalLiquidityAddedByCommunityLps[_token] <= _communityCap, "ERR__TOTAL_CAP_LESS_THAN_CSL");
        require(_communityCap <= perTokenTotalCap[_token], "ERR__COMM_CAP_GT_PTTC");
        require(_communityCap >= perWalletCapForCommunityLp[_token], "ERR__COMM_CAP_LT_PWCFCL");
        if (perTokenCommunityCap[_token] != _communityCap) {
            perTokenCommunityCap[_token] = _communityCap;
            emit TotalCommunityCapUpdated(_token, _communityCap);
        }
    }

    /**
     * @dev Special care must be taken when calling this function
     *      There are no checks for _perWalletCap (since it's onlyOwner), but it's essential that it
     *      should be >= max lp provided by a community lp
     *      Checking this on chain will probably require implementing a bbst, which needs more bandwidth
     *      Call the view function getMaxCommunityLpPositon() separately before changing this value
     */
    function setPerWalletCapForCommunityLp(address _token, uint256 _perWalletCap) public onlyOwner {
        require(liquidityPool.isTokenSupported(_token), "ERR__TOKEN_NOT_SUPPORTED");
        require(_perWalletCap <= perTokenTotalCap[_token], "ERR__PWC_GT_PTTC");
        require(_perWalletCap <= perTokenCommunityCap[_token], "ERR__PWC_GT_PTCC");
        if (perWalletCapForCommunityLp[_token] != _perWalletCap) {
            perWalletCapForCommunityLp[_token] = _perWalletCap;
            emit PerWalletCapForCommunityLpUpdated(_token, _perWalletCap);
        }
    }

    function setCap(
        address _token,
        uint256 _totalCap,
        uint256 _communityCap,
        uint256 _perWalletCap
    ) public onlyOwner {
        setTotalCap(_token, _totalCap);
        setCommunityCap(_token, _communityCap);
        setPerWalletCapForCommunityLp(_token, _perWalletCap);
    }

    function setCaps(
        address[] memory _tokens,
        uint256[] memory _totalCaps,
        uint256[] memory _communityCaps,
        uint256[] memory _perWalletCaps
    ) external onlyOwner {
        require(
            _tokens.length == _totalCaps.length &&
                _totalCaps.length == _communityCaps.length &&
                _communityCaps.length == _perWalletCaps.length,
            "ERR__LENGTH_MISMACH"
        );
        for (uint256 i = 0; i < _tokens.length; ++i) {
            setCap(_tokens[i], _totalCaps[i], _communityCaps[i], _perWalletCaps[i]);
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
     * @dev Returns the maximum amount a single community LP has provided
     */
    function getMaxCommunityLpPositon(address _token) external view returns (uint256) {
        ILPToken lpToken = ILPToken(liquidityPool.lpToken());
        uint256 totalSupply = lpToken.totalSupply();
        uint256 maxLp = 0;
        for (uint256 i = 0; i < totalSupply; ++i) {
            if (!isInstitutionalLp[lpToken.ownerOf(i)]) {
                uint256 liquidity = liquidityAddedByCommunityLp[_token][lpToken.ownerOf(i)];
                if (liquidity > maxLp) {
                    maxLp = liquidity;
                }
            }
        }
        return maxLp;
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
