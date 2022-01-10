// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "./RadicleCloudBase.sol";
import {IERC20} from "./EIP/ERC20.sol";
import {AuthorizationArgs} from "./EIP/EIP3009.sol";

/// @title RadicleCloud contract for USDC token.
contract USDCRadicleCloud is RadicleCloudBase {
    /// @notice The address of the ERC-20 contract we work with
    IERC20 public immutable erc20;

    /// @param price the rate we charge per block
    /// @param duration the length of the deployment in terms of blocks
    /// @param owner the owner of contract
    /// @param _erc20 the address of USDC contract we work with, supply must be lower than `2 ^ 127`
    constructor(
        uint64 price,
        uint32 duration,
        address owner,
        IERC20 _erc20
    ) RadicleCloudBase(price, duration, owner) {
        erc20 = _erc20;
    }

    /// @notice Buy or renew deployment with your USDC authorization.
    /// @param org the org buying deployment for
    /// @param owner the owner of the org
    /// @param authorizationArgs the USDC authorization arguments
    function buyOrRenewWithAuthorization(
        address org,
        address owner,
        AuthorizationArgs calldata authorizationArgs
    ) public {
        require(authorizationArgs.to == address(this), "Contract is not the recipient");
        erc20.transferWithAuthorization(
            authorizationArgs.from,
            authorizationArgs.to,
            authorizationArgs.value,
            authorizationArgs.validAfter,
            authorizationArgs.validBefore,
            authorizationArgs.nonce,
            authorizationArgs.v,
            authorizationArgs.r,
            authorizationArgs.s
        );
        topUp(org, owner, uint128(authorizationArgs.value));
    }

    function _withdraw(address destination, uint128 amount) internal override {
        erc20.transfer(destination, amount);
    }
}
