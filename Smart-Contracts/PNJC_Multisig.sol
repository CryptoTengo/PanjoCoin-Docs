// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/**
 * @title PNJC Master Treasury
 * @author PNJC Development Team
 * @notice A professional-grade multi-signature wallet for the PanjoCoin ecosystem.
 * 
 * @dev SECURITY COMPLIANCE (OZ Standards):
 * - Inherits ReentrancyGuard to prevent cross-function reentrancy attacks.
 * - Implements M-of-N consensus logic for decentralized governance.
 * - Adheres to the Check-Effects-Interactions (CEI) pattern for all execution logic.
 * - Compatible with EVM Cancun (2026) optimizations.
 */

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PNJCMasterTreasury is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Audit Trails (Events) ---
    /**
     * @dev Events are indexed to ensure full traceability on Etherscan/Polygonscan.
     */
    event TransactionSubmitted(uint256 indexed txIndex, address indexed owner, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed txIndex, address indexed owner);
    event TransactionExecuted(uint256 indexed txIndex, address indexed owner);
    event TransactionRevoked(uint256 indexed txIndex, address indexed owner);
    event RequiredSignaturesUpdated(uint256 newRequiredCount);

    // --- Governance State ---
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredSignatures;

    struct Transaction {
        address to;            // Target: Fee Router, PNJC Token, or external wallet
        uint256 value;         // Native amount (ETH/MATIC)
        bytes data;            // Encoded function call (e.g., for 'updateRates')
        bool executed;         // Execution status
        uint256 approvalCount; // Number of current approvals
    }

    // Mapping: txIndex => ownerAddress => hasConfirmed
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    // --- Access Control Modifiers ---
    /**
     * @dev Reverts if the caller is not an authorized owner of this Treasury.
     */
    modifier onlyOwner() {
        require(isOwner[msg.sender], "PNJC Treasury: Access denied");
        _;
    }

    /**
     * @dev Reverts if the transaction index does not exist in the ledger.
     */
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "PNJC Treasury: Tx does not exist");
        _;
    }

    /**
     * @dev Reverts if the transaction has already been successfully executed.
     */
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "PNJC Treasury: Tx already processed");
        _;
    }

    /**
     * @notice Constructor initializes the decentralized governing body.
     * @param _owners Array of initial owner addresses (e.g., 3 hardware wallet addresses).
     * @param _requiredSignatures Minimum consensus threshold (e.g., 2 for a 2-of-3 setup).
     */
    constructor(address[] memory _owners, uint256 _requiredSignatures) {
        require(_owners.length > 0, "PNJC Treasury: Owners list cannot be empty");
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _owners.length,
            "PNJC Treasury: Invalid signature threshold"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "PNJC Treasury: Zero address detected");
            require(!isOwner[owner], "PNJC Treasury: Duplicate owners not allowed");

            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredSignatures = _requiredSignatures;
    }

    /**
     * @notice Enables the Treasury to receive funds (ETH/MATIC) from the Fee Router.
     */
    receive() external payable {}

    /**
     * @notice Propose a new administrative action or fund transfer.
     * @param _to The destination address for the transaction.
     * @param _value The amount of native currency to be sent.
     * @param _data The calldata representing the function to be executed.
     */
    function submitTransaction(address _to, uint256 _value, bytes memory _data) 
        external 
        onlyOwner 
    {
        uint256 txIndex = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            approvalCount: 0
        }));

        emit TransactionSubmitted(txIndex, msg.sender, _to, _value, _data);
        
        // Auto-confirm for the submitter to save gas
        confirmTransaction(txIndex);
    }

    /**
     * @notice Adds an owner's approval to a pending transaction.
     * @dev Once 'requiredSignatures' is met, the transaction can be executed.
     * @param _txIndex The unique identifier of the transaction.
     */
    function confirmTransaction(uint256 _txIndex) 
        public 
        onlyOwner 
        txExists(_txIndex) 
        notExecuted(_txIndex) 
    {
        require(!isConfirmed[_txIndex][msg.sender], "PNJC Treasury: Already confirmed by caller");
        
        transactions[_txIndex].approvalCount += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit TransactionConfirmed(_txIndex, msg.sender);

        // Efficiency: Auto-execution if threshold is reached
        if (transactions[_txIndex].approvalCount >= requiredSignatures) {
            executeTransaction(_txIndex);
        }
    }

    /**
     * @notice Triggers the external call of a confirmed transaction.
     * @dev Uses low-level '.call' to ensure compatibility with Fee Router's gas requirements.
     * Implements Check-Effects-Interactions (CEI) security pattern.
     */
    function executeTransaction(uint256 _txIndex) 
        public 
        onlyOwner 
        txExists(_txIndex) 
        notExecuted(_txIndex) 
        nonReentrant 
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.approvalCount >= requiredSignatures, "PNJC Treasury: Consensus not reached");

        // 1. Effects: Update state before interaction to prevent reentrancy
        transaction.executed = true;

        // 2. Interaction: Execute the external call
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "PNJC Treasury: Call execution failed");

        emit TransactionExecuted(_txIndex, msg.sender);
    }

    /**
     * @notice Revokes a previously granted confirmation.
     * @param _txIndex The unique identifier of the transaction.
     */
    function revokeConfirmation(uint256 _txIndex) 
        external 
        onlyOwner 
        txExists(_txIndex) 
        notExecuted(_txIndex) 
    {
        require(isConfirmed[_txIndex][msg.sender], "PNJC Treasury: Tx not confirmed by caller");

        transactions[_txIndex].approvalCount -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit TransactionRevoked(_txIndex, msg.sender);
    }

    // --- View Functions ---
    /**
     * @notice Returns the list of all current Treasury owners.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}