// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ERC20VotingPower
 * @dev ERC20 token with voting power delegation, snapshot capabilities, and admin-controlled minting.
 * Each token = 1 vote weight. Supports delegation and checkpointing.
 * Only accounts with MINTER_ROLE can mint new tokens.
 */
contract ERC20VotingPower is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private immutable _tokenMaxSupply;

    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial supply minted to deployer
     * @param maxSupply_ Maximum supply that can ever exist (0 = unlimited)
     * @param initialHolder Address that receives initialSupply (use creator)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply_,
        address initialHolder
    )
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        require(maxSupply_ == 0 || initialSupply <= maxSupply_, "Initial supply exceeds max supply");
        require(initialHolder != address(0), "Initial holder zero address");
        _tokenMaxSupply = maxSupply_;
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        if (initialSupply > 0) {
            _mint(initialHolder, initialSupply);
            emit TokensMinted(initialHolder, initialSupply);
        }
    }

    /**
     * @dev Mint new tokens (only callable by MINTER_ROLE)
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Cannot mint to zero address");
        if (_tokenMaxSupply > 0) {
            require(totalSupply() + amount <= _tokenMaxSupply, "Exceeds max supply");
        }
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Batch mint tokens to multiple addresses (only callable by MINTER_ROLE)
     * @param recipients Array of addresses to receive tokens
     * @param amounts Array of amounts to mint to each address
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 a = amounts[i];
            if (a > 0 && r != address(0)) {
                if (_tokenMaxSupply > 0) {
                    require(totalSupply() + a <= _tokenMaxSupply, "Exceeds max supply");
                }
                _mint(r, a);
                emit TokensMinted(r, a);
            }
        }
    }

    // OpenZeppelin v5 unified hook
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    // Conflict between ERC20Permit and ERC20Votes
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // Admin helper to add a minter (factory or creator/timelock can call while holding DEFAULT_ADMIN_ROLE)
    function setMinter(address newMinter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMinter != address(0), "Invalid minter");
        _grantRole(MINTER_ROLE, newMinter);
    }
}
