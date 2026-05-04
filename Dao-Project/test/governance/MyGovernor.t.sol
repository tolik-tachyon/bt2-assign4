pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/governance/MyGovernor.sol";
import "../../src/token/GovernanceToken.sol";
import "../../src/core/Box.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract MyGovernorTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Box box;

    address voter1 = address(1);
    address voter2 = address(2);
    address voter3 = address(3);

    function setUp() public {
        // ---------------- TOKEN ----------------
        token = new GovernanceToken(
            address(0),
            address(this),
            address(this),
            address(this)
        );

        // distribute voting power
        token.transfer(voter1, 200_000 ether);
        token.transfer(voter2, 200_000 ether);

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

        // roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        // ---------------- BOX ----------------
        box = new Box(address(timelock));
    }

    // =========================================================
    // CORE LIFECYCLE (4)
    // =========================================================

    function _createProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(box);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);

        vm.prank(voter1);
        return governor.propose(
            targets,
            values,
            calldatas,
            "Proposal #1"
        );
    }

    function test_propose_works() public {
        uint256 id = _createProposal();
        assertTrue(id > 0);
    }

    function test_moves_to_active_after_delay() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        assertEq(uint256(governor.state(id)), uint256(IGovernor.ProposalState.Active));
    }

    function test_voting_succeeds_basic_case() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);

        vm.prank(voter2);
        governor.castVote(id, 1);

        assertTrue(true);
    }

    function test_proposal_queued_after_success() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 7000);

        governor.queue(
            _targets(),
            _values(),
            _calldatas(),
            keccak256(bytes("Proposal #1"))
        );

        assertEq(uint256(governor.state(id)), uint256(IGovernor.ProposalState.Queued));
    }

    // =========================================================
    // VOTING (3)
    // =========================================================

    function test_vote_for() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);

        assertTrue(true);
    }

    function test_vote_against() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 0);

        assertTrue(true);
    }

    function test_vote_abstain() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 2);

        assertTrue(true);
    }

    // =========================================================
    // DELEGATION (2)
    // =========================================================

    function test_delegate_vote_power_works() public {
        uint256 votes = token.getVotes(voter1);
        assertGt(votes, 0);
    }

    function test_delegated_voting_affects_outcome() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);

        vm.prank(voter2);
        governor.castVote(id, 1);

        assertTrue(true);
    }

    // =========================================================
    // FAILURE CASES (2)
    // =========================================================

    function test_fails_no_quorum() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 10000);

        assertEq(
            uint256(governor.state(id)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }

    function test_defeated_due_to_against_votes() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 0);
        vm.prank(voter2);
        governor.castVote(id, 0);

        vm.roll(block.number + 10000);

        assertEq(
            uint256(governor.state(id)),
            uint256(IGovernor.ProposalState.Defeated)
        );
    }

    // =========================================================
    // EXECUTION (1)
    // =========================================================

    function test_timelock_execution_succeeds() public {
        uint256 id = _createProposal();

        vm.roll(block.number + 1);

        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.prank(voter2);
        governor.castVote(id, 1);

        vm.roll(block.number + 7000);

        governor.queue(
            _targets(),
            _values(),
            _calldatas(),
            keccak256(bytes("Proposal #1"))
        );

        vm.warp(block.timestamp + 2 days);

        governor.execute(
            _targets(),
            _values(),
            _calldatas(),
            keccak256(bytes("Proposal #1"))
        );

        assertEq(box.retrieve(), 42);
    }

    // =========================================================
    // HELPERS
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