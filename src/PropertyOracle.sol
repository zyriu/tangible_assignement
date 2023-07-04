// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

/// @title For the sake of simplicity for this assignment, we simulate an oracle that would feed an adequate
/// True Property Valuation (TPV) and rent based on real estate market prices.
contract PropertyOracle {

  // the admin can feed off chain data to the contract
  address public admin;

  // for the sake of simplicity for this exercise we use a weekly rent
  mapping (uint256 => uint256) public propertyWeeklyRent;
  mapping (uint256 => uint256) public truePropertyValuations;

  modifier onlyAdmin() {
    require(msg.sender == admin);
    _;
  }

  constructor (address admin_) {
    require(admin_ != address(0));
    admin = admin_;
  }

  /// @dev Retrieve property rent and tpv.
  function getPropertyInfo(uint256 TNFTIndex) public view returns (uint256 rent, uint256 tpv) {
    rent = propertyWeeklyRent[TNFTIndex];
    tpv = truePropertyValuations[TNFTIndex];
  }

  /// @dev Called off chain to set initial property rent and value from real world data.
  function setPropertyInfo(uint256 TNFTIndex, uint256 rent, uint256 tpv) external onlyAdmin {
    propertyWeeklyRent[TNFTIndex] = rent;
    truePropertyValuations[TNFTIndex] = tpv;
  }

  /// @dev Called off chain to update the mapping with property rent from real world data.
  function updatePropertyWeeklyRent(uint256 TNFTIndex, uint256 rent) external onlyAdmin {
    propertyWeeklyRent[TNFTIndex] = rent;
  }

  /// @dev Called off chain to update the mapping with property value from real world data.
  function updateTruePropertyValue(uint256 TNFTIndex, uint256 tpv) external onlyAdmin {
    truePropertyValuations[TNFTIndex] = tpv;
  }
}
