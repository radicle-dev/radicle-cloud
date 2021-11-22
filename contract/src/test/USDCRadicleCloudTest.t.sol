// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "../USDCRadicleCloud.sol";
import {Hevm} from "./Hevm.t.sol";
import {ERC20, IERC20} from "../EIP/ERC20.sol";
import {AuthorizationArgs} from "../EIP/EIP3009.sol";

contract USDCRadicleCloudTest is DSTest {
    Hevm private hevm = Hevm(HEVM_ADDRESS);
    USDCRadicleCloud private rc;
    ERC20 private coin;

    function setUp() public {
        coin = new ERC20("USDC", 1 ether);
        // price    = 1 usdc/block
        // duration = 200 blocks
        // owner    = address(this)
        rc = new USDCRadicleCloud(1 wei, 200, address(this), coin);
    }

    function testSinglePurchaseSuspend() public {
        hevm.roll(20);
        coin.transfer(address(2), rc.getPrice());
        rc.buyOrRenewWithAuthorization(
            address(2),
            address(2),
            AuthorizationArgs({
                from: address(2),
                to: address(rc),
                value: rc.getPrice(),
                validAfter: 0,
                validBefore: 0,
                nonce: 0,
                v: 0,
                r: 0,
                s: 0
            })
        );
        // make sure all was spent
        assertEq(coin.balanceOf(address(2)), 0);
        assertEq(coin.balanceOf(address(rc)), rc.getPrice());
        // make sure operator only withdrew 30
        hevm.roll(50);
        uint256 preWithdrawBalance = coin.balanceOf(address(this));
        assertEq(rc.withdrawRealizedRevenue(), 30);
        uint256 postWithdrawBalance = coin.balanceOf(address(this));
        assertEq(postWithdrawBalance - preWithdrawBalance, 30);
        // suspend deployment
        rc.suspendDeployment(address(2));
        // make sure user gets (balance - 30) back
        assertEq(coin.balanceOf(address(2)), rc.getPrice() - 30);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }
}
