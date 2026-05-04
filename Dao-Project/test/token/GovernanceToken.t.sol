pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/token/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;

    address teamVesting = address(1);
    address treasury = address(2);
    address airdrop = address(3);
    address liquidity = address(4);

    address voter = address(10);

    function setUp() public {
        token = new GovernanceToken(
            teamVesting,
            treasury,
            airdrop,
            liquidity
        );
    }

    // 1. correct initial distribution
    function testInitialDistribution() public {
        assertEq(token.balanceOf(treasury), 300_000 ether);
        assertEq(token.balanceOf(airdrop), 200_000 ether);
        assertEq(token.balanceOf(liquidity), 100_000 ether);
        assertEq(token.balanceOf(teamVesting), 400_000 ether);
    }

    // 2. delegation enables voting power
    function testDelegation() public {
        vm.prank(treasury);
        token.delegate(voter);

        assertGt(token.getVotes(voter), 0);
    }

    // 3. voting power snapshot consistency
    function testVotingPowerSnapshot() public {
        vm.prank(treasury);
        token.delegate(treasury);

        uint256 votes = token.getVotes(treasury);
        uint256 balance = token.balanceOf(treasury);

        assertEq(votes, balance);
    }

    // 4. permit works (EIP-2612)
    function testPermit() public {
        uint256 pk = 0xA11CE;
        address owner = vm.addr(pk);

        deal(address(token), owner, 100 ether);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    address(this),
                    100 ether,
                    nonce,
                    deadline
                ))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        token.permit(owner, address(this), 100 ether, deadline, v, r, s);

        assertEq(token.allowance(owner, address(this)), 100 ether);
    }

    // 5. delegation changes voting power dynamically
    function testDelegationUpdate() public {
        vm.prank(treasury);
        token.delegate(voter);

        uint256 before = token.getVotes(voter);

        vm.prank(airdrop);
        token.transfer(voter, 100 ether);

        assertGt(token.getVotes(voter), before);
    }
}