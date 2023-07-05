// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IReUSD.sol";
import "./interfaces/ITangibleNFT.sol";

/// @title For the sake of simplicity for this assignment, we simulate an oracle that would feed an adequate
/// True Property Valuation (TPV) and rent based on real estate market prices. In production, this would be an
/// intermediate contract that would submit a query to an oracle, and relay the price to the ReUSD contract.
contract PropertyOracle is Ownable {

  IReUSD public reUSD;
  ITangibleNFT public tangibleREstateTNFT;

  // for the sake of simplicity for this exercise we use a weekly rent
  mapping (uint256 => uint256) public propertyWeeklyRent;
  mapping (uint256 => uint256) public truePropertyValuations;

  error NullAddress();

  /// @dev Retrieve property rent and tpv.
  function getPropertyInfo(uint256 TNFTIndex) public view returns (uint256 rent, uint256 tpv) {
    rent = propertyWeeklyRent[TNFTIndex];
    tpv = truePropertyValuations[TNFTIndex];
  }

  /// @dev Called off chain to set initial property rent and value from real world data.
  function setPropertyInfo(uint256 TNFTIndex, uint256 rent, uint256 tpv) external onlyOwner {
    propertyWeeklyRent[TNFTIndex] = rent;
    truePropertyValuations[TNFTIndex] = tpv;
  }

  /// @dev set the real estate USD contract
  function setReUSD(address reUSD_) external onlyOwner {
    if (reUSD_ == address(0)) revert NullAddress();

    reUSD = IReUSD(reUSD_);
  }

  /// @dev set the tangible real estate NFT contract
  function setTNFTContract(address tangibleREstateTNFT_) external onlyOwner {
    if (tangibleREstateTNFT_ == address(0)) revert NullAddress();

    tangibleREstateTNFT = ITangibleNFT(tangibleREstateTNFT_);
  }

  /// @dev Called off chain to update the mapping with property rent from real world data.
  function updatePropertyWeeklyRent(uint256 TNFTIndex, uint256 rent) external onlyOwner {
    propertyWeeklyRent[TNFTIndex] = rent;
  }

  /// @dev Called off chain to update the mapping with property value from real world data, as well as the basket price
  /// if the TFNT is in the basket.
  function updateTruePropertyValue(uint256 TNFTIndex, uint256 tpv) external onlyOwner {
    uint256 currentTpv = truePropertyValuations[TNFTIndex];
    truePropertyValuations[TNFTIndex] = tpv;
    if (tangibleREstateTNFT.ownerOf(TNFTIndex) == address(reUSD)) {
      if (currentTpv > tpv) {
        reUSD.updateTotalTPV(currentTpv - tpv, false);
      } else {
        reUSD.updateTotalTPV(tpv - currentTpv, true);
      }
    }
  }
}
