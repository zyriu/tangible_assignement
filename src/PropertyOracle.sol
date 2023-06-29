// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

/// @title PropertyOracle simulates, for the sake of this assignment, an oracle that would feed an adequate
/// True Property Valuation (TPV) based on real estate market prices.
contract PropertyOracle {

  uint256 public constant DECIMALS = 9; // 9 decimals just like USDR

  mapping (uint256 => uint256) public truePropertyValuations;

  /// @dev Compute some random value between $100k - $10M and stores it in a mapping to keep the price constant after
  /// the initial call. A real production implementation would generate and update the mapping based on real world data.
  function getTruePropertyValuation(uint256 TNFTIndex) external returns (uint256 tpv) {
    tpv = truePropertyValuations[TNFTIndex];

    if (tpv == 0) {
      uint256 randomNumber = uint256(
        keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase, block.number))
      );
      uint256 min = 100000;
      uint256 max = 10000000;
      tpv = ((randomNumber % (max - min)) + min) * 10 ** DECIMALS;
      truePropertyValuations[TNFTIndex] = tpv;
    }
  }
}
