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

    function setUp() public {
    token = new GovernanceToken(
        teamUser,
        treasuryUser,
        airdropUser,
        liquidityUser
    );

    // ✅ FUND VESTING CONTRACT
    vm.prank(address(10));
    token.transfer(address(this), 1_000_000 ether);

    token.transfer(address(this), 1_000_000 ether);

    vesting = new TokenVesting(
        address(token),
        teamUser,
        block.timestamp
    );

    // send tokens into vesting contract
    token.transfer(address(vesting), 1_000_000 ether);
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

        uint256 before = token.balanceOf(teamUser);

        vesting.release();

        uint256 afterBalance = token.balanceOf(teamUser);

        assertGt(afterBalance, before);
        assertGt(vesting.released(), 0);
    }
}