// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Box {
    address public immutable timelock;
    uint256 private value;

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Not timelock");
        _;
    }

    constructor(address _timelock) {
        timelock = _timelock;
    }

    // -------------------------
    // GOVERNED STATE CHANGE
    // -------------------------
    function store(uint256 _value) external onlyTimelock {
        value = _value;
    }

    function retrieve() external view returns (uint256) {
        return value;
    }
}