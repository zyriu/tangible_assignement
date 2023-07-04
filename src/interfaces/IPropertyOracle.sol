// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IPropertyOracle {
  function getPropertyInfo(uint256 TNFTIndex) external view returns (uint256, uint256);
}
