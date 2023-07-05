// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../src/PropertyOracle.sol";

contract PropertyOracleTest is Test {

  address public owner;

  PropertyOracle public propertyOracle;

  // polygon state
  string POLYGON_RPC = vm.envString("POLYGON_RPC");
  IERC721 public tangibleREstateTNFT = IERC721(0x29613FbD3e695a669C647597CEFd60bA255cc1F8);
  uint256 private constant TNFT_FIRST_TOKEN_ID = 0x10000000000000000000000000000000a;

  function setUp() public {
    vm.selectFork(vm.createFork(POLYGON_RPC));
    owner = address(this);
    propertyOracle = new PropertyOracle();
    propertyOracle.setTNFTContract(address(tangibleREstateTNFT));
  }

  function testSetPropertyInfoShouldRevertIfNotCalledByOwner(uint256 TNFTIndex, uint256 rent, uint256 tpv) public {
    vm.startPrank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");
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

  function testSetReUSDShouldRevertIfNotCalledByOwner() public {
    vm.prank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");
    propertyOracle.setReUSD(owner);
  }

  function testSetReUSDShouldRevertIfCalledWithNullAddress() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NullAddress()"))));
    propertyOracle.setReUSD(address(0x0));
  }

  function testSetReUSDShouldSetReUSDProperly() public {
    assertEq(address(propertyOracle.reUSD()), address(0x0));
    propertyOracle.setReUSD(address(0x42));
    assertEq(address(propertyOracle.reUSD()), address(0x42));
  }

  function testSetTNFTContractShouldRevertIfNotCalledByOwner() public {
    vm.prank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");
    propertyOracle.setTNFTContract(owner);
  }

  function testSetTNFTContractShouldRevertIfCalledWithNullAddress() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NullAddress()"))));
    propertyOracle.setTNFTContract(address(0x0));
  }

  function testSetTNFTContractShouldSetTNFTContractProperly() public {
    assertEq(address(propertyOracle.tangibleREstateTNFT()), address(tangibleREstateTNFT));
    propertyOracle.setTNFTContract(address(0x42));
    assertEq(address(propertyOracle.tangibleREstateTNFT()), address(0x42));
  }

  function testUpdatePropertyWeeklyRentShouldUpdateRentCorrectly(uint256 TNFTIndex, uint256 rent) public {
    (uint256 storedRent, ) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(storedRent, 0);
    propertyOracle.updatePropertyWeeklyRent(TNFTIndex, rent);
    (storedRent, ) = propertyOracle.getPropertyInfo(TNFTIndex);
    assertEq(rent, storedRent);
  }

  function testUpdateTruePropertyValueShouldUpdateValueCorrectly(uint256 tpv) public {
    (, uint256 storedTpv) = propertyOracle.getPropertyInfo(TNFT_FIRST_TOKEN_ID);
    assertEq(storedTpv, 0);
    propertyOracle.updateTruePropertyValue(TNFT_FIRST_TOKEN_ID, tpv);
    (, storedTpv) = propertyOracle.getPropertyInfo(TNFT_FIRST_TOKEN_ID);
    assertEq(tpv, storedTpv);
  }
}
