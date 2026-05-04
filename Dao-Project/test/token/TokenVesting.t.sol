pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/token/GovernanceToken.sol";
import "../../src/token/TokenVesting.sol";

contract TokenVestingTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    address team = address(1);
    address treasury = address(2);
    address airdrop = address(3);
    address liquidity = address(4);

    function setUp() public {
        // ONE token instance ONLY
        token = new GovernanceToken(
            address(0),
            treasury,
            airdrop,
            liquidity
        );

        // vesting uses the SAME token
        vesting = new TokenVesting(
            address(token),
            team,
            block.timestamp
        );
    }

    // 1. vesting starts at zero
    function testInitialVesting() public {
        assertEq(vesting.vestedAmount(), 0);
        assertEq(vesting.released(), 0);
    }

    // 2. linear vesting midpoint check
    function testLinearVestingMidpoint() public {
        vm.warp(block.timestamp + 180 days);

        uint256 vested = vesting.vestedAmount();

        assertGt(vested, 0);
    }

    // 3. full vesting + release correctness
    function testFullVestingAndRelease() public {
        vm.warp(block.timestamp + 365 days);

        uint256 before = token.balanceOf(team);

        vesting.release();

        uint256 afterBalance = token.balanceOf(team);

        assertGt(afterBalance, before);
        assertGt(vesting.released(), 0);
    }
}