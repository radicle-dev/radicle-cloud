// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address spender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract ERC20 is IERC20 {
    string public symbol;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _symbol, uint256 supply) {
        symbol = _symbol;
        balanceOf[msg.sender] = supply;
    }

    function transfer(address addr, uint256 amount) public override returns (bool) {
        return transferFrom(msg.sender, addr, amount);
    }

    function transferFrom(
        address spender,
        address addr,
        uint256 amount
    ) public override returns (bool) {
        require(balanceOf[spender] >= amount, "Not enough balance");

        balanceOf[spender] -= amount;
        balanceOf[addr] += amount;

        return true;
    }

    function approve(address spender, uint256 amount) public pure override returns (bool) {
        spender;
        amount;

        return false;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        // assuming signature is correct
        allowance[owner][spender] = value;
        deadline;
        v;
        r;
        s;
    }

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        validAfter;
        validBefore;
        nonce;
        v;
        r;
        s;
        // assuming signature is correct
        transferFrom(from, to, value);
    }
}
