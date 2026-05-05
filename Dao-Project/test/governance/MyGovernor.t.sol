// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "src/governance/MyGovernor.sol";
import "src/token/GovernanceToken.sol";
import "src/core/Box.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

contract MyGovernorTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Box box;

    address teamUser = address(10);
    address treasuryUser = address(11);
    address airdropUser = address(12);
    address liquidityUser = address(13);

    address voter1 = address(1);
    address voter2 = address(2);

    function setUp() public {
    token = new GovernanceToken(
        teamUser,
        treasuryUser,
        airdropUser,
        liquidityUser
    );

    // ✅ FUND VOTERS (MISSING BEFORE)
    vm.prank(liquidityUser);
    token.transfer(voter1, 500_000 ether);

    vm.prank(liquidityUser);
    token.transfer(voter2, 500_000 ether);

    vm.prank(voter1);
    token.delegate(voter1);

    vm.prank(voter2);
    token.delegate(voter2);

    vm.roll(block.number + 1);

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

    box = new Box(address(timelock));
    }

    // =========================================================
    // HELPERS
    // =========================================================

    function _proposal() internal returns (uint256) {
        address[] memory t = new address[](1);
        t[0] = address(box);

        uint256[] memory v = new uint256[](1);

        bytes[] memory c = new bytes[](1);
        c[0] = abi.encodeWithSignature("store(uint256)", 42);

        vm.prank(voter1);
        return governor.propose(t, v, c, "DAO proposal");
    }

    function _descHash() internal pure returns (bytes32) {
        return keccak256(bytes("DAO proposal"));
    }

    // =========================================================
    // 1. proposal creation
    // =========================================================
    function test_propose() public {
        uint256 id = _proposal();
        assertGt(id, 0);
    }

    // =========================================================
    // 2. proposal becomes active
    // =========================================================
    function test_state_active() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        assertEq(
            uint256(governor.state(id)),
            uint256(IGovernor.ProposalState.Active)
        );
    }

    // =========================================================
    // 3. voting FOR works
    // =========================================================
    function test_vote_for() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
    }

    // =========================================================
    // 4. voting AGAINST works
    // =========================================================
    function test_vote_against() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 0);
    }

    // =========================================================
    // 5. voting ABSTAIN works
    // =========================================================
    function test_vote_abstain() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 2);
    }

    // =========================================================
    // 6. delegation gives voting power
    // =========================================================
    function test_delegation() public {
    vm.prank(address(10));
    token.transfer(voter1, 1000 ether);

    vm.roll(block.number + 1);

    vm.prank(voter1);
    token.delegate(voter1);

    assertGt(token.getVotes(voter1), 0);
    }

    // =========================================================
    // 7. proposal succeeds with votes
    // =========================================================
    function test_succeeded_state() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 10000);

        assertEq(
            uint256(governor.state(id)),
            uint256(IGovernor.ProposalState.Succeeded)
        );
    }

    // =========================================================
    // 8. proposal queued
    // =========================================================
    function test_queue() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 10000);

        governor.queue(
            _targets(),
            _values(),
            _calldatas(),
            _descHash()
        );
    }

    // =========================================================
    // 9. execution works
    // =========================================================
    function test_execute() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 10000);

        governor.queue(
            _targets(),
            _values(),
            _calldatas(),
            _descHash()
        );

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(
            _targets(),
            _values(),
            _calldatas(),
            _descHash()
        );

        assertEq(box.retrieve(), 42);
    }

    // =========================================================
    // 10. proposal defeated (no votes)
    // =========================================================
    function test_defeated() public {
        uint256 id = _proposal();

        vm.roll(block.number + 10000);

        assertEq(
            uint256(governor.state(id)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }

    // =========================================================
    // 11. helper proposal state not broken
    // =========================================================
    function test_state_exists() public {
        uint256 id = _proposal();
        uint256 s = uint256(governor.state(id));
        assertTrue(s <= 7);
    }

    // =========================================================
    // 12. full lifecycle sanity check
    // =========================================================
    function test_full_lifecycle() public {
        uint256 id = _proposal();
        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 10000);

        governor.queue(
            _targets(),
            _values(),
            _calldatas(),
            _descHash()
        );

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(
            _targets(),
            _values(),
            _calldatas(),
            _descHash()
        );

        assertEq(box.retrieve(), 42);
    }

    // =========================================================
    // helpers
    // =========================================================
    function _targets() internal view returns (address[] memory t) {
        t = new address[](1);
        t[0] = address(box);
    }

    function _values() internal pure returns (uint256[] memory v) {
        v = new uint256[](1);
    }

    function _calldatas() internal pure returns (bytes[] memory c) {
        c = new bytes[](1);
        c[0] = abi.encodeWithSignature("store(uint256)", 42);
    }
}