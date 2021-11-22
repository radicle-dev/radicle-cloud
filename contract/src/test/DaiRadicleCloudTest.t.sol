// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "ds-test/test.sol";
import {Hevm} from "./Hevm.t.sol";
import "../DaiRadicleCloud.sol";
import {Dai, PermitArgs} from "../lib/Dai.sol";

contract DaiRadicleCloudTest is DSTest {
    Hevm private hevm = Hevm(HEVM_ADDRESS);
    DaiRadicleCloud private rc;
    Dai private coin;

    function setUp() public {
        coin = new Dai("Dai", 1 ether);
        // price    = 1 dai/block
        // duration = 200 blocks
        // owner    = address(this)
        rc = new DaiRadicleCloud(1 wei, 200, address(this), coin);
    }

    function testSinglePurchaseSuspend() public {
        hevm.roll(20);
        coin.transfer(address(this), rc.getPrice());
        rc.buyOrRenewWithPermit(
            address(2),
            address(2),
            uint128(rc.getPrice()),
            PermitArgs({nonce: 0, expiry: 0, v: 0, r: 0, s: 0})
        );
        hevm.roll(50);
        rc.suspendDeployment(address(2));
        assertEq(rc.withdrawRealizedRevenue(), 30);
        hevm.roll(100);
        assertEq(rc.withdrawRealizedRevenue(), 0);
    }
}
