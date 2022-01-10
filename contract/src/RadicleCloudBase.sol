// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

import "./lib/ImpactPoints.sol";

/// @title RadicleCloudBase does on-chain accounting and emits events for operator.
/// @dev RadicleCloudBase is an abstract contract.
abstract contract RadicleCloudBase {
    /// @notice Owner is needed for changing rate and withdrawing funds.
    address public owner;

    /// @dev Keep info for tracking each deployment
    struct Deployment {
        uint64 start;
        uint64 expiry;
        address owner;
    }
    /// @notice Info regading each deployment
    mapping(address => Deployment) public dep;

    /// @dev Keep track of each package that was used to top up
    struct Package {
        uint64 start;
        uint64 expiry;
        uint64 rate;
    }
    /// @notice Array of packages that topped up the deployment of org
    mapping(address => Package[]) public pkgs;

    /// @notice Rate (price) new top ups are charged
    uint64 public ratePerBlock;
    /// @notice Rate (price) currently being earned
    int64 private runningRate = 0;

    /// @notice Duration of a package in terms of blocks
    uint32 public immutable duration;
    /// @notice Blocks to wait before being eligible for withdraw
    uint32 public immutable withdrawWait;

    /// @notice MAXBLOCK is the maximum value of uint64
    uint64 private constant MAXBLOCK = type(uint64).max;

    /// @dev Add functionalities for index and block retrieval
    using ImpactPoints for uint64[];
    /// @notice Special array of blocks when buys happened
    uint64[] private buys = [1, MAXBLOCK];
    /// @notice Special array of blocks when expires happen
    uint64[] private expires = [1, MAXBLOCK];
    /// @notice Special array of blocks when cancels happened
    uint64[] private cancels = [1, MAXBLOCK];
    /// @notice Special array of blocks when renews happened
    uint64[] private renews = [1, MAXBLOCK];
    /// @notice Whether a renewal happened at this block
    mapping(uint64 => bool) private hasRenewal;
    /// @notice Sum of unaccounted impacts at block t
    mapping(uint64 => int64) private impacts;

    /// @dev Last block we've withdrawn funds utill.
    uint64 private lastProcessed;

    /// @notice Emitted when money is deposited, could be renewal or initial order.
    /// @param org the org owning the deployment
    /// @param expiry next expiry for this deployment
    event NewTopUp(address org, uint64 expiry);

    /// @notice Emitted when deployment for org is cancelled or suspended.
    /// @param org the org owning the deployment
    /// @param expiry when this deployment was stopped
    event DeploymentStopped(address org, uint64 expiry);

    /// @notice Modifier to check if caller is owner.
    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    /// @notice Create a new contract.
    /// @param price amount that should be charged per block
    /// @param _duration immutable number of blocks each top up lasts
    /// @param _owner owner of this contract
    constructor(
        uint64 price,
        uint32 _duration,
        address _owner
    ) {
        duration = _duration;
        withdrawWait = (_duration * 3) / 100;
        owner = _owner;
        ratePerBlock = price;
        lastProcessed = uint64(block.number);
    }

    /// @notice Change owner of contract.
    /// @param newOwner address of new owner
    function changeOwner(address newOwner) public isOwner {
        owner = newOwner;
    }

    /// @notice Change ratePerBlock for orders after this block.
    /// @param newRate the new rate per block
    function changeRate(uint64 newRate) public isOwner {
        ratePerBlock = newRate;
    }

    /// @notice Return current package price.
    function getPrice() public view returns (uint256) {
        return ratePerBlock * duration;
    }

    /// @notice Return deployment expiry for org.
    /// @param org the org owning the deployment
    /// @return expiry block number
    function getExpiry(address org) external view returns (uint64) {
        return dep[org].expiry;
    }

    /// @notice Top up existing deployment or create a new one.
    /// @param org the address of org whose deployment we're topping up
    /// @param _owner the address to set deployment owner to on creation
    /// @param amount the amount being topped up, must be exact multiples of `ratePerBlock * duration`
    function topUp(
        address org,
        address _owner,
        uint128 amount
    ) internal {
        require(amount >= ratePerBlock * duration, "Amount is not enough for a single package");
        require(
            amount % (ratePerBlock * duration) == 0,
            "Amount is not exact multiple of getPrice()"
        );

        uint128 packages = amount / (ratePerBlock * duration);
        if (dep[org].expiry > block.number) {
            // active user
            for (uint64 i = 0; i < packages; ++i) {
                hasRenewal[dep[org].expiry + (i * duration)] = true;
            }

            uint64 newExpiry = uint64(dep[org].expiry + packages * duration);
            // NOTE: this can be optimized, probably
            pkgs[org].push(
                Package({start: dep[org].expiry, expiry: newExpiry, rate: ratePerBlock})
            );

            impacts[dep[org].expiry] += int64(ratePerBlock);
            dep[org].expiry = newExpiry;
            impacts[dep[org].expiry] -= int64(ratePerBlock);
        } else {
            // new user
            for (uint64 i = 0; i < packages; ++i) {
                hasRenewal[uint64(block.number) + (i * duration)] = true;
            }

            dep[org].expiry = uint64(block.number + packages * duration);
            dep[org].start = uint64(block.number);
            dep[org].owner = _owner;

            buys.add(uint64(block.number));
            expires.add((uint64(block.number + duration)));

            impacts[uint64(block.number)] += int64(ratePerBlock);
            impacts[uint64(block.number + duration)] -= int64(ratePerBlock);
            pkgs[org].push(
                Package({start: dep[org].start, expiry: dep[org].expiry, rate: ratePerBlock})
            );
        }
        emit NewTopUp(org, dep[org].expiry);
    }

    /// @dev Biggest between `a` and `b`.
    function max(uint64 a, uint64 b) internal pure returns (uint64) {
        return a > b ? a : b;
    }

    /// @dev Smaller between `a` and `b`.
    function min(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }

    /// @dev Return next impact point for rate.
    /// @return smallest block between next buy, expiry, cancel, and renew
    function _nextImpact() internal view returns (uint64) {
        return min(min(buys.last(), expires.last()), min(cancels.last(), renews.last()));
    }

    /// @dev Calculate the amount operator has earned till current block.
    /// @return revenue earned from last processed blocked till now
    function _calcRealizedRevenue() internal returns (uint128) {
        uint128 revenue = 0;
        int64 rate = runningRate;
        uint64 last = lastProcessed;
        uint64 current = uint64(block.number);
        while (last <= current) {
            uint64 nextLast = _nextImpact();
            if (nextLast == MAXBLOCK) break;
            if (nextLast == last) {
                rate += impacts[last];
                if (last == buys.last()) buys.next();
                if (last == cancels.last()) cancels.next();
                if (last == renews.last()) renews.next();
                if (last == expires.last()) {
                    // create renews on fly
                    if (hasRenewal[last]) {
                        renews.add(last + duration);
                        delete hasRenewal[last];
                    }
                    expires.next();
                }
                delete impacts[last];
                nextLast = _nextImpact();
            }
            revenue += uint64(rate) * (min(current, nextLast) - last);
            last = nextLast;
        }

        runningRate = rate;
        lastProcessed = current;
        return revenue;
    }

    /// @notice Update realized revenue and accounting for owner.
    /// @return amount earned by owner till current block
    function withdrawRealizedRevenue() public isOwner returns (uint128 amount) {
        amount = _calcRealizedRevenue();
        _withdraw(owner, amount);
    }

    /// @dev Stop deployment and payout outstanding balance.
    /// @param org the org owning deployment
    function _stopDeploymentAndPayout(address org) internal {
        Package[] storage currentPkgs = pkgs[org];
        uint128 due = 0;

        for (uint64 i = 0; i < currentPkgs.length; ++i) {
            Package storage pkg = currentPkgs[i];
            if (block.number < pkg.expiry) {
                due += pkg.rate * (pkg.expiry - max(uint64(block.number), pkg.start));
                // cancel impacts of pkg
                impacts[uint64(block.number)] -= int64(pkg.rate);
                impacts[pkg.expiry] += int64(pkg.rate);
                delete currentPkgs[i];
            }
        }

        cancels.add(uint64(block.number));
        _withdraw(dep[org].owner, due);
        emit DeploymentStopped(org, uint64(block.number));
    }

    /// @notice Cancel deployment for org and withdraw remaining fund.
    /// @param org the org owning deployment, deployment must be owned by caller
    function cancelDeployment(address org) public {
        require(dep[org].owner == msg.sender, "Caller does not own org");
        require(
            dep[org].start + withdrawWait <= block.number,
            "Withdraw wait period hasn't finished"
        );
        _stopDeploymentAndPayout(org);
    }

    /// @notice Suspend deployment and transfer remaining fund.
    /// @param org the org owning deployment
    function suspendDeployment(address org) public isOwner {
        _stopDeploymentAndPayout(org);
    }

    /// @notice Withdraw amount money to destination address.
    /// @dev called when funds need to be withdraw by org's or contract's owner
    /// @param destination destination address to send funds to
    /// @param amount transferred amount
    function _withdraw(address destination, uint128 amount) internal virtual;
}
