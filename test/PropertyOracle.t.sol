// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../src/PropertyOracle.sol";

contract PropertyOracleTest is Test {

  address public owner;

  PropertyOracle public propertyOracle;

  function setUp() public {
    owner = address(this);
    propertyOracle = new PropertyOracle(owner);
    assertEq(propertyOracle.DECIMALS(), 9);
  }

  function testSetPropertyInfoShouldRevertIfNotCalledByAdmin(uint256 TNFTIndex, uint256 rent, uint256 tpv) public {
    vm.startPrank(address(0x42));
    vm.expectRevert();
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
    vm.stopPrank();
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
  }

  function testSetPropertyInfoShouldSetValuesCorrectly(uint256 TNFTIndex, uint256 rent, uint256 tpv) public {
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
    (uint256 storedRent, uint256 storedTpv) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(rent, storedRent);
    assertEq(tpv, storedTpv);
  }
}
