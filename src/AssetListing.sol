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
        uint256 totalOwnershipSold;
    }

    mapping(uint256 => Asset) public assets;
    mapping(uint256 => mapping(address => uint256)) public ownershipShares; // Maps asset ID to owner shares
    uint256 public nextAssetId;
    uint256 public collateralPercentage; // Example: 5% collateral
    uint256 public listingFeePercentage; // Example: 0.5% listing fee
    PropertyNFT public propertyNFT;
    IERC20 public usdc;
    address public governanceContractAddress;
    address public SPVAddress;

    event AssetListed(uint256 indexed assetId, address indexed owner, uint256 valuation, uint256 tokenId);
    event OwnershipPurchased(uint256 indexed assetId, address indexed buyer, uint256 ownershipPercentage);
    event CollateralReturned(uint256 indexed assetId, address indexed owner);
    event AssetSold(uint256 indexed assetId, uint256 salePrice);
    event FundsDistributed(uint256 indexed assetId, uint256 totalAmountDistributed);
    event OwnershipTransferred(uint256 indexed assetId, address from, address to, uint256 shareAmount);

    function initialize(
        uint256 _collateralPercentage,
        uint256 _listingFeePercentage,
        address _usdc,
        address _propertyNFTAddress,
        address _governanceContractAddress,
        address _SPVAddress
    ) public initializer {
        collateralPercentage = _collateralPercentage;
        listingFeePercentage = _listingFeePercentage;
        usdc = IERC20(_usdc);
        propertyNFT = PropertyNFT(_propertyNFTAddress);
        governanceContractAddress = _governanceContractAddress;
        SPVAddress = _SPVAddress;
        nextAssetId = 1;
    }

    modifier onlyGovernance() {
        require(msg.sender == governanceContractAddress, "Only Governance contract can call this function");
        _;
    }

    // Function to sell the asset
    function sellAsset(uint256 assetId) external onlyGovernance {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset is not listed for sale");
        require(asset.totalOwnershipSold == 10000, "Asset is not fully subscribed");

        uint256 salePrice = asset.valuation;

        // Ensure the asset owner deposits USDC equivalent to the sale price
        require(usdc.transferFrom(asset.owner, address(this), salePrice), "USDC deposit failed");

        distributeFunds(assetId, salePrice);

        emit AssetSold(assetId, salePrice);

        asset.isListed = false;
    }

    // Function to distribute funds to fractional owners
    function distributeFunds(uint256 assetId, uint256 totalAmount) public onlyGovernance {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset is not listed for sale");

        for (uint256 i = 0; i < nextAssetId; i++) {
            address owner = asset.owner;
            uint256 ownershipPercentage = ownershipShares[assetId][owner];
            uint256 amountToDistribute = (totalAmount * ownershipPercentage) / 10000;
            
            usdc.transfer(owner, amountToDistribute);
        }

        emit FundsDistributed(assetId, totalAmount);
    }

    // Request to list an asset on the platform
    function requestAssetListing(uint256 valuation, bool isSingleBuyer) external {
        uint256 collateral = (valuation * collateralPercentage) / 100;
        uint256 listingFee = (valuation * listingFeePercentage) / 100;

        require(usdc.transferFrom(msg.sender, address(this), collateral + listingFee), "Transfer failed");

        uint256 assetId = nextAssetId++;

        assets[assetId] = Asset({
            assetId: assetId,
            owner: msg.sender,
            valuation: valuation,
            isListed: false,
            isSingleBuyer: isSingleBuyer,
            collateralAmount: collateral,
            listingFee: listingFee,
            tokenId: 0,
            totalOwnershipSold: 0
        });

        emit AssetListed(assetId, msg.sender, valuation, 0);
    }

    // Approve and list the asset for sale, minting the NFT
    function listAsset(uint256 assetId, string memory tokenURI) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(!asset.isListed, "Asset already listed");

        uint256 tokenId = propertyNFT.mint(address(this), tokenURI);
        asset.tokenId = tokenId;

        asset.isListed = true;

        emit AssetListed(assetId, asset.owner, asset.valuation, tokenId);
    }

    // Purchase the entire asset for single buyer scenario
    function purchaseEntireAsset(uint256 assetId) external {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset is not listed for sale");
        require(asset.totalOwnershipSold == 0, "Partial ownership already sold");
        require(usdc.balanceOf(msg.sender) >= asset.valuation, "Insufficient USDC to buy the entire asset");

        usdc.transferFrom(msg.sender, address(this), asset.valuation);
        propertyNFT.safeTransferFrom(address(this), msg.sender, asset.tokenId);

        usdc.transfer(asset.owner, asset.collateralAmount);

        emit CollateralReturned(assetId, asset.owner);
    }

    // Purchase fractional ownership in the asset
    function purchaseFractionalOwnership(uint256 assetId, uint256 usdcAmount) external {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset is not listed for sale");
        require(!asset.isSingleBuyer, "Asset is available only for a single buyer");
        require(usdcAmount > 0, "Purchase amount must be greater than zero");

        uint256 ownershipPercentage = (usdcAmount * 10000) / asset.valuation;
        require(ownershipPercentage > 0, "USDC amount too small for fractional ownership");
        require(asset.totalOwnershipSold + ownershipPercentage <= 10000, "Cannot exceed 100% ownership");

        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        ownershipShares[assetId][msg.sender] += ownershipPercentage;
        asset.totalOwnershipSold += ownershipPercentage;

        emit OwnershipPurchased(assetId, msg.sender, ownershipPercentage);
    }

    // Finalize fractional ownership when fully subscribed
    function finalizeFractionalOwnership(uint256 assetId) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(asset.isListed, "Asset is not listed for sale");
        require(!asset.isSingleBuyer, "Asset is available only for a single buyer");
        require(asset.totalOwnershipSold >= 10000, "Asset is not fully subscribed");

        propertyNFT.safeTransferFrom(address(this), SPVAddress, asset.tokenId);

        usdc.transfer(asset.owner, asset.collateralAmount);

        emit CollateralReturned(assetId, asset.owner);
    }

    // Forfeit collateral under specific conditions (e.g., listing violation or fraudulent behavior)
    function forfeitCollateral(uint256 assetId) external onlyOwner {
        Asset storage asset = assets[assetId];
        require(asset.collateralAmount > 0, "No collateral to forfeit");

        asset.collateralAmount = 0;
    }

    // Function to transfer fractional ownership
    function transferOwnership(uint256 assetId, address from, address to, uint256 shareAmount) external onlyGovernance {
        require(ownershipShares[assetId][from] >= shareAmount, "Insufficient shares to transfer");

        ownershipShares[assetId][from] -= shareAmount;
        ownershipShares[assetId][to] += shareAmount;

        emit OwnershipTransferred(assetId, from, to, shareAmount);
    }
}
