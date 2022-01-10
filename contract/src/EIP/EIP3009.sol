// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

struct AuthorizationArgs {
    address from;
    address to;
    uint256 value;
    uint256 validAfter;
    uint256 validBefore;
    bytes32 nonce;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
