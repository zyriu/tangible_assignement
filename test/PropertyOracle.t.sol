// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../src/PropertyOracle.sol";

contract PropertyOracleTest is Test {

  PropertyOracle public propertyOracle;

  function setUp() public {
    propertyOracle = new PropertyOracle();
    assertEq(propertyOracle.DECIMALS(), 9);
  }

  function testGetTruePropertyValuationShouldGenerateInRange(uint256 TNFTIndex) public {
    uint256 price = propertyOracle.getTruePropertyValuation(TNFTIndex);
    assertGe(price, 100_000 * 10e9);
    assertLe(price, 10_000_000 * 10e9);
  }

  function testGetTruePropertyValuationShouldNotRegeneratePrice(uint256 TNFTIndex) public {
    uint256 initialPrice = propertyOracle.getTruePropertyValuation(TNFTIndex);
    uint256 price = propertyOracle.getTruePropertyValuation(TNFTIndex);
    assertEq(initialPrice, price);
  }
}
