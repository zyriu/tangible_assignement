// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IReUSD {
  function updateTotalTPV(uint256 delta, bool sub) external;
}
