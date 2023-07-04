// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPropertyOracle.sol";
import "./interfaces/ITangibleNFT.sol";
import "./interfaces/IVault.sol";

/// @title For the sake of simplicity for this assignment, we simulate a vault that would receive weekly or monthly rent
/// payments. Instead of claiming rent on a daily basis, the vault accumulate rewards and can be claimed pro rata
/// whenever convenient. This contract isn't production readt as it doesn't account for a change in the rental amount,
/// nor performs safety checks on who claims the rent, etc.
contract Vault is IVault, Ownable {

  uint256 public totalWeeklyRental;

  // keep track of which rental has available credit
  mapping(uint256 => uint256) public propertyAvailableCredit;

  // balance that has yet to be claimed but has been accrued previous to the latest claim timestamp
  uint256 public outstandingBalance;
  uint256 public latestClaimTimestamp;

  address public rentCollector;
  IPropertyOracle public propertyOracle;
  IERC20 public USDC;

  error InsufficientUSDCBalance();
  error InvalidProperty();
  error InvalidRentPayment();
  error NothingToClaim();
  error NullAddress();
  error PropertyUninitialized();

  constructor(address propertyOracle_, address rentCollector_, address USDC_) {
    propertyOracle = IPropertyOracle(propertyOracle_);
    rentCollector = rentCollector_;
    USDC = IERC20(USDC_);
  }

  modifier onlyRentCollector() {
    require(msg.sender == rentCollector, "Unauthorized");
    _;
  }

  function accruedRent() public view override returns (uint256 balance) {
    balance = (block.timestamp - latestClaimTimestamp) * totalWeeklyRental / 7 days;
    balance += outstandingBalance;
  }

  /// @dev allows third parties to collect rent. In a production environment, this would have proper access control for
  /// either a landlord, protocols, etc.
  function claimRent() external onlyRentCollector {
    uint256 amountToClaim = accruedRent();
    if (amountToClaim == 0) revert NothingToClaim();
    if (amountToClaim > USDC.balanceOf(address(this))) revert InsufficientUSDCBalance();

    latestClaimTimestamp = block.timestamp;
    outstandingBalance = 0;

    USDC.transfer(msg.sender, amountToClaim);
  }

  /// @dev initialize rent collection by setting current timestamp and crediting outstanding balance
  function initializeRentCollection(uint256 TNFTId) external onlyOwner {
    (uint256 weeklyRent, ) = propertyOracle.getPropertyInfo(TNFTId);
    if (weeklyRent == 0) revert InvalidProperty();

    // we compute the current outstanding balance prior to adding the new property to the rental pool
    outstandingBalance = accruedRent();
    latestClaimTimestamp = block.timestamp;

    totalWeeklyRental += weeklyRent;
  }

  /// @dev allows third party to pay rent for a property
  function payRent(uint256 TNFTId, uint256 amount) external {
    if (amount == 0) revert InvalidRentPayment();

    USDC.transferFrom(msg.sender, address(this), amount);
    propertyAvailableCredit[TNFTId] += amount;
  }

  /// @dev set the property oracle
  function setPropertyOracle(address propertyOracle_) external onlyOwner {
    if (propertyOracle_ == address(0)) revert NullAddress();

    propertyOracle = IPropertyOracle(propertyOracle_);
  }
}
