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
  }

  function testSetPropertyInfoShouldRevertIfNotCalledByAdmin(uint256 TNFTIndex, uint256 rent, uint256 tpv) public {
    vm.startPrank(address(0x42));
    vm.expectRevert();
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
    vm.stopPrank();
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
  }

  function testSetPropertyInfoShouldSetInfoCorrectly(uint256 TNFTIndex, uint256 rent, uint256 tpv) public {
    (uint256 storedRent, uint256 storedTpv) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(storedRent, 0);
    assertEq(storedTpv, 0);
    propertyOracle.setPropertyInfo(TNFTIndex, rent, tpv);
    (storedRent, storedTpv) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(rent, storedRent);
    assertEq(tpv, storedTpv);
  }

  function testUpdatePropertyWeeklyRentShouldUpdateRentCorrectly(uint256 TNFTIndex, uint256 rent) public {
    (uint256 storedRent, ) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(storedRent, 0);
    propertyOracle.updatePropertyWeeklyRent(TNFTIndex, rent);
    (storedRent, ) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(rent, storedRent);
  }

  function testUpdateTruePropertyValueShouldUpdateValueCorrectly(uint256 TNFTIndex, uint256 tpv) public {
    (, uint256 storedTpv) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(storedTpv, 0);
    propertyOracle.updateTruePropertyValue(TNFTIndex, tpv);
    (, storedTpv) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(tpv, storedTpv);
  }
}
