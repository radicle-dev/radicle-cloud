// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.6;

/// @notice Special array of impact points to track rate.
/// @dev First item is index currently being pointed to and last item always has to be UINT64_MAX.
library ImpactPoints {
    function add(uint64[] storage self, uint64 value) internal {
        if (self.length > 2 && self[self.length - 2] == value) return;
        self[self.length - 1] = value;
        self.push(type(uint64).max);
    }

    function last(uint64[] storage self) internal view returns (uint64) {
        return self[self[0]];
    }

    function next(uint64[] storage self) internal {
        /*
        if (self[self[0]] != type(uint64).max) {
            // bring everything back one index
            for (uint i = self[0] + 1; i < self.length ; ++i) {
                self[i-1] = self[i];
            }
            // pop last element
            self.pop();
            return;
        }
        */
        self[0] += 1;
    }
}
