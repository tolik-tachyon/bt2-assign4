// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Treasury {
    address public immutable timelock;

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Not timelock");
        _;
    }

    constructor(address _timelock) {
        require(_timelock != address(0));
        timelock = _timelock;
    }

    // -------------------------
    // ETH
    // -------------------------
    receive() external payable {}

    function withdrawETH(address payable to, uint256 amount)
        external
        onlyTimelock
    {
        require(to != address(0));
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // -------------------------
    // ERC20
    // -------------------------
    function withdrawToken(
        address token,
        address to,
        uint256 amount
    ) external onlyTimelock {
        require(
            IERC20(token).transfer(to, amount),
            "Token transfer failed"
        );
    }
}
