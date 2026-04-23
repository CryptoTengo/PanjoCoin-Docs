// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*//////////////////////////////////////////////////////////////
                AUDIT & INVESTOR NOTES
//////////////////////////////////////////////////////////////

✔ ERC20 standard token
✔ Fixed supply (no mint after deployment)
✔ Burnable (deflationary)
✔ Allowance control (increase/decrease)
✔ EIP-2612 Permit (gasless approvals)
✔ No owner / no admin (fully trustless)

Security Model:
- Fully deterministic ERC20 logic
- No upgradeability
- No hidden fees or blacklists

//////////////////////////////////////////////////////////////*/

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/*//////////////////////////////////////////////////////////////
                        ERC20 CORE
//////////////////////////////////////////////////////////////*/

contract ERC20 is Context {

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 internal _totalSupply;
    string internal _name;
    string internal _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return 18; }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(_msgSender(), to, value);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(_msgSender(), spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 current = _allowances[from][_msgSender()];
        require(current >= value, "ALLOWANCE_LOW");

        unchecked {
            _approve(from, _msgSender(), current - value);
        }

        _transfer(from, to, value);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        ALLOWANCE CONTROL
    //////////////////////////////////////////////////////////////*/

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address owner = _msgSender();
        uint256 current = _allowances[owner][spender];
        require(current >= subtractedValue, "ALLOWANCE_UNDERFLOW");

        unchecked {
            _approve(owner, spender, current - subtractedValue);
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "FROM_ZERO");
        require(to != address(0), "TO_ZERO");

        uint256 bal = _balances[from];
        require(bal >= value, "BALANCE_LOW");

        unchecked {
            _balances[from] = bal - value;
        }

        _balances[to] += value;

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), "MINT_ZERO");

        _totalSupply += value;
        _balances[account] += value;

        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "BURN_ZERO");

        uint256 bal = _balances[account];
        require(bal >= value, "BURN_EXCEEDS");

        unchecked {
            _balances[account] = bal - value;
            _totalSupply -= value;
        }

        emit Transfer(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "OWNER_ZERO");
        require(spender != address(0), "SPENDER_ZERO");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/*//////////////////////////////////////////////////////////////
                        EIP-2612 PERMIT
//////////////////////////////////////////////////////////////*/

contract ERC20Permit is ERC20 {

    mapping(address => uint256) public nonces;

    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        _CACHED_CHAIN_ID = block.chainid;

        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                    keccak256(bytes(_name)),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(this)
                )
            );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "EXPIRED");

        uint256 nonce = nonces[owner]++;

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash)
        );

        address recovered = ecrecover(digest, v, r, s);
        require(recovered == owner && recovered != address(0), "INVALID_SIGNATURE");

        _approve(owner, spender, value);
    }
}

/*//////////////////////////////////////////////////////////////
                        FINAL TOKEN
//////////////////////////////////////////////////////////////*/

contract PanjoCoin is ERC20Permit {

    uint256 public constant MAX_SUPPLY = 1_000_000_000_000 * 10**18;

    event Burn(address indexed from, uint256 amount);

    constructor(address distributionWallet)
        ERC20Permit("PanjoCoin", "PNJC")
    {
        require(distributionWallet != address(0), "ZERO_WALLET");
        _mint(distributionWallet, MAX_SUPPLY);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
        emit Burn(_msgSender(), amount);
    }
}
