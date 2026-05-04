// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/governance/MyGovernor.sol";
import "../../src/token/GovernanceToken.sol";
import "../../src/core/Box.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract DAO_Treasury_E2E_Test is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Box box;

    address voter1 = address(1);
    address voter2 = address(2);

    function setUp() public {
        // ---------------- TOKEN ----------------
        token = new GovernanceToken(
            address(0),
            address(this),
            address(this),
            address(this)
        );

        token.transfer(voter1, 300_000 ether);
        token.transfer(voter2, 300_000 ether);

        vm.prank(voter1);
        token.delegate(voter1);

        vm.prank(voter2);
        token.delegate(voter2);

        // ---------------- TIMELOCK ----------------
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            address(this)
        );

        // ---------------- GOVERNOR ----------------
        governor = new MyGovernor(token, timelock);

        // roles setup
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        // ---------------- BOX ----------------
        box = new Box(address(timelock));
    }

    // =========================================================
    // TASK 3 REQUIRED E2E TEST
    // =========================================================
    function test_box_governance_full_flow() public {
        // ---------------- PROPOSE ----------------
        address[] memory targets = new address[](1);
        targets[0] = address(box);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "store(uint256)",
            42
        );

        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Set Box = 42"
        );

        // ---------------- MOVE TO ACTIVE ----------------
        vm.roll(block.number + 1);

        // ---------------- VOTING ----------------
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // FOR

        vm.prank(voter2);
        governor.castVote(proposalId, 1); // FOR

        // ---------------- QUEUE ----------------
        vm.roll(block.number + 7000);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Set Box = 42"))
        );

        // ---------------- EXECUTE ----------------
        vm.warp(block.timestamp + 2 days);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Set Box = 42"))
        );

        // ---------------- VERIFY ----------------
        assertEq(box.retrieve(), 42);
    }
}