// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @dev Using fixed version 5.0.2 to ensure compatibility with 'Paris' EVM 
 * and avoid 'mcopy' instruction errors found in later versions.
 */
import "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title PanjoCoin (PNJC)
 * @author PanjoCoin Team
 * @notice Standard ERC20 token with EIP-2612 Permit functionality for gasless approvals.
 * @dev This contract implements a fixed supply model. No minting or burning functions are exposed.
 */
contract PanjoCoin is ERC20, ERC20Permit {

    /**
     * @notice The maximum and total supply of the token.
     * @dev Set to 1,000,000,000,000 (1 Trillion) with 18 decimal places.
     * Fixed as a constant to guarantee supply integrity for investors.
     */
    uint256 public constant MAX_SUPPLY = 1_000_000_000_000 * 10**18;

    /**
     * @notice Contract constructor.
     * @dev Initializes the token and mints the total supply to the deployer's address.
     * Inherits from OpenZeppelin's audited ERC20 and ERC20Permit implementations.
     */
    constructor() 
        ERC20("PanjoCoin", "PNJC") 
        ERC20Permit("PanjoCoin") 
    {
        // Audit point: Initial supply is minted once. 
        // Lack of minting functions ensures no inflation is possible.
        _mint(msg.sender, MAX_SUPPLY);
    }

    /**
     * @dev Key Features for Investors:
     * 1. **Security**: Built on OpenZeppelin 5.0.2, the gold standard for smart contracts.
     * 2. **Fixed Supply**: 1 Trillion PNJC tokens. The supply cannot be increased after deployment.
     * 3. **EIP-2612**: Supports 'Permit' transactions, allowing users to approve transfers via 
     * off-chain signatures, significantly improving the user experience on Polygon.
     * 4. **No Hidden Logic**: No owner-only functions, blacklists, or fees are present in this code.
     */
}
