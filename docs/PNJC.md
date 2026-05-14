# Solidity API

## PanjoCoin

PNJC is a fixed-supply utility token designed for the Polygon ecosystem.

_SECURITY & AUDIT FEATURES:
- Fixed Supply: 1,000,000,000,000 PNJC (No additional minting possible).
- Rug-Proof: No administrative roles, ownership, or backdoors.
- Standards: Fully compliant with ERC20, ERC20Burnable, and ERC20Permit.
- Transparency: Custom audit events for all sensitive state changes._

### Contract
PanjoCoin : Smart-Contract/PNJC.sol

SECURITY & AUDIT FEATURES:
- Fixed Supply: 1,000,000,000,000 PNJC (No additional minting possible).
- Rug-Proof: No administrative roles, ownership, or backdoors.
- Standards: Fully compliant with ERC20, ERC20Burnable, and ERC20Permit.
- Transparency: Custom audit events for all sensitive state changes.

 --- 
### Functions:
### constructor

```solidity
constructor(address _treasury) public
```

Contract constructor executed during deployment.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _treasury | address | The address designated to receive 100% of the initial supply. |

### _update

```solidity
function _update(address from, address to, uint256 value) internal virtual
```

_Internal update hook to maintain the custom audit trail for every transaction.
Overrides OpenZeppelin's standard _update function._

### burn

```solidity
function burn(uint256 value) public
```

Permanently destroys a specified amount of tokens from the caller's balance.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The amount of tokens to be burned. |

### burnFrom

```solidity
function burnFrom(address account, uint256 value) public
```

Destroys tokens from a specific account based on pre-approved allowance.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The address from which tokens will be removed. |
| value | uint256 | The amount of tokens to be burned. |

inherits ERC20Permit:
### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual
```

_Sets `value` as the allowance of `spender` over ``owner``'s tokens,
given ``owner``'s signed approval.

IMPORTANT: The same issues {IERC20-approve} has related to transaction
ordering also applies here.

Emits an {Approval} event.

Requirements:

- `spender` cannot be the zero address.
- `deadline` must be a timestamp in the future.
- `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
over the EIP712-formatted function arguments.
- the signature must use ``owner``'s current nonce (see {nonces}).

For more information on the signature format, see the
https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
section].

CAUTION: See Security Considerations above._

### nonces

```solidity
function nonces(address owner) public view virtual returns (uint256)
```

_Returns the current nonce for `owner`. This value must be
included whenever a signature is generated for {permit}.

Every successful call to {permit} increases ``owner``'s nonce by one. This
prevents a signature from being used multiple times._

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```

_Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}._

inherits Nonces:
### _useNonce

```solidity
function _useNonce(address owner) internal virtual returns (uint256)
```

_Consumes a nonce.

Returns the current value and increments nonce._

### _useCheckedNonce

```solidity
function _useCheckedNonce(address owner, uint256 nonce) internal virtual
```

_Same as {_useNonce} but checking that `nonce` is the next valid for `owner`._

inherits EIP712:
### _domainSeparatorV4

```solidity
function _domainSeparatorV4() internal view returns (bytes32)
```

_Returns the domain separator for the current chain._

### _hashTypedDataV4

```solidity
function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32)
```

_Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
function returns the hash of the fully encoded EIP712 message for this domain.

This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:

```solidity
bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
    keccak256("Mail(address to,string contents)"),
    mailTo,
    keccak256(bytes(mailContents))
)));
address signer = ECDSA.recover(digest, signature);
```_

### eip712Domain

```solidity
function eip712Domain() public view virtual returns (bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions)
```

_returns the fields and values that describe the domain separator used by this contract for EIP-712
signature._

### _EIP712Name

```solidity
function _EIP712Name() internal view returns (string)
```

_The name parameter for the EIP712 domain.

NOTE: By default this function reads _name which is an immutable value.
It only reads from storage if necessary (in case the value is too large to fit in a ShortString)._

### _EIP712Version

```solidity
function _EIP712Version() internal view returns (string)
```

_The version parameter for the EIP712 domain.

NOTE: By default this function reads _version which is an immutable value.
It only reads from storage if necessary (in case the value is too large to fit in a ShortString)._

inherits IERC5267:
inherits IERC20Permit:
inherits ERC20Burnable:
inherits ERC20:
### name

```solidity
function name() public view virtual returns (string)
```

_Returns the name of the token._

### symbol

```solidity
function symbol() public view virtual returns (string)
```

_Returns the symbol of the token, usually a shorter version of the
name._

### decimals

```solidity
function decimals() public view virtual returns (uint8)
```

_Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5.05` (`505 / 10 ** 2`).

Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the default value returned by this function, unless
it's overridden.

NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}._

### totalSupply

```solidity
function totalSupply() public view virtual returns (uint256)
```

_Returns the value of tokens in existence._

### balanceOf

```solidity
function balanceOf(address account) public view virtual returns (uint256)
```

_Returns the value of tokens owned by `account`._

### transfer

```solidity
function transfer(address to, uint256 value) public virtual returns (bool)
```

_See {IERC20-transfer}.

Requirements:

- `to` cannot be the zero address.
- the caller must have a balance of at least `value`._

### allowance

```solidity
function allowance(address owner, address spender) public view virtual returns (uint256)
```

_Returns the remaining number of tokens that `spender` will be
allowed to spend on behalf of `owner` through {transferFrom}. This is
zero by default.

This value changes when {approve} or {transferFrom} are called._

### approve

```solidity
function approve(address spender, uint256 value) public virtual returns (bool)
```

_See {IERC20-approve}.

NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
`transferFrom`. This is semantically equivalent to an infinite approval.

Requirements:

- `spender` cannot be the zero address._

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 value) public virtual returns (bool)
```

_See {IERC20-transferFrom}.

Skips emitting an {Approval} event indicating an allowance update. This is not
required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].

NOTE: Does not update the allowance if the current allowance
is the maximum `uint256`.

Requirements:

- `from` and `to` cannot be the zero address.
- `from` must have a balance of at least `value`.
- the caller must have allowance for ``from``'s tokens of at least
`value`._

### _transfer

```solidity
function _transfer(address from, address to, uint256 value) internal
```

_Moves a `value` amount of tokens from `from` to `to`.

This internal function is equivalent to {transfer}, and can be used to
e.g. implement automatic token fees, slashing mechanisms, etc.

Emits a {Transfer} event.

NOTE: This function is not virtual, {_update} should be overridden instead._

### _mint

```solidity
function _mint(address account, uint256 value) internal
```

_Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
Relies on the `_update` mechanism

Emits a {Transfer} event with `from` set to the zero address.

NOTE: This function is not virtual, {_update} should be overridden instead._

### _burn

```solidity
function _burn(address account, uint256 value) internal
```

_Destroys a `value` amount of tokens from `account`, lowering the total supply.
Relies on the `_update` mechanism.

Emits a {Transfer} event with `to` set to the zero address.

NOTE: This function is not virtual, {_update} should be overridden instead_

### _approve

```solidity
function _approve(address owner, address spender, uint256 value) internal
```

_Sets `value` as the allowance of `spender` over the `owner`'s tokens.

This internal function is equivalent to `approve`, and can be used to
e.g. set automatic allowances for certain subsystems, etc.

Emits an {Approval} event.

Requirements:

- `owner` cannot be the zero address.
- `spender` cannot be the zero address.

Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument._

### _approve

```solidity
function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual
```

_Variant of {_approve} with an optional flag to enable or disable the {Approval} event.

By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
`_spendAllowance` during the `transferFrom` operation sets the flag to false. This saves gas by not emitting any
`Approval` event during `transferFrom` operations.

Anyone who wishes to continue emitting `Approval` events on the `transferFrom` operation can force the flag to
true using the following override:

```solidity
function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
    super._approve(owner, spender, value, true);
}
```

Requirements are the same as {_approve}._

### _spendAllowance

```solidity
function _spendAllowance(address owner, address spender, uint256 value) internal virtual
```

_Updates `owner`'s allowance for `spender` based on spent `value`.

Does not update the allowance value in case of infinite allowance.
Revert if not enough allowance is available.

Does not emit an {Approval} event._

inherits IERC20Errors:
inherits IERC20Metadata:
inherits IERC20:

 --- 
### Events:
### TokenInitialized

```solidity
event TokenInitialized(address treasury, uint256 supply, uint256 timestamp)
```

_Transparency Events for On-chain Tracking_

### TransferAudit

```solidity
event TransferAudit(address from, address to, uint256 value)
```

### BurnAudit

```solidity
event BurnAudit(address account, uint256 amount)
```

inherits ERC20Permit:
inherits Nonces:
inherits EIP712:
inherits IERC5267:
### EIP712DomainChanged

```solidity
event EIP712DomainChanged()
```

_MAY be emitted to signal that the domain could have changed._

inherits IERC20Permit:
inherits ERC20Burnable:
inherits ERC20:
inherits IERC20Errors:
inherits IERC20Metadata:
inherits IERC20:
### Transfer

```solidity
event Transfer(address from, address to, uint256 value)
```

_Emitted when `value` tokens are moved from one account (`from`) to
another (`to`).

Note that `value` may be zero._

### Approval

```solidity
event Approval(address owner, address spender, uint256 value)
```

_Emitted when the allowance of a `spender` for an `owner` is set by
a call to {approve}. `value` is the new allowance._

