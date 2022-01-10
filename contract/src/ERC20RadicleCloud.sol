// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "./RadicleCloudBase.sol";
import {IERC20} from "./EIP/ERC20.sol";
import {AuthorizationArgs} from "./EIP/EIP3009.sol";

/// @title RadicleCloud contract for any ERC-20 token.
contract ERC20RadicleCloud is RadicleCloudBase {
    /// @notice The address of the ERC-20 contract we work with
    IERC20 public immutable erc20;

    /// @param price the rate we charge per block
    /// @param duration the length of the deployment in terms of blocks
    /// @param owner the owner of contract
    /// @param _erc20 the address of an ERC-20 contract we work with, supply must be lower than `2 ^ 127`
    constructor(
        uint64 price,
        uint32 duration,
        address owner,
        IERC20 _erc20
    ) RadicleCloudBase(price, duration, owner) {
        erc20 = _erc20;
    }

    /// @notice Buy or renew deployment with your ERC-20, must have approved before-hand.
    /// @param org the org buying deployment for
    /// @param owner the owner of the org
    /// @param amount the amount you're sending, must be exact multiples of `getPrice()`
    function buyOrRenew(
        address org,
        address owner,
        uint128 amount
    ) public {
        _withdrawFrom(msg.sender, address(this), amount);
        topUp(org, owner, amount);
    }

    function _withdraw(address destination, uint128 amount) internal override {
        erc20.transfer(destination, amount);
    }

    function _withdrawFrom(
        address from,
        address destination,
        uint128 amount
    ) internal {
        erc20.transferFrom(from, destination, amount);
    }
}
