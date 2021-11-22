// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "./RadicleCloudBase.sol";
import {IDai, PermitArgs} from "./lib/Dai.sol";

/// @title RadicleCloud contract for Dai.
contract DaiRadicleCloud is RadicleCloudBase {
    /// @notice The address of the Dai contract we work with
    IDai public immutable dai;

    /// @param price the rate we charge per block
    /// @param duration the length of the deployment in terms of blocks
    /// @param owner the owner of contract
    /// @param _dai the address of Dai contract we work with, supply must be lower than `2 ^ 127`
    constructor(
        uint64 price,
        uint32 duration,
        address owner,
        IDai _dai
    ) RadicleCloudBase(price, duration, owner) {
        dai = _dai;
    }

    /// @notice Buy or renew deployment with your Dai withdraw permission.
    /// @param org the org buying deployment for
    /// @param owner the owner of the org
    /// @param amount the amount you're sending, must be exact multiples of `getPrice()`
    /// @param permitArgs the dai permission arguments
    function buyOrRenewWithPermit(
        address org,
        address owner,
        uint128 amount,
        PermitArgs calldata permitArgs
    ) public {
        _permit(permitArgs);
        _withdrawFrom(msg.sender, address(this), amount);
        topUp(org, owner, amount);
    }

    /// @dev Permit contract to spend the caller's Dai.
    /// @param permitArgs the dai permission arguments
    function _permit(PermitArgs calldata permitArgs) internal {
        dai.permit(
            msg.sender,
            address(this),
            permitArgs.nonce,
            permitArgs.expiry,
            true,
            permitArgs.v,
            permitArgs.r,
            permitArgs.s
        );
    }

    function _withdraw(address destination, uint128 amount) internal override {
        dai.transfer(destination, amount);
    }

    function _withdrawFrom(
        address from,
        address destination,
        uint128 amount
    ) internal {
        dai.transferFrom(from, destination, amount);
    }
}
