// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PropertyNFT.sol";

contract AssetListing is Initializable, Ownable {
    struct Asset {
        uint256 assetId;
        address owner;
        uint256 valuation;
        bool isListed;
        bool isSingleBuyer;
        uint256 collateralAmount;
        uint256 listingFee;
        uint256 tokenId;
    }

    mapping(uint256 => Asset) public assets;
    uint256 public nextAssetId;
    uint256 public collateralPercentage; // Example: 5% collateral
    uint256 public listingFeePercentage; // Example: 0.5% listing fee
    PropertyNFT public propertyNFT;
    IERC20 public usdc;

    event AssetRequested(uint256 indexed assetId, address indexed owner, uint256 valuation);
    event AssetListed(uint256 indexed assetId, address indexed owner, uint256 valuation);
    event CollateralReturned(uint256 indexed assetId, address indexed owner);
    event CollateralForfeited(uint256 indexed assetId, address indexed owner);

    function initialize(
        uint256 _collateralPercentage,
        uint256 _listingFeePercentage,
        address _usdc,
        address _propertyNFTAddress
    ) public initializer {
        collateralPercentage = _collateralPercentage;
        listingFeePercentage = _listingFeePercentage;
        usdc = IERC20(_usdc);
        propertyNFT = PropertyNFT(_propertyNFTAddress);
        nextAssetId = 1;
    }

    // Request to list an asset on the platform
    function requestAssetListing(uint256 valuation, bool isSingleBuyer, string memory tokenURI) external {
        uint256 collateral = (valuation * collateralPercentage) / 100;
        uint256 listingFee = (valuation * listingFeePercentage) / 100;

        require(usdc.transferFrom(msg.sender, address(this), collateral + listingFee), "Transfer failed");

        uint256 assetId = nextAssetId++;
        uint256 tokenId = propertyNFT.mint(address(this), tokenURI);

        assets[assetId] = Asset({
            assetId: assetId,
            owner: msg.sender,
            valuation: valuation,
            isListed: false,
            isSingleBuyer: isSingleBuyer,
            collateralAmount: collateral,
            listingFee: listingFee,
            tokenId: tokenId
        });

        emit AssetRequested(assetId, msg.sender, valuation);
    }

    // Approve and list the asset for sale
    function listAsset(uint256 assetId) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(!asset.isListed, "Asset already listed");

        if (asset.isSingleBuyer) {
            // Logic for single buyer scenario
        } else {
            // Logic for fractional ownership scenario
            // Typically, this would involve creating and selling shares or fractions
        }

        asset.isListed = true;

        emit AssetListed(assetId, asset.owner, asset.valuation);
    }

    // Return collateral after successful asset sale or full subscription
    function returnCollateral(uint256 assetId) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset not listed");
        require(asset.isSingleBuyer, "Asset not fully subscribed or sold");

        uint256 collateralAmount = asset.collateralAmount;
        asset.collateralAmount = 0;

        usdc.transfer(asset.owner, collateralAmount);

        emit CollateralReturned(assetId, asset.owner);
    }

    // Forfeit collateral under certain conditions (e.g., listing violation or fraudulent behavior)
    function forfeitCollateral(uint256 assetId) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(asset.collateralAmount > 0, "No collateral to forfeit");

        uint256 collateralAmount = asset.collateralAmount;
        asset.collateralAmount = 0;

        usdc.transfer(owner(), collateralAmount);

        emit CollateralForfeited(assetId, asset.owner);
    }
}
