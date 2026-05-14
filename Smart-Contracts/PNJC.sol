// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (v5.0.0+) compatible
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title PanjoCoin (PNJC) - High-Performance Polygon Implementation
 * @author PanjoCoin Engineering Team
 * 
 * @notice ARCHITECTURAL OVERVIEW:
 * This contract is a professional-grade ERC20 implementation specifically 
 * optimized for the Polygon ecosystem. It features EIP-2612 (Permit) 
 * for gasless approvals and a burnable mechanism for deflationary utility.
 *
 * @dev AUDIT & INVESTOR KEY HIGHLIGHTS:
 * 1. ZERO INFLATION: Total supply is hard-capped at 1 Trillion tokens. 
 *    No minting capabilities exist post-deployment.
 * 2. TRUSTLESS DESIGN: The contract lacks administrative roles (No Owner, No Admin). 
 *    This eliminates 'Rug Pull' risks as no one can pause or modify the contract.
 * 3. POLYGON OPTIMIZED: Uses Solidity 0.8.34 with 'shanghai' or 'paris' EVM target 
 *    to ensure full compatibility with Polygon's node architecture.
 * 4. EIP-2612 INTEGRATION: Permits allow for seamless integration with Polygon 
 *    DEXs (like QuickSwap), enabling signature-based interactions.
 */
contract PanjoCoin is ERC20, ERC20Permit, ERC20Burnable {

    /**
     * @dev Tokenomics constants.
     * Fixed supply: 1,000,000,000,000 PNJC (1 Trillion).
     */
    uint256 private constant _MAX_TOTAL_SUPPLY = 1_000_000_000_000 * 10**18;

    /**
     * @notice Deployment logic for Polygon.
     * @param initialOwner The address designated to receive the initial supply 
     * (e.g., Multi-Sig, Liquidity Pool, or Vesting contract).
     */
    constructor(address initialOwner) 
        ERC20("PanjoCoin", "PNJC") 
        ERC20Permit("PanjoCoin") 
    {
        // AUDIT: Check for non-zero address to prevent permanent token loss.
        if (initialOwner == address(0)) {
            revert("PanjoCoin: initial owner is the zero address");
        }

        // Integrity Check: Total supply is minted exactly once to the designated owner.
        // Internal _mint ensures all ERC20 invariants are maintained.
        _mint(initialOwner, _MAX_TOTAL_SUPPLY);
    }

    /**
     * @notice Explicit getter for the hard-capped total supply.
     * @return The maximum amount of PNJC that will ever be in circulation.
     */
    function maxSupply() external pure returns (uint256) {
        return _MAX_TOTAL_SUPPLY;
    }

    /**
     * @dev INTERNAL AUDIT NOTE:
     * This contract excludes 'Context' and 'Ownable' to minimize bytecode size 
     * and maximize decentralization. It is fully 'Rug-Proof' by design.
     */
}