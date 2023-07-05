// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IVault {
  function accruedRent() external view returns (uint256);
  function claimRent() external;
}
