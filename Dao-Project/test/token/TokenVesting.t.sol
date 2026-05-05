pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/token/GovernanceToken.sol";
import "src/token/TokenVesting.sol";

contract TokenVestingTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    address teamUser = address(10);
    address treasuryUser = address(11);
    address airdropUser = address(12);
    address liquidityUser = address(13);

    uint256 constant INITIAL_TRANSFER = 400_000 ether;

    function setUp() public {
    token = new GovernanceToken(
        teamUser,
        treasuryUser,
        airdropUser,
        liquidityUser
    );

    vm.prank(teamUser);
    token.transfer(address(this), INITIAL_TRANSFER);

    vesting = new TokenVesting(
        address(token),
        teamUser,
        block.timestamp
    );

    // send tokens into vesting contract
    token.transfer(address(vesting), INITIAL_TRANSFER);
}

    // 1. vesting starts at zero
    function testInitialVesting() public view {
        assertEq(vesting.vestedAmount(), 0);
        assertEq(vesting.released(), 0);
    }

    // 2. linear vesting midpoint check
    function testLinearVestingMidpoint() public {
        vm.warp(block.timestamp + 180 days);

        uint256 vested = vesting.vestedAmount();

        uint256 half = INITIAL_TRANSFER / 2;
        assertGt(vested, half - 10_000 ether, "below ~50%");
        assertLt(vested, half + 10_000 ether, "above ~50%");
    }

    // 3. full vesting + release correctness
    function testFullVestingAndRelease() public {
        vm.warp(block.timestamp + 365 days);

        uint256 before = token.balanceOf(teamUser);

        vesting.release();

        uint256 afterBalance = token.balanceOf(teamUser);

        assertEq(vesting.released(), 400_000 ether, "full amount not released");
        assertEq(afterBalance - before, 400_000 ether, "teamUser balance wrong");
    }

    function testCannotReleaseBeforeVesting() public {
        uint256 before = token.balanceOf(teamUser);
        vesting.release();
        assertEq(token.balanceOf(teamUser), before, "should release nothing");
        assertEq(vesting.released(), 0);
    }
}
