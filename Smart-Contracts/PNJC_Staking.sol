// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title PNJC Advanced Staking & Governance Engine
 * @author Tengo Kalandia / PanjoCoin Project
 * @notice This contract manages the staking of PNJC tokens to support the ecosystem,
 * provide liquidity stability, and fund medical clowning initiatives via Smiledonate.
 * 
 * AUDIT & INVESTOR INFORMATION:
 * - Security: Implements ReentrancyGuard to prevent re-entry attacks during token transfers.
 * - Integrity: Uses SafeERC20 to ensure compatibility with all ERC20 implementations.
 * - Social Impact: A fixed percentage (Charity Tax) of all staking rewards is 
 *   automatically diverted to the Smiledonate NNLE vault.
 * - Governance: Implements a "Time-Weight" multiplier for DAO voting power, 
 *   rewarding long-term holders over short-term speculators.
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PNJC_Staking_Advanced is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Core Project Constants ---
    IERC20 public immutable pnjcToken;
    address public charityVault; // Destination for Smiledonate funds
    
    uint256 public rewardRate; 
    uint256 public charityTaxRate = 500; // 5% of rewards (Basis points: 500/10000)
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    // --- State Mappings ---
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public stakeTimestamp;

    uint256 private _totalSupply;

    // --- Events for Transparency ---
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 userAmount, uint256 charityAmount);
    event CharityVaultUpdated(address indexed newVault);

    /**
     * @dev Initialize contract with PNJC token address and Charity Vault address.
     */
    constructor(address _pnjcToken, address _charityVault) Ownable(msg.sender) {
        pnjcToken = IERC20(_pnjcToken);
        charityVault = _charityVault;
    }

    // --- Core Logic ---

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return ((_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    /**
     * @notice Stakes PNJC tokens. Improves ecosystem stability by locking supply.
     * @param amount Quantity of PNJC to stake.
     */
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        pnjcToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraws staked tokens from the pool.
     * @param amount Quantity of PNJC to withdraw.
     */
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "Insufficient staked balance");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        pnjcToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claims rewards with automated Charity Sync logic.
     * Sends the user's share to their wallet and the charity share to Smiledonate.
     */
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 totalReward = rewards[msg.sender];
        if (totalReward > 0) {
            rewards[msg.sender] = 0;
            
            uint256 charityShare = (totalReward * charityTaxRate) / 10000;
            uint256 userShare = totalReward - charityShare;

            pnjcToken.safeTransfer(msg.sender, userShare);
            pnjcToken.safeTransfer(charityVault, charityShare);

            emit RewardPaid(msg.sender, userShare, charityShare);
        }
    }

    /**
     * @notice Provides DAO Voting Power calculation.
     * Formula: Amount Staked * (1 + Months Staked bonus).
     * @param account The address of the stakeholder.
     */
    function getVotingPower(address account) external view returns (uint256) {
        uint256 timeStaked = block.timestamp - stakeTimestamp[account];
        uint256 multiplier = 1 + (timeStaked / 30 days); 
        return _balances[account] * multiplier;
    }

    // --- Administrative Functions (Owner Only) ---

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
    }

    function updateCharityVault(address _newVault) external onlyOwner {
        require(_newVault != address(0), "Invalid vault address");
        charityVault = _newVault;
        emit CharityVaultUpdated(_newVault);
    }

    function setCharityTax(uint256 _newRate) external onlyOwner {
        require(_newRate <= 2000, "Tax cannot exceed 20%");
        charityTaxRate = _newRate;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}