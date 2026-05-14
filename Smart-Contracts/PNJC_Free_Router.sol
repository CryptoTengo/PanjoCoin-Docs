// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/**
 * @title PNJC Multi-Asset Fee Router
 * @author CertiK-Style Professional Revision
 * @notice Automated revenue distribution layer for Native assets and ERC20 tokens.
 * @dev High-security implementation using OpenZeppelin standards and SafeERC20.
 */

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PNJCFeeRouter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Role Definitions ---
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // --- State Variables: Beneficiary Wallets ---
    address public clownCareWallet;
    address public liquidityWallet;
    address public devWallet;
    address public daoTreasury;

    // --- State Variables: Fee Configuration (Basis Points: 100 = 1%) ---
    uint256 public clownCareFee = 200;   // 2.0%
    uint256 public liquidityFee = 100;    // 1.0%
    uint256 public devFee = 100;          // 1.0%
    uint256 public daoFee = 50;           // 0.5%
    
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant MAX_TOTAL_FEE_CAP = 1500; // 15% Max cap for investor protection

    // --- Events ---
    event FeesDistributed(address indexed token, uint256 totalAmount);
    event BeneficiariesUpdated(address clownCare, address liquidity, address dev, address dao);
    event RatesUpdated(uint256 clownCare, uint256 liquidity, uint256 dev, uint256 dao);

    /**
     * @dev Initializes roles and beneficiary addresses.
     */
    constructor(
        address _clownCareWallet,
        address _liquidityWallet,
        address _devWallet,
        address _daoTreasury,
        address admin
    ) {
        if (admin == address(0)) revert("Router: Admin cannot be zero address");
        
        clownCareWallet = _clownCareWallet;
        liquidityWallet = _liquidityWallet;
        devWallet = _devWallet;
        daoTreasury = _daoTreasury;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Fallback function to accept Native asset (ETH/BNB/MATIC).
     */
    receive() external payable {}

    /**
     * @notice Distributes accumulated Native assets among beneficiaries.
     */
    function distributeNative() external nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert("Router: No Native balance available");
        
        _processDistribution(address(0), balance);
    }

    /**
     * @notice Distributes accumulated ERC20 tokens among beneficiaries.
     * @param token The address of the ERC20 token to be distributed.
     */
    function distributeToken(address token) external nonReentrant {
        if (token == address(0)) revert("Router: Invalid token address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) revert("Router: No token balance available");
        
        _processDistribution(token, balance);
    }

    /**
     * @dev Internal routing logic using Check-Effects-Interactions pattern.
     */
    function _processDistribution(address token, uint256 amount) internal {
        uint256 clownAmount = (amount * clownCareFee) / BASIS_POINTS_DENOMINATOR;
        uint256 liqAmount = (amount * liquidityFee) / BASIS_POINTS_DENOMINATOR;
        uint256 devAmount = (amount * devFee) / BASIS_POINTS_DENOMINATOR;
        uint256 daoAmount = (amount * daoFee) / BASIS_POINTS_DENOMINATOR;

        if (token == address(0)) {
            _dispatchNative(clownCareWallet, clownAmount);
            _dispatchNative(liquidityWallet, liqAmount);
            _dispatchNative(devWallet, devAmount);
            _dispatchNative(daoTreasury, daoAmount);
        } else {
            IERC20(token).safeTransfer(clownCareWallet, clownAmount);
            IERC20(token).safeTransfer(liquidityWallet, liqAmount);
            IERC20(token).safeTransfer(devWallet, devAmount);
            IERC20(token).safeTransfer(daoTreasury, daoAmount);
        }

        emit FeesDistributed(token, amount);
    }

    /**
     * @dev Secure Native transfer using low-level call to prevent gas limit issues.
     */
    function _dispatchNative(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert("Router: Native transfer failed");
    }

    // --- Administrative Functions (Restricted) ---

    /**
     * @notice Updates the recipient addresses for the distribution.
     */
    function updateBeneficiaries(
        address _clownCare, 
        address _liquidity, 
        address _dev, 
        address _dao
    ) external onlyRole(ADMIN_ROLE) {
        if (_clownCare == address(0) || _liquidity == address(0)) revert("Router: Invalid address");
        clownCareWallet = _clownCare;
        liquidityWallet = _liquidity;
        devWallet = _dev;
        daoTreasury = _dao;
        emit BeneficiariesUpdated(_clownCare, _liquidity, _dev, _dao);
    }

    /**
     * @notice Updates the fee percentages.
     * @dev Total sum must not exceed 15% (1500 BPS).
     */
    function updateRates(
        uint256 _clownCare, 
        uint256 _liquidity, 
        uint256 _dev, 
        uint256 _dao
    ) external onlyRole(ADMIN_ROLE) {
        if (_clownCare + _liquidity + _dev + _dao > MAX_TOTAL_FEE_CAP) revert("Router: Exceeds cap");
        
        clownCareFee = _clownCare;
        liquidityFee = _liquidity;
        devFee = _dev;
        daoFee = _dao;
        
        emit RatesUpdated(_clownCare, _liquidity, _dev, _dao);
    }

    /**
     * @notice Emergency withdrawal of funds by the super admin.
     */
    function emergencyWithdraw(address token, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert("Router: Target address zero");
        if (token == address(0)) {
            _dispatchNative(to, address(this).balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(to, balance);
        }
    }
}