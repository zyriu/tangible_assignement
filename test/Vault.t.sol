// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/PropertyOracle.sol";
import "../src/Vault.sol";

contract VaultTest is Test {

  address public owner;

  PropertyOracle public propertyOracle;
  Vault public vault;

  // mock USDC
  ERC20PresetFixedSupply public USDC;

  function setUp() public {
    owner = address(this);
    propertyOracle = new PropertyOracle();
    USDC = new ERC20PresetFixedSupply("Circle USD", "USDC", UINT256_MAX, owner);
    vault = new Vault(address(propertyOracle), owner, address(USDC));
  }

  function testClaimShouldClaimRentProperly(uint256 TNFTId, uint256 weeklyRent) public {
    vm.assume(weeklyRent >= 500 * 1e18 && weeklyRent <= 50_000 * 1e18);
    propertyOracle.setPropertyInfo(TNFTId, weeklyRent, 1_000_000 * 1e18);
    vault.initializeRentCollection(TNFTId);
    USDC.approve(address(vault), UINT256_MAX);
    vault.payRent(TNFTId, UINT256_MAX);
    vm.warp(block.timestamp + 1 days);
    vault.claimRent();
    assertEq(USDC.balanceOf(owner), weeklyRent * 1 days / 7 days);
  }

  function testClaimShouldClaimRentProperlyWithOutstanding(uint256 weeklyRent) public {
    vm.assume(weeklyRent >= 500 * 1e18 && weeklyRent <= 50_000 * 1e18);
    propertyOracle.setPropertyInfo(0, weeklyRent, 1_000_000 * 1e18);
    propertyOracle.setPropertyInfo(1, weeklyRent * 2, 1_000_000 * 1e18);
    vault.initializeRentCollection(0);
    USDC.approve(address(vault), UINT256_MAX);
    vault.payRent(0, UINT256_MAX);
    vm.warp(block.timestamp + 1 days);
    vault.initializeRentCollection(1);
    assertEq(vault.outstandingBalance(), weeklyRent * 1 days / 7 days);
    assertEq(vault.accruedRent(), weeklyRent * 1 days / 7 days);
    vm.warp(block.timestamp + 1 days);
    assertEq(vault.outstandingBalance(), weeklyRent * 1 days / 7 days);
    vault.claimRent();
    assertApproxEqRel(USDC.balanceOf(owner), weeklyRent * 4 days / 7 days, 1e2);
  }

  function testClaimRentShouldRevertIfClaimedByNonRentCollector() public {
    vm.prank(address(0x42));
    vm.expectRevert("Unauthorized");
    vault.claimRent();
  }

  function testClaimRentShouldRevertIfClaimingWithoutPayment() public {
    propertyOracle.setPropertyInfo(0, 2000 * 1e18, 1_000_000 * 1e18);
    vault.initializeRentCollection(0);
    vm.warp(block.timestamp + 1000);
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InsufficientUSDCBalance()"))));
    vault.claimRent();
  }

  function testClaimRentShouldRevertIfRentHasBeenClaimed() public {
    propertyOracle.setPropertyInfo(0, 2000 * 1e18, 1_000_000 * 1e18);
    vault.initializeRentCollection(0);
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NothingToClaim()"))));
    vault.claimRent();
  }

  function testInitializeRentCollectionShouldSetRentProperly(uint256 TNFTId, uint256 weeklyRent) public {
    vm.assume(weeklyRent >= 500 * 1e18 && weeklyRent <= 50_000 * 1e18);
    propertyOracle.setPropertyInfo(TNFTId, weeklyRent, 1_000_000 * 1e18);
    assertEq(vault.totalWeeklyRental(), 0);
    vault.initializeRentCollection(TNFTId);
    assertEq(vault.latestClaimTimestamp(), block.timestamp);
    assertEq(vault.totalWeeklyRental(), weeklyRent);
  }

  function testPayRentShouldCreditPropertyAvailableCreditProperly(uint256 TNFTId, uint256 weeklyRent) public {
    vm.assume(weeklyRent >= 500 * 1e18 && weeklyRent <= 50_000 * 1e18);
    propertyOracle.setPropertyInfo(TNFTId, weeklyRent, 1_000_000 * 1e18);
    vault.initializeRentCollection(TNFTId);
    assertEq(vault.propertyAvailableCredit(TNFTId), 0);
    USDC.approve(address(vault), UINT256_MAX);
    vault.payRent(TNFTId, weeklyRent);
    assertEq(vault.propertyAvailableCredit(TNFTId), weeklyRent);
  }

  function testPayRentShouldCreditPropertyAvailableCreditMultiple(uint256 TNFTId, uint256 weeklyRent) public {
    vm.assume(weeklyRent >= 500 * 1e18 && weeklyRent <= 50_000 * 1e18);
    propertyOracle.setPropertyInfo(TNFTId, weeklyRent, 1_000_000 * 1e18);
    vault.initializeRentCollection(TNFTId);
    assertEq(vault.propertyAvailableCredit(TNFTId), 0);
    USDC.approve(address(vault), UINT256_MAX);
    vault.payRent(TNFTId, weeklyRent);
    assertEq(vault.propertyAvailableCredit(TNFTId), weeklyRent);
    vault.payRent(TNFTId, weeklyRent * 2);
    assertEq(vault.propertyAvailableCredit(TNFTId), weeklyRent * 3);
  }

  function testPayRentShouldRevertIfCalledWithZeroAmount() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidRentPayment()"))));
    vault.payRent(0, 0);
  }

  function testSetPropertyOracleShouldRevertIfNotCalledByOwner() public {
    vm.prank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");
    vault.setPropertyOracle(owner);
  }

  function testSetPropertyOracleShouldRevertIfCalledWithNullAddress() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NullAddress()"))));
    vault.setPropertyOracle(address(0x0));
  }

  function testSetPropertyOracleShouldSetOracleProperly() public {
    assertFalse(address(vault.propertyOracle()) == address(0x42));
    vault.setPropertyOracle(address(0x42));
    assertEq(address(vault.propertyOracle()), address(0x42));
  }

  function testSetRentCollectorShouldRevertIfNotCalledByOwner() public {
    vm.prank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");
    vault.setRentCollector(owner);
  }

  function testSetRentCollectorShouldRevertIfCalledWithNullAddress() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NullAddress()"))));
    vault.setRentCollector(address(0x0));
  }

  function testSetRentCollectorShouldSetRentCollectorProperly() public {
    assertEq(vault.rentCollector(), owner);
    vault.setRentCollector(address(0x42));
    assertEq(vault.rentCollector(), address(0x42));
  }
}
