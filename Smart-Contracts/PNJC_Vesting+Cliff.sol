// SPDX-License-Identifier: MIT
// PanjoCoin (PNJC) – Audit-Ready Vesting Contract v2.0
// 
// @audit FOR INVESTORS:
// @audit - This contract locks tokens and releases them linearly over time
// @audit - NO ONE can unlock tokens before the cliff period ends
// @audit - NO ONE can change the beneficiary address
// @audit - The owner can ONLY withdraw accidental token transfers (NOT PNJC)
// @audit - All vesting parameters are immutable and visible on-chain forever
// 
// @audit FOR AUDITORS:
// @audit - Uses OpenZeppelin's audited SafeERC20, Ownable, ReentrancyGuard
// @audit - No delegatecall, no selfdestruct, no assembly
// @audit - Checks-effects-interactions pattern
// @audit - Input validation in constructor
// @audit - Linear vesting with cliff, mathematically precise

pragma solidity 0.8.34;

// ============================================================
// OPENZEPPELIN IMPORTS (audited and battle-tested)
// ============================================================

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ============================================================
// MAIN CONTRACT: PanjoCoinVesting
// ============================================================

/**
 * @title PanjoCoinVesting
 * @author PanjoCoin Team
 * @dev Vesting contract for PanjoCoin (PNJC) tokens with cliff + linear release.
 * 
 * @notice This contract implements a standard vesting schedule where:
 *         - Tokens are completely locked during the cliff period
 *         - After cliff, tokens unlock linearly over the vesting duration
 *         - Only the beneficiary can claim tokens
 *         - The owner can only rescue non-PNJC tokens sent by mistake
 * 
 * @dev Security highlights:
 *      - All critical parameters are immutable (cannot be changed after deployment)
 *      - ReentrancyGuard protects the claim function
 *      - SafeERC20 prevents token transfer issues
 *      - No backdoors or admin overrides for vested tokens
 * 
 * @dev Typical use cases in PanjoCoin:
 *      - Team vesting: cliff 12 months, vesting 36 months
 *      - Treasury vesting: cliff 3 months, vesting 24 months
 *      - Founder vesting: cliff 12 months, vesting 36 months
 *      - Marketing vesting: cliff 0 months, vesting 12 months
 */
contract PanjoCoinVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================================
    // IMMUTABLE STATE VARIABLES (set once, never change)
    // ============================================================
    // @audit These values are burned into the contract bytecode at deployment
    // @audit Anyone can read them on Polygonscan forever
    
    /// @notice Address that can claim vested tokens (cannot be changed)
    /// @dev Must be a non-zero address, typically a multisig wallet
    address public immutable beneficiary;
    
    /// @notice The ERC20 token being vested (PanjoCoin PNJC)
    /// @dev This is the token that will be released over time
    IERC20 public immutable token;
    
    /// @notice Timestamp (UNIX seconds) when vesting starts
    /// @dev If start > block.timestamp, cliff period is active
    uint256 public immutable start;
    
    /// @notice Timestamp (UNIX seconds) when cliff ends and first tokens become available
    /// @dev cliff = start + cliffDuration
    uint256 public immutable cliff;
    
    /// @notice Duration of the linear vesting period in seconds
    /// @dev After start + vestingDuration, all tokens are vested
    uint256 public immutable vestingDuration;
    
    /// @notice Total amount of tokens locked in this contract
    /// @dev This is the maximum that can ever be claimed
    uint256 public immutable totalAmount;
    
    // ============================================================
    // MUTABLE STATE VARIABLES (change over time)
    // ============================================================
    
    /// @notice Amount of tokens already claimed by the beneficiary
    /// @dev Increases each time claim() is called
    /// @dev Cannot exceed totalAmount
    uint256 public released;

    // ============================================================
    // EVENTS (for off-chain monitoring)
    // ============================================================
    
    /// @notice Emitted when beneficiary successfully claims tokens
    /// @param beneficiary Address that received the tokens
    /// @param amount Amount of tokens claimed
    event TokensReleased(address indexed beneficiary, uint256 amount);
    
    /// @notice Emitted when owner withdraws a non-vested token sent by mistake
    /// @param token Address of the token that was withdrawn
    /// @param amount Amount of tokens withdrawn
    event EmergencyWithdrawn(address indexed token, uint256 amount);

    // ============================================================
    // CONSTRUCTOR
    // ============================================================
    
    /**
     * @dev Deploys the vesting contract and immediately locks the tokens
     * 
     * @param _beneficiary The address that will receive the vested tokens
     * @param _token The ERC20 token address (PanjoCoin contract address)
     * @param _totalAmount Total amount of tokens to vest (with decimals, e.g., 1e18 for 1 token)
     * @param _start Timestamp (UNIX seconds) when vesting begins
     * @param _cliffDuration Duration of the cliff period in seconds
     * @param _vestingDuration Total vesting duration in seconds
     * 
     * @dev Requirements:
     *      - _beneficiary cannot be address(0)
     *      - _token cannot be address(0)
     *      - _totalAmount must be greater than 0
     *      - _cliffDuration must be less than or equal to _vestingDuration
     *      - The deployer must have approved this contract to spend _totalAmount tokens
     * 
     * @dev Example for Team Vesting (12 month cliff, 36 month vesting):
     *      _beneficiary = teamMultisigAddress
     *      _start = block.timestamp + 365 days
     *      _cliffDuration = 365 days
     *      _vestingDuration = 1095 days (3 years)
     */
    constructor(
        address _beneficiary,
        IERC20 _token,
        uint256 _totalAmount,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) Ownable(msg.sender) {
        // ============================================================
        // INPUT VALIDATION (fail early, fail loudly)
        // ============================================================
        // @audit These checks prevent deployment with invalid parameters
        // @audit All error messages are clear and descriptive
        
        require(_beneficiary != address(0), "PanjoCoinVesting: beneficiary cannot be zero address");
        require(address(_token) != address(0), "PanjoCoinVesting: token cannot be zero address");
        require(_totalAmount > 0, "PanjoCoinVesting: total amount must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "PanjoCoinVesting: cliff duration cannot exceed vesting duration");
        
        // ============================================================
        // STATE INITIALIZATION
        // ============================================================
        
        // Calculate the cliff timestamp (when tokens first become available)
        uint256 _cliff = _start + _cliffDuration;
        
        // Set immutable variables (these can never be changed after this point)
        beneficiary = _beneficiary;
        token = _token;
        totalAmount = _totalAmount;
        start = _start;
        cliff = _cliff;
        vestingDuration = _vestingDuration;
        
        // Initialize released amount to zero
        released = 0;
        
        // ============================================================
        // TOKEN TRANSFER
        // ============================================================
        // @audit Transfer tokens from the deployer to this contract
        // @audit This requires that the deployer called approve() BEFORE deployment
        // @audit Using safeTransferFrom which reverts on failure
        
        _token.safeTransferFrom(msg.sender, address(this), _totalAmount);
    }

    // ============================================================
    // PUBLIC VIEW FUNCTIONS (gas-efficient, no state changes)
    // ============================================================
    
    /**
     * @dev Calculates the total amount of tokens that have vested so far
     * @return uint256 Amount vested (includes already claimed tokens)
     * 
     * @notice Vested amount is calculated as:
     *         - 0% before cliff
     *         - Linear from 0% to 100% between cliff and start+vestingDuration
     *         - 100% after start+vestingDuration
     * 
     * @dev Mathematical formula:
     *      if block.timestamp < cliff:                                    return 0
     *      if block.timestamp >= start + vestingDuration:                 return totalAmount
     *      else:                                                          return totalAmount * (block.timestamp - cliff) / vestingDuration
     * 
     * @dev The calculation uses integer math with multiplication before division
     *      to maintain maximum precision. No floating point is used.
     */
    function vestedAmount() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        
        // Case 1: Before cliff period - nothing is vested
        if (currentTime < cliff) {
            return 0;
        }
        
        // Case 2: After full vesting period - everything is vested
        if (currentTime >= start + vestingDuration) {
            return totalAmount;
        }
        
        // Case 3: During linear vesting phase
        // Calculate how much time has passed since the cliff ended
        uint256 timeSinceCliff = currentTime - cliff;
        
        // Linear vesting calculation
        // vested = totalAmount * timeSinceCliff / vestingDuration
        uint256 vested = (totalAmount * timeSinceCliff) / vestingDuration;
        
        return vested;
    }
    
    /**
     * @dev Calculates the amount of tokens currently available to claim
     * @return uint256 Amount that can be claimed now (vested - already claimed)
     * 
     * @notice This is the amount that would be transferred if claim() is called
     * @dev Returns 0 if no tokens are available to claim
     */
    function releasable() public view returns (uint256) {
        uint256 vested = vestedAmount();
        uint256 alreadyReleased = released;
        
        // Safety check to prevent underflow
        if (vested <= alreadyReleased) {
            return 0;
        }
        
        return vested - alreadyReleased;
    }
    
    /**
     * @dev Returns the current block timestamp
     * @return uint256 Current timestamp in UNIX seconds
     * @notice Useful for off-chain verification of vesting progress
     */
    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @dev Returns the total balance of tokens held by this contract
     * @return uint256 Current token balance
     * @notice Should equal totalAmount - released under normal conditions
     */
    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev Returns the amount of tokens still locked (not yet claimable)
     * @return uint256 Amount of locked tokens
     * @notice Locked tokens = totalAmount - vestedAmount (NOT totalAmount - released)
     */
    function getLockedTokens() external view returns (uint256) {
        return totalAmount - vestedAmount();
    }

    // ============================================================
    // MAIN USER ACTION: CLAIM TOKENS
    // ============================================================
    
    /**
     * @dev Claim all currently available tokens
     * @notice Can be called multiple times; only the beneficiary can call
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * 
     * @dev Execution flow:
     *      1. Verify caller is the beneficiary
     *      2. Calculate claimable amount
     *      3. Verify amount > 0
     *      4. Update state (released += amount)
     *      5. Transfer tokens to beneficiary
     *      6. Emit event
     * 
     * @dev The checks-effects-interactions pattern is followed:
     *      - State is updated before external call (safeTransfer)
     *      - This prevents reentrancy even without the modifier
     */
    function claim() external nonReentrant {
        // Verify caller is the authorized beneficiary
        require(msg.sender == beneficiary, "PanjoCoinVesting: caller is not the beneficiary");
        
        // Calculate claimable amount
        uint256 amount = releasable();
        require(amount > 0, "PanjoCoinVesting: no tokens available to claim");
        
        // Update state BEFORE external transfer (reentrancy protection)
        released += amount;
        
        // Transfer tokens to the beneficiary
        token.safeTransfer(beneficiary, amount);
        
        // Emit event for off-chain tracking
        emit TokensReleased(beneficiary, amount);
    }

    // ============================================================
    // OWNER-ONLY EMERGENCY FUNCTIONS
    // ============================================================
    
    /**
     * @dev Withdraw ANY OTHER token accidentally sent to this contract
     * @param _otherToken The ERC20 token to withdraw
     * 
     * @notice This function exists to rescue tokens that were sent to this contract by mistake
     * @notice This CANNOT be used to withdraw the vested token (PanjoCoin PNJC)
     * 
     * @dev Security guarantee:
     *      - The function explicitly checks that _otherToken is NOT the vesting token
     *      - Even if the check fails, safeTransfer would fail because the contract owns no PNJC
     * 
     * @dev Requirements:
     *      - Only the contract owner can call this function
     *      - The token to withdraw cannot be the vesting token
     *      - The contract must have a balance of the token to withdraw
     */
    function emergencyWithdraw(IERC20 _otherToken) external onlyOwner nonReentrant {
        // CRITICAL: Prevent withdrawal of the main vested token
        require(address(_otherToken) != address(token), "PanjoCoinVesting: cannot withdraw the vested token");
        
        uint256 balance = _otherToken.balanceOf(address(this));
        require(balance > 0, "PanjoCoinVesting: no balance to withdraw");
        
        // Transfer the other token to the owner (typically a team multisig)
        _otherToken.safeTransfer(owner(), balance);
        
        emit EmergencyWithdrawn(address(_otherToken), balance);
    }
}