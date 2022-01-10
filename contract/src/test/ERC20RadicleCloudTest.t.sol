// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "../ERC20RadicleCloud.sol";
import {Hevm} from "./Hevm.t.sol";
import {ERC20, IERC20} from "../EIP/ERC20.sol";
import {AuthorizationArgs} from "../EIP/EIP3009.sol";

contract ERC20RadicleCloudTest is DSTest {
    Hevm private hevm = Hevm(HEVM_ADDRESS);
    ERC20RadicleCloud private rc;
    ERC20 private coin;

    function setUp() public {
        coin = new ERC20("CLD", 1 ether);
        // price    = 1 cld/block
        // duration = 200 blocks
        // owner    = address(this)
        rc = new ERC20RadicleCloud(1 wei, 200, address(this), coin);
    }

    function testSinglePurchaseSuspend() public {
        hevm.roll(20);
        coin.transfer(address(this), rc.getPrice());
        rc.buyOrRenew(address(2), address(2), uint128(rc.getPrice()));
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
