// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IPropertyOracle.sol";
import "./interfaces/IReUSD.sol";
import "./interfaces/ITangibleNFT.sol";
import "./interfaces/IVault.sol";

/// @title An ERC20 that represents a basket of TangibleNFTProperties.
contract ReUSD is ERC20, IERC721Receiver, IReUSD, Ownable {

    address public manager;

    IERC20 public USDC;
    ITangibleNFT public immutable tangibleREstateTNFT;
    IPropertyOracle public propertyOracle;
    IVault public vault;

    // the total value of the basket properties
    uint256 public totalTPV;

    error InvalidAmount();
    error InsufficientBalance();
    error NullAddress();
    error NothingRedeemable();

    constructor(
        address tangibleREstateTNFT_,
        address propertyOracle_,
        address USDC_,
        address vault_
    ) ERC20("Tangible Real estate USD", "ReUSD") {
        tangibleREstateTNFT = ITangibleNFT(tangibleREstateTNFT_);
        propertyOracle = IPropertyOracle(propertyOracle_);
        USDC = IERC20(USDC_);
        vault = IVault(vault_);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Unauthorized");
        _;
    }

    /// @dev using a tangible real estate NFT, mint the equivalent real estate value in ReUSD tokens. For the sake of
    /// simplicity, we design the vault contract in this exercise such as only basket held properties are subject to
    /// rent payment, thus there is no need to perform an initial rental income claim or computation for the property
    /// used in the mint.
    function mint(uint256 TNFTId) external {
        tangibleREstateTNFT.safeTransferFrom(msg.sender, address(this), TNFTId, "");

        // get tpv from oracle and compute mintable amount based on current basket value
        (, uint256 tpv) = propertyOracle.getPropertyInfo(TNFTId);
        uint256 mintableAmount = tpv;
        uint256 currentTokenPrice = price();
        if (currentTokenPrice > 0) {
            mintableAmount = mintableAmount * 1e18 / currentTokenPrice;
        }

        totalTPV += tpv;

        _mint(msg.sender, mintableAmount);
    }

    /// @dev returns the current token price, adding up the properties total value and the current accrued rent. If the
    /// basket is empty, returns 0. With decimals, $1 equals 1e18.
    function price() public view returns (uint256 currentPrice) {
        uint256 supply = totalSupply();
        if (supply > 0) {
            currentPrice = (totalTPV + vault.accruedRent() + USDC.balanceOf(address(this))) * 1e18 / supply;
        }
    }

    /// @dev burn amount of ReUSD to claim tangible real estate NFTs. At least one NFT must be claimed. If the amount
    /// doesn't match the current properties' value, top up with rental income. There is no check about which rental
    /// income belongs to which property, these checks need to be implemented on the vault contract
    function redeem(uint256 amount, uint256[] calldata TNFTId) external {
        if (amount == 0) revert InvalidAmount();
        if (TNFTId.length == 0) revert InvalidAmount();

        uint256 currentTokenPrice = price();
        if (currentTokenPrice == 0) revert NothingRedeemable();

        // compute total tpv of assets redeemed and adjust basket total tpv
        uint256 totalTPVRedeemed;
        for (uint256 k = 0; k < TNFTId.length; k++) {
            (, uint256 tpv) = propertyOracle.getPropertyInfo(TNFTId[k]);
            totalTPVRedeemed += tpv;
        }
        totalTPV -= totalTPVRedeemed;

        uint256 amountToBurn = totalTPVRedeemed / currentTokenPrice;
        if (amountToBurn > amount) revert InsufficientBalance();

        // if amount exceeds total tpv of redeemed TFNTs and available USDC, claim rent and top up with it
        uint256 usdcAmount = amount * currentTokenPrice / 1e18 - totalTPVRedeemed;
        if (usdcAmount > USDC.balanceOf(address(this))) {
            vault.claimRent();
        }

        _burn(msg.sender, amount);
        USDC.transfer(msg.sender, usdcAmount);
        for (uint256 k = 0; k < TNFTId.length; k++) {
            tangibleREstateTNFT.safeTransferFrom(address(this), msg.sender, TNFTId[k]);
        }
    }

    /// @dev set the manager, will perform TPV update. In this exercise, we use the oracle directly, but in production
    /// something like an intermediate contract could be used, by integrating a service like Gelato for instance
    function setManager(address manager_) external onlyOwner {
        if (manager_ == address(0)) revert NullAddress();

        manager = manager_;
    }

    /// @dev set the property oracle
    function setPropertyOracle(address propertyOracle_) external onlyOwner {
        if (propertyOracle_ == address(0)) revert NullAddress();

        propertyOracle = IPropertyOracle(propertyOracle_);
    }

    /// @dev set the total TPV to keep the basket value accurate. This is the role of the oracle or an intermediate
    /// contract that would be executed every time a request is submitted to the oracle
    function updateTotalTPV(uint256 delta, bool sub) external override onlyManager {
        if (sub) {
            totalTPV -= delta;
        } else {
            totalTPV += delta;
        }
    }

    /// @dev comply with IERC721Receiver safeTransferFrom
    function onERC721Received(
        address, /*operator*/
        address, /*seller*/
        uint256, /*tokenId*/
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
