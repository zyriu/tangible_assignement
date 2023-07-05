// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "../src/PropertyOracle.sol";
import "../src/ReUSD.sol";
import "../src/Vault.sol";

contract ReUSDTest is IERC721Receiver, Test {

  address public owner;
  address public userA = address(0x420);
  address public userB = address(0x42069);
  address public userC = address(0x42069420);

  PropertyOracle public propertyOracle;
  ReUSD public reUSD;
  Vault public vault;

  // mock USDC
  ERC20PresetFixedSupply public USDC;

  // polygon state
  string POLYGON_RPC = vm.envString("POLYGON_RPC");
  IERC721 public tangibleREstateTNFT = IERC721(0x29613FbD3e695a669C647597CEFd60bA255cc1F8);
  uint256 private constant TNFT_FIRST_TOKEN_ID = 0x10000000000000000000000000000000a;

  function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

  function setUp() public {
    vm.selectFork(vm.createFork(POLYGON_RPC));
    owner = address(this);

    propertyOracle = new PropertyOracle();
    USDC = new ERC20PresetFixedSupply("Circle USD", "USDC", UINT256_MAX, owner);
    vault = new Vault(address(propertyOracle), owner, address(USDC));
    reUSD = new ReUSD(address(tangibleREstateTNFT), address(propertyOracle), address(USDC), address(vault));
    reUSD.setManager(owner);
    vault.setRentCollector(address(reUSD));
  }

  function testImplementsERC721Receiver() public {
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.prank(tnftHolder);
    tangibleREstateTNFT.safeTransferFrom(tnftHolder, address(reUSD), TNFT_FIRST_TOKEN_ID);
  }

  function testMintShouldMintProperly() public {
    address[3] memory users = [userA, userB, userC];
    for (uint k = 0; k < 3; k++) {
      uint256 tnftId = TNFT_FIRST_TOKEN_ID + k;
      address currentUser = users[k];
      propertyOracle.setPropertyInfo(tnftId, 1_000 * 1e18,  1_000_000 * 1e18);
      vault.initializeRentCollection(tnftId);
      address tnftHolder = tangibleREstateTNFT.ownerOf(tnftId);
      vm.prank(tnftHolder);
      tangibleREstateTNFT.safeTransferFrom(tnftHolder, currentUser, tnftId);
      vm.startPrank(currentUser);
      tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
      reUSD.mint(tnftId);
      vm.stopPrank();
    }
    assertEq(reUSD.totalTPV(), 3_000_000 * 1e18);
    assertEq(reUSD.balanceOf(userA), 1_000_000 * 1e18);
    assertEq(reUSD.balanceOf(userB), 1_000_000 * 1e18);
    assertEq(reUSD.balanceOf(userC), 1_000_000 * 1e18);
  }

  function testPriceShouldComputePriceProperly(uint256 tpv) public {
    vm.assume(tpv >= 10_000 * 1e18 && tpv <= 50_000_000 * 1e18);
    assertEq(reUSD.price(), 0);
    tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID, 1_000 * 1e18, tpv);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID);
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.prank(tnftHolder);
    tangibleREstateTNFT.safeTransferFrom(tnftHolder, owner, TNFT_FIRST_TOKEN_ID);
    reUSD.mint(TNFT_FIRST_TOKEN_ID);
    assertEq(reUSD.price(), 1e18);
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID + 1, 1_000 * 1e18, tpv);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID + 1);
    tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID + 1);
    vm.prank(tnftHolder);
    tangibleREstateTNFT.safeTransferFrom(tnftHolder, owner, TNFT_FIRST_TOKEN_ID + 1);
    reUSD.mint(TNFT_FIRST_TOKEN_ID + 1);
    assertEq(reUSD.price(), 1e18);
  }

  function testPriceShouldComputePriceProperlyWithRent(uint256 tpv) public {
    vm.assume(tpv >= 10_000 * 1e18 && tpv <= 50_000_000 * 1e18);
    assertEq(reUSD.price(), 0);
    tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID, 1_000 * 1e18, tpv);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID);
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.prank(tnftHolder);
    tangibleREstateTNFT.safeTransferFrom(tnftHolder, owner, TNFT_FIRST_TOKEN_ID);
    reUSD.mint(TNFT_FIRST_TOKEN_ID);
    vm.warp(block.timestamp + 7 days);
    assertEq(reUSD.price(), (tpv + 1_000 * 1e18) * 1e18 / reUSD.totalSupply());
  }

  function testRedeemShouldRevertIfAmountIsNull() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidAmount()"))));
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = TNFT_FIRST_TOKEN_ID;
    reUSD.redeem(0, tokenIds);
  }

  function testRedeemShouldRevertIfEmptyTFNTArray() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidAmount()"))));
    uint256[] memory tokenIds = new uint256[](0);
    reUSD.redeem(1, tokenIds);
  }

  function testRedeemShouldRevertIfTotalTPVIsNull() public {
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NothingRedeemable()"))));
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = TNFT_FIRST_TOKEN_ID;
    reUSD.redeem(1, tokenIds);
  }

  function testRedeemShouldRevertIfTotalTPVRedeemedExceedsReUSDBalanceOfCaller() public {
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID, 1000 * 1e18, 1_000_000 * 1e18);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID);
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.startPrank(tnftHolder);
    tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
    reUSD.mint(TNFT_FIRST_TOKEN_ID);
    vm.stopPrank();
    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InsufficientBalance()"))));
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = TNFT_FIRST_TOKEN_ID;
    reUSD.redeem(1, tokenIds);
  }

  function testRedeemShouldRedeemProperly() public {
    address[3] memory users = [userA, userB, userC];
    for (uint k = 0; k < 3; k++) {
      uint256 tnftId = TNFT_FIRST_TOKEN_ID + k;
      address currentUser = users[k];
      propertyOracle.setPropertyInfo(tnftId, 1_000 * 1e18,  1_000_000 * 1e18);
      vault.initializeRentCollection(tnftId);
      address tnftHolder = tangibleREstateTNFT.ownerOf(tnftId);
      vm.prank(tnftHolder);
      tangibleREstateTNFT.safeTransferFrom(tnftHolder, currentUser, tnftId);
      vm.startPrank(currentUser);
      tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
      reUSD.mint(tnftId);
      vm.stopPrank();
    }
    vm.prank(userC);
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = TNFT_FIRST_TOKEN_ID;
    reUSD.redeem(1_000_000 * 1e18, tokenIds);
    assertEq(reUSD.balanceOf(userC), 0);
    assertEq(USDC.balanceOf(userC), 0);
    assertEq(tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID), userC);
  }

  function testRedeemShouldRedeemProperlyWithRent() public {
    address[3] memory users = [userA, userB, userC];
    for (uint k = 0; k < 3; k++) {
      uint256 tnftId = TNFT_FIRST_TOKEN_ID + k;
      address currentUser = users[k];
      propertyOracle.setPropertyInfo(tnftId, 1_000 * 1e18,  1_000_000 * 1e18);
      vault.initializeRentCollection(tnftId);
      address tnftHolder = tangibleREstateTNFT.ownerOf(tnftId);
      vm.prank(tnftHolder);
      tangibleREstateTNFT.safeTransferFrom(tnftHolder, currentUser, tnftId);
      vm.startPrank(currentUser);
      tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
      reUSD.mint(tnftId);
      vm.stopPrank();
    }
    vm.warp(block.timestamp + 7 days);
    USDC.approve(address(vault), UINT256_MAX);
    vault.payRent(TNFT_FIRST_TOKEN_ID, 3_000 * 1e18);
    vm.prank(userC);
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = TNFT_FIRST_TOKEN_ID;
    reUSD.redeem(1_000_000 * 1e18, tokenIds);
    assertEq(reUSD.balanceOf(userC), 0);
    assertEq(USDC.balanceOf(userC), 1_000 * 1e18);
    assertEq(tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID), userC);
  }

  function testSetPropertyOracleShouldRevertIfNotCalledByOwner() public {
    vm.prank(address(0x42));
    vm.expectRevert("Ownable: caller is not the owner");

    reUSD.setPropertyOracle(owner);
  }

  function testSetPropertyOracleShouldSetOracleProperly() public {
    assertFalse(address(reUSD.propertyOracle()) == address(0x42));
    reUSD.setPropertyOracle(address(0x42));
    assertEq(address(reUSD.propertyOracle()), address(0x42));
  }

  function testUpdateTotalTPVShouldRevertIfNotCalledByManager() public {
    vm.prank(address(0x42));
    vm.expectRevert("Unauthorized");
    reUSD.updateTotalTPV(0, false);
  }

  function testUpdateTotalTPVShouldUpdateNegativeDelta() public {
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID, 1_000 * 1e18, 10_000_000 * 1e18);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID);
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.startPrank(tnftHolder);
    tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
    reUSD.mint(TNFT_FIRST_TOKEN_ID);
    vm.stopPrank();
    reUSD.updateTotalTPV(1_000_000 * 1e18, true);
    assertEq(reUSD.totalTPV(), 9_000_000 * 1e18);
  }

  function testUpdateTotalTPVShouldUpdatePositiveDelta() public {
    propertyOracle.setPropertyInfo(TNFT_FIRST_TOKEN_ID, 1_000 * 1e18, 10_000_000 * 1e18);
    vault.initializeRentCollection(TNFT_FIRST_TOKEN_ID);
    address tnftHolder = tangibleREstateTNFT.ownerOf(TNFT_FIRST_TOKEN_ID);
    vm.startPrank(tnftHolder);
    tangibleREstateTNFT.setApprovalForAll(address(reUSD), true);
    reUSD.mint(TNFT_FIRST_TOKEN_ID);
    vm.stopPrank();
    reUSD.updateTotalTPV(1_000_000 * 1e18, false);
    assertEq(reUSD.totalTPV(), 11_000_000 * 1e18);
  }
}
