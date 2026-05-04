// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/token/GovernanceToken.sol";
import "../../src/governance/MyGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/core/Box.sol";
import "../../src/treasury/Treasury.sol";

contract FullFlowTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;

    Box box;
    Treasury treasury;

    address alice = address(1);
    address bob = address(2);

    uint256 constant VOTING_DELAY = 7200;
    uint256 constant VOTING_PERIOD = 50400;

    function setUp() public {
        // ───────── TOKEN ─────────
        token = new GovernanceToken(
            address(100),
            address(101),
            address(102),
            address(103)
        );

        // ───────── TIMELOCK ─────────
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            address(this)
        );

        // ───────── GOVERNOR ─────────
        governor = new MyGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        // ───────── TARGETS ─────────
        box = new Box(address(timelock));
        treasury = new Treasury(address(timelock));

        // ❌ REMOVED (NOT OWNABLE)
        // box.transferOwnership(address(timelock));
        // treasury.transferOwnership(address(timelock));

        // ───────── VOTING POWER ─────────
        token.transfer(alice, 1000 ether);
        token.transfer(bob, 1000 ether);

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(bob);
        token.delegate(bob);
    }

    function testFullDAOFlow() public {
        // ============================
        // 1. PROPOSAL: Box.store(42)
        // ============================
        address[] memory targets = new address[](1);
        targets[0] = address(box);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);

        string memory description = "Set Box to 42";

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // ============================
        // 2. VOTING
        // ============================
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.prank(bob);
        governor.castVote(proposalId, 1);

        // ============================
        // 3. QUEUE
        // ============================
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(description));

        governor.queue(targets, values, calldatas, descHash);

        // ============================
        // 4. EXECUTE
        // ============================
        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(targets, values, calldatas, descHash);

        assertEq(box.retrieve(), 42);

        // ============================
        // 5. TREASURY PROPOSAL
        // ============================
        vm.deal(address(treasury), 10 ether);

        address[] memory t2 = new address[](1);
        t2[0] = address(treasury);

        uint256[] memory v2 = new uint256[](1);

        bytes[] memory c2 = new bytes[](1);

        // ✔ FIXED FUNCTION NAME
        c2[0] = abi.encodeWithSignature(
            "withdrawETH(address,uint256)",
            alice,
            5 ether
        );

        string memory desc2 = "Send ETH";

        uint256 proposal2 = governor.propose(t2, v2, c2, desc2);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        governor.castVote(proposal2, 1);

        vm.prank(bob);
        governor.castVote(proposal2, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(t2, v2, c2, keccak256(bytes(desc2)));

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(t2, v2, c2, keccak256(bytes(desc2)));

        // ============================
        // 6. FINAL CHECKS
        // ============================
        assertEq(box.retrieve(), 42);
        assertGt(alice.balance, 0);
    }
}