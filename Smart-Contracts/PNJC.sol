// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title HybridAirdrop
 * @author PanjoCoin Engineering Team
 * @notice Contract for managing token airdrops with TGE unlock, linear vesting, and auto-burn.
 */
contract HybridAirdrop is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct Allocation {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 revocableAmount;
        bool burned;
    }

    // Constants
    uint256 private constant _BPS_DENOMINATOR = 10_000;
    uint256 public constant AIRDROP_DURATION = 6 weeks;

    // Immutables
    IERC20 public immutable TOKEN;
    uint256 public immutable VESTING_START;
    uint256 public immutable TGE_UNLOCK_BPS;
    uint256 public immutable AIRDROP_END;

    // State Variables
    mapping(address => Allocation) private _allocations;
    address[] private _participants;

    bool public autoBurned;
    uint256 public totalRevokedBurned;
    uint256 public totalAutoBurned;

    address public migrationContract;
    bool public migrationActive;
    bool public isFinalized;

    // Events
    event AllocationSet(address indexed user, uint256 totalAmount);
    event TokensClaimed(address indexed user, uint256 amount);
    event VestingRevokedAndBurned(address indexed user, uint256 revokedAmount);
    event AutoBurned(uint256 burnedAmount, uint256 timestamp);
    event NonAirdropTokenRescued(address indexed rescuedToken, uint256 amount);
    event MigrationActivated(address indexed newContract);
    event Migrated(address indexed user, uint256 amount);
    event Finalized();

    // Errors
    error ZeroAddressNotAllowed();
    error ZeroAmount();
    error ArrayLengthMismatch();
    error NothingToClaim();
    error NothingToRevoke();
    error CannotRescueAirdropToken();
    error TgeBpsExceedsDenominator();
    error InsufficientContractBalance();
    error MigrationNotActive();
    error MigrationAlreadyActive();
    error RevokeAmountExceedsUnvested();
    error ContractFinalized();

    constructor(
        IERC20 token_,
        uint256 vestingStart_,
        uint256 tgeUnlockBps_
    ) Ownable(msg.sender) {
        if (address(token_) == address(0)) revert ZeroAddressNotAllowed();
        if (tgeUnlockBps_ > _BPS_DENOMINATOR) revert TgeBpsExceedsDenominator();

        TOKEN = token_;
        VESTING_START = vestingStart_;
        TGE_UNLOCK_BPS = tgeUnlockBps_;
        AIRDROP_END = vestingStart_ + AIRDROP_DURATION;
    }

    modifier autoBurn() {
        if (block.timestamp >= AIRDROP_END && !autoBurned) {
            _executeAutoBurn();
        }
        _;
    }

    modifier notFinalized() {
        if (isFinalized) revert ContractFinalized();
        _;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function finalize() external onlyOwner {
        isFinalized = true;
        emit Finalized();
    }

    function setAllocations(
        address[] calldata users_,
        uint256[] calldata amounts_
    ) external onlyOwner {
        uint256 len = users_.length;
        if (len != amounts_.length) revert ArrayLengthMismatch();

        for (uint256 i; i < len; ) {
            address user = users_[i];
            uint256 amount = amounts_[i];

            if (user == address(0)) revert ZeroAddressNotAllowed();
            if (amount == 0) revert ZeroAmount();

            if (_allocations[user].totalAmount == 0) {
                _participants.push(user);
            }

            uint256 tgeAmount = (amount * TGE_UNLOCK_BPS) / _BPS_DENOMINATOR;
            uint256 vestingAmount = amount - tgeAmount;

            _allocations[user] = Allocation({
                totalAmount: amount,
                claimedAmount: 0,
                revocableAmount: vestingAmount,
                burned: false
            });

            emit AllocationSet(user, amount);
            unchecked { ++i; }
        }
    }

    function revokeVestingPartial(
        address user_,
        uint256 amount_
    ) external onlyOwner nonReentrant autoBurn notFinalized {
        if (amount_ == 0) revert ZeroAmount();
        Allocation storage alloc = _allocations[user_];
        
        uint256 currentUnvested = _getUnvestedAmount(alloc);
        if (amount_ > currentUnvested) revert RevokeAmountExceedsUnvested();

        alloc.totalAmount -= amount_;
        alloc.revocableAmount -= amount_;

        TOKEN.safeTransfer(address(0), amount_);
        totalRevokedBurned += amount_;
        emit VestingRevokedAndBurned(user_, amount_);
    }

    function revokeVesting(
        address user_
    ) external onlyOwner nonReentrant autoBurn notFinalized {
        Allocation storage alloc = _allocations[user_];
        uint256 unvested = _getUnvestedAmount(alloc);
        if (unvested == 0) revert NothingToRevoke();

        alloc.totalAmount -= unvested;
        alloc.revocableAmount -= unvested;

        TOKEN.safeTransfer(address(0), unvested);
        totalRevokedBurned += unvested;
        emit VestingRevokedAndBurned(user_, unvested);
    }

    function rescueNonAirdropTokens(IERC20 token_) external onlyOwner {
        if (token_ == TOKEN) revert CannotRescueAirdropToken();
        uint256 balance = token_.balanceOf(address(this));
        if (balance == 0) revert ZeroAmount();
        token_.safeTransfer(owner(), balance);
        emit NonAirdropTokenRescued(address(token_), balance);
    }

    function activateMigration(address newContract_) external onlyOwner notFinalized {
        if (migrationActive) revert MigrationAlreadyActive();
        if (newContract_ == address(0) || newContract_ == address(this)) revert ZeroAddressNotAllowed();
        migrationContract = newContract_;
        migrationActive = true;
        emit MigrationActivated(newContract_);
    }

    function claimable() public view returns (uint256 claimable_) {
        Allocation memory alloc = _allocations[msg.sender];
        if (alloc.totalAmount == 0 || alloc.burned) return 0;

        uint256 totalAvailable = _getTotalAvailable(alloc.totalAmount);
        if (totalAvailable > alloc.claimedAmount) {
            claimable_ = totalAvailable - alloc.claimedAmount;
        }
    }

    function claim() external nonReentrant whenNotPaused autoBurn notFinalized {
        uint256 amount = claimable();
        if (amount == 0) revert NothingToClaim();
        if (TOKEN.balanceOf(address(this)) < amount) revert InsufficientContractBalance();

        _allocations[msg.sender].claimedAmount += amount;
        TOKEN.safeTransfer(msg.sender, amount);
        emit TokensClaimed(msg.sender, amount);
    }

    function migrate() external nonReentrant whenNotPaused autoBurn notFinalized {
        if (!migrationActive) revert MigrationNotActive();
        uint256 amount = claimable();
        if (amount == 0) revert NothingToClaim();

        Allocation storage alloc = _allocations[msg.sender];
        alloc.claimedAmount = alloc.totalAmount;
        alloc.burned = true;

        TOKEN.safeTransfer(migrationContract, amount);
        emit Migrated(msg.sender, amount);
    }

    function getAllocation() external view returns (uint256 total, uint256 claimed, uint256 revocable, bool isBurned) {
        Allocation memory a = _allocations[msg.sender];
        return (a.totalAmount, a.claimedAmount, a.revocableAmount, a.burned);
    }

    function unvestedAmount() external view returns (uint256 unvested_) {
        Allocation memory alloc = _allocations[msg.sender];
        return _getUnvestedAmount(alloc);
    }

    function participantCount() external view returns (uint256) { return _participants.length; }
    function totalBurned() external view returns (uint256) { return totalRevokedBurned + totalAutoBurned; }

    function _executeAutoBurn() private {
        autoBurned = true;
        uint256 balance = TOKEN.balanceOf(address(this));
        if (balance > 0) {
            TOKEN.safeTransfer(address(0), balance);
            totalAutoBurned = balance;
            emit AutoBurned(balance, block.timestamp);
        }
    }

    function _getTotalAvailable(uint256 total_) private view returns (uint256 unlocked) {
        uint256 tge = (total_ * TGE_UNLOCK_BPS) / _BPS_DENOMINATOR;
        uint256 vesting = total_ - tge;

        if (block.timestamp < VESTING_START) return tge;
        if (block.timestamp >= AIRDROP_END) return total_;

        uint256 elapsed = block.timestamp - VESTING_START;
        uint256 unlockedVesting = (vesting * elapsed) / AIRDROP_DURATION;
        unlocked = tge + unlockedVesting;
    }

    function _getUnvestedAmount(Allocation memory alloc) private view returns (uint256 unvested_) {
        if (alloc.totalAmount == 0 || alloc.burned) return 0;
        uint256 totalAvailable = _getTotalAvailable(alloc.totalAmount);
        unvested_ = alloc.totalAmount - totalAvailable;
        
        if (unvested_ > alloc.revocableAmount) {
            unvested_ = alloc.revocableAmount;
        }
    }
}
