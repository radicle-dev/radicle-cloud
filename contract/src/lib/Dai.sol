// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import {ERC20, IERC20} from "../EIP/ERC20.sol";

struct PermitArgs {
    uint256 nonce;
    uint256 expiry;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

interface IDai is IERC20 {
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract Dai is IDai, ERC20 {
    constructor(string memory _symbol, uint256 supply) ERC20(_symbol, supply) {
        return;
    }

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        holder;
        spender;
        nonce;
        expiry;
        allowed;
        v;
        r;
        s;
    }
}
