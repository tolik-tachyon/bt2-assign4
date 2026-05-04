// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../src/token/GovernanceToken.sol";
import "../src/token/TokenVesting.sol";
import "../src/governance/MyGovernor.sol";
import "../src/treasury/Treasury.sol";
import "../src/core/Box.sol";

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // =====================================================
        // 1. TOKEN VESTING
        // =====================================================

        TokenVesting vesting = new TokenVesting(
            address(0),
            msg.sender,
            block.timestamp
        );

        // =====================================================
        // 2. GOVERNANCE TOKEN
        // =====================================================

        GovernanceToken token = new GovernanceToken(
            address(vesting),
            msg.sender,
            msg.sender,
            msg.sender
        );

        // =====================================================
        // 3. TIMELOCK (CLEAN OZ v5 SETUP)
        // =====================================================

        address[] memory proposers = new address[](0); // EMPTY initially
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute

        TimelockController timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            msg.sender
        );

        // =====================================================
        // 4. TREASURY + BOX
        // =====================================================

        Treasury treasury = new Treasury(address(timelock));
        Box box = new Box(address(timelock));

        // =====================================================
        // 5. GOVERNOR
        // =====================================================

        MyGovernor governor = new MyGovernor(
            token,
            timelock
        );

        // =====================================================
        // 6. ROLE SETUP (IMPORTANT FIX)
        // =====================================================

        // Governor becomes proposer
        timelock.grantRole(
            timelock.PROPOSER_ROLE(),
            address(governor)
        );

        // Executor open
        timelock.grantRole(
            timelock.EXECUTOR_ROLE(),
            address(0)
        );

        // OPTIONAL BEST PRACTICE: remove deployer admin rights
        timelock.revokeRole(
            timelock.DEFAULT_ADMIN_ROLE(),
            msg.sender
        );

        // =====================================================
        // 7. OUTPUT
        // =====================================================

        console.log("=== DAO DEPLOYED ===");
        console.log("Token:", address(token));
        console.log("Vesting:", address(vesting));
        console.log("Governor:", address(governor));
        console.log("Timelock:", address(timelock));
        console.log("Treasury:", address(treasury));
        console.log("Box:", address(box));

        vm.stopBroadcast();
    }
}