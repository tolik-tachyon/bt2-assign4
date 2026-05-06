// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Box {
    address public immutable timelock;
    uint256 private _value;

    event ValueChanged(uint256 value);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Not timelock");
        _;
    }

    constructor(address _timelock) {
        require(_timelock != address(0));
        timelock = _timelock;
    }

    // -------------------------
    // GOVERNED STATE CHANGE
    // -------------------------
    function store(uint256 value) external onlyTimelock {
        _value = value;
        emit ValueChanged(value);
    }

    function retrieve() external view returns (uint256) {
        return _value;
    }
}
