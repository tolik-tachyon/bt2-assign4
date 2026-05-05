// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable start;
    uint256 public constant DURATION = 365 days;

    uint256 public released;

    constructor(address _token, address _beneficiary, uint256 _start) {
        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = _start;
    }

    function vestedAmount() public view returns (uint256) {
        uint256 total = token.balanceOf(address(this)) + released;

        if (block.timestamp < start) return 0;
        if (block.timestamp >= start + DURATION) return total;

        return (total * (block.timestamp - start)) / DURATION;
    }

    function release() external {
        uint256 vested = vestedAmount();
        uint256 amount = vested - released;

        released = vested;
        token.transfer(beneficiary, amount);
    }
}