// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "src/governance/MyGovernor.sol";
import "src/token/GovernanceToken.sol";
import "src/core/Box.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

contract DAO_Treasury_E2E_Test is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Box box;

    address voter1 = address(1);
    address voter2 = address(2);

    function setUp() public {
    // ---------------- ACTORS ----------------
    address teamUser = address(10);
    address treasuryUser = address(11);
    address airdropUser = address(12);
    address liquidityUser = address(13);

    // ---------------- TOKEN ----------------
    token = new GovernanceToken(
        teamUser,
        treasuryUser,
        airdropUser,
        liquidityUser
    );

    // ---------------- VOTERS ----------------
    vm.prank(teamUser);
    token.transfer(voter1, 500_000 ether);

    vm.prank(teamUser);
    token.transfer(voter2, 500_000 ether);

    // ---------------- DELEGATION ----------------
    vm.prank(voter1);
    token.delegate(voter1);

    vm.prank(voter2);
    token.delegate(voter2);

    vm.prank(teamUser);
    token.delegate(teamUser);

    vm.prank(treasuryUser);
    token.delegate(treasuryUser);

    vm.roll(block.number + 1);

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

    governor = new MyGovernor(token, timelock);

    timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
    timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

    // ---------------- TARGET CONTRACTS ----------------
    box = new Box(address(timelock));
    }

    function test_box_governance_full_flow() public {
        address[] memory targets = new address[](1);
        targets[0] = address(box);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);

        // ---------------- PROPOSE ----------------
        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Set Box = 42"
        );

        // ---------------- ACTIVE STATE ----------------
        vm.roll(block.number + 1);

        // ---------------- VOTING ----------------
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        // ---------------- QUEUE ----------------
        vm.roll(block.number + 7000);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Set Box = 42"))
        );

        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
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