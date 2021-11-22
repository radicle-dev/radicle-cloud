// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "./RadicleCloudBase.sol";

/// @title RadicleCloud contract for Ether.
contract EthRadicleCloud is RadicleCloudBase {
    /// @param price the rate we charge per block
    /// @param duration the length of the deployment in terms of blocks
    /// @param owner the owner of contract
    constructor(
        uint64 price,
        uint32 duration,
        address owner
    ) RadicleCloudBase(price, duration, owner) {
        return;
    }

    /// @notice Buy or renew deployment.
    /// @param org the org buying deployment for
    /// @param owner the owner of the org
    function buyOrRenew(address org, address owner) public payable {
        topUp(org, owner, uint128(msg.value));
    }

    function _withdraw(address destination, uint128 amount) internal override {
        if (amount == 0) return;
        payable(destination).transfer(amount);
    }
}
