// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import {Hevm} from "./Hevm.t.sol";
import "../EthRadicleCloud.sol";

contract EthRadicleCloudTest is DSTest {
    Hevm private hevm = Hevm(HEVM_ADDRESS);
    EthRadicleCloud private rc;

    function setUp() public {
        // price    = 1 wei/block
        // duration = 200 blocks
        // owner    = address(this)
        rc = new EthRadicleCloud(1 wei, 200, address(this));
    }

    // contract is owner thus should be able to receive ether
    receive() external payable {
        msg.value;
    }

    function buyOnePackageForAddress(uint160 org) public {
        rc.buyOrRenew{value: rc.getPrice()}(address(org), address(org));
    }

    function testPrice() public {
        uint256 price = rc.getPrice();
        assertEq(price, 1 wei * rc.duration());
    }

    function testFailNewPurchaseLowAmount() public {
        rc.buyOrRenew{value: rc.getPrice() - 1}(address(2), address(2));
        assertEq(rc.getExpiry(address(2)), rc.duration());
    }

    function testNewPurchase() public {
        buyOnePackageForAddress(2);
        assertEq(rc.getExpiry(address(2)), rc.duration());
    }

    function testFailOneAndPlusPurchase() public {
        rc.buyOrRenew{value: rc.getPrice() + (rc.getPrice() / 2)}(address(2), address(2));
        assertEq(rc.getExpiry(address(2)), rc.duration());
    }

    function testRenew() public {
        buyOnePackageForAddress(2);
        buyOnePackageForAddress(2);
        assertEq(rc.getExpiry(address(2)), rc.duration() * 2);
    }

    function testSinglePurchaseTwoPeriods() public {
        hevm.roll(20);
        rc.buyOrRenew{value: rc.getPrice() * 3}(address(2), address(2));
        assertEq(rc.getExpiry(address(2)), rc.duration() * 3 + 20);
    }

    function testSinglePurchaseMid() public {
        hevm.roll(20);
        buyOnePackageForAddress(2);
        hevm.roll(120);
        assertEq(rc.withdrawRealizedRevenue(), 100);
    }

    function testSinglePurchaseEnd() public {
        hevm.roll(20);
        buyOnePackageForAddress(2);
        hevm.roll(220);
        assertEq(rc.withdrawRealizedRevenue(), 200);
    }

    function testSinglePurchaseOut() public {
        hevm.roll(20);
        buyOnePackageForAddress(2);
        hevm.roll(999);
        assertEq(rc.withdrawRealizedRevenue(), 200);
    }

    function testSinglePurchaseMultiWithdraw() public {
        hevm.roll(20);
        buyOnePackageForAddress(2);
        hevm.roll(120);
        assertEq(rc.withdrawRealizedRevenue(), 100);
        hevm.roll(220);
        assertEq(rc.withdrawRealizedRevenue(), 100);
        hevm.roll(300);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }

    function testSinglePurchaseSuspend() public {
        hevm.roll(20);
        buyOnePackageForAddress(2);
        hevm.roll(50);
        rc.suspendDeployment(address(2));
        assertEq(address(2).balance, rc.getPrice() - 30);
        uint256 preWithdrawBalance = address(this).balance;
        assertEq(rc.withdrawRealizedRevenue(), 30);
        uint256 postWithdrawBalance = address(this).balance;
        assertEq(postWithdrawBalance - preWithdrawBalance, 30);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }

    function testSinglePurchaseRenewWithdraw() public {
        buyOnePackageForAddress(2);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 100);
        rc.changeRate(4);
        buyOnePackageForAddress(2);
        hevm.roll(150);
        assertEq(rc.withdrawRealizedRevenue(), 50);
        hevm.roll(400);
        assertEq(rc.withdrawRealizedRevenue(), 50 + 800);
        hevm.roll(999);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }

    function testSinglePurchaseRenewWithdrawMidSecond() public {
        buyOnePackageForAddress(2);
        hevm.roll(100);
        rc.changeRate(4);
        buyOnePackageForAddress(2);
        hevm.roll(300);
        rc.suspendDeployment(address(2));
        assertEq(address(2).balance, 400);
    }

    function testSinglePurchaseReverseChangeRate() public {
        rc.changeRate(4);
        buyOnePackageForAddress(2);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 400);
        rc.changeRate(1);
        buyOnePackageForAddress(2);
        hevm.roll(150);
        assertEq(rc.withdrawRealizedRevenue(), 200);
        hevm.roll(400);
        assertEq(rc.withdrawRealizedRevenue(), 200 + 200);
        hevm.roll(999);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }

    function testSinglePurchaseRenewWithdrawOut() public {
        buyOnePackageForAddress(2);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 100);
        rc.changeRate(4);
        buyOnePackageForAddress(2);
        hevm.roll(999);
        assertEq(rc.withdrawRealizedRevenue(), 900);
    }

    function testDepHasCorrectOwner() public {
        buyOnePackageForAddress(2);
        (, , address owner) = rc.dep(address(2));
        assertEq(owner, address(2));
    }

    function testDepHasNewOwnerWhenRenewAfterExpiry() public {
        buyOnePackageForAddress(2);
        (, , address owner) = rc.dep(address(2));
        assertEq(owner, address(2));
        hevm.roll(250);
        rc.buyOrRenew{value: rc.getPrice()}(address(2), address(3));
        assertEq(owner, address(2));
    }

    function testMultiPurchaseUpgradeSuspend() public {
        hevm.roll(20); // @ t = 20
        buyOnePackageForAddress(2);
        hevm.roll(40); // @ t = 40
        buyOnePackageForAddress(4);
        hevm.roll(60); // @ t = 60
        buyOnePackageForAddress(6);
        hevm.roll(140); // @ t = 140
        rc.suspendDeployment(address(2)); // suspend org (2)
        assertEq(address(2).balance, rc.getPrice() - 120);
        rc.suspendDeployment(address(6)); // suspend org (6)
        assertEq(address(6).balance, rc.getPrice() - 80);
        assertEq(rc.withdrawRealizedRevenue(), 120 + 100 + 80);
        rc.changeRate(4);
        buyOnePackageForAddress(4);
        (uint64 start, uint64 expiry, ) = rc.dep(address(4));
        assertEq(start, 40);
        assertEq(expiry, 440);
        hevm.roll(445); // @ t = 445 (out)
        assertEq(rc.withdrawRealizedRevenue(), 100 + 800);
        hevm.roll(999);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }

    function testMultiPurchaseSuspendExpireUpgradeGap() public {
        hevm.roll(20); // @ t = 20
        buyOnePackageForAddress(2); // 20 --> 220 org (2)
        hevm.roll(40); // @ t = 40
        buyOnePackageForAddress(4); // 40 --> 240 org (4)
        hevm.roll(60); // @ t = 60
        buyOnePackageForAddress(6); // 60 --> 260 org (6)
        hevm.roll(140); // @ t = 140
        rc.suspendDeployment(address(2)); // suspended org (2): 20 --> 140
        assertEq(address(2).balance, rc.getPrice() - 120);
        rc.changeRate(4);
        buyOnePackageForAddress(4); // 40 --> 440 org (4), total 1000
        hevm.roll(440); // @ t = 440
        buyOnePackageForAddress(8); // 440 --> 640 org (8), total 800
        hevm.roll(999); // @ t = 999 (out)
        assertEq(rc.withdrawRealizedRevenue(), 120 + 1000 + 200 + 800);
    }

    function testMultiPurchaseMultiRenewSuspend() public {
        buyOnePackageForAddress(2);
        buyOnePackageForAddress(4);
        hevm.roll(100);
        buyOnePackageForAddress(4);
        hevm.roll(300);
        rc.suspendDeployment(address(4));
        assertEq(rc.withdrawRealizedRevenue(), 500);
    }

    function testSuspendExpiredDep() public {
        buyOnePackageForAddress(2);
        hevm.roll(250);
        rc.suspendDeployment(address(2));
        assertEq(address(2).balance, 0);
        rc.suspendDeployment(address(4));
        assertEq(address(4).balance, 0);
    }
}
