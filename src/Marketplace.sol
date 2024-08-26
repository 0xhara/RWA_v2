// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AssetListing.sol";

contract Marketplace is Ownable {
    AssetListing public assetListing;
    IERC20 public usdc;

    struct Listing {
        uint256 assetId;
        address seller;
        uint256 shareAmount;
        uint256 price;
        bool isAuction;
        bool isSold;
    }

    struct AuctionBid {
        address bidder;
        uint256 bidAmount;
    }

    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => AuctionBid[]) public auctionBids;

    event ListingCreated(uint256 indexed listingId, uint256 assetId, address seller, uint256 shareAmount, uint256 price, bool isAuction);
    event BidPlaced(uint256 indexed listingId, address indexed bidder, uint256 bidAmount);
    event ListingSold(uint256 indexed listingId, address buyer, uint256 salePrice);

    constructor(address _assetListing, address _usdc) {
        assetListing = AssetListing(_assetListing);
        usdc = IERC20(_usdc);
    }

    // Create a listing for reselling shares
    function createListing(uint256 assetId, uint256 shareAmount, uint256 price, bool isAuction) external {
        require(assetListing.ownershipShares(assetId, msg.sender) >= shareAmount, "Insufficient ownership");

        listings[nextListingId] = Listing({
            assetId: assetId,
            seller: msg.sender,
            shareAmount: shareAmount,
            price: price,
            isAuction: isAuction,
            isSold: false
        });

        emit ListingCreated(nextListingId, assetId, msg.sender, shareAmount, price, isAuction);
        nextListingId++;
    }

    // Buy shares from a listing (for fixed price listings)
    function buyListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(!listing.isAuction, "Listing is for auction");
        require(!listing.isSold, "Listing already sold");

        require(usdc.transferFrom(msg.sender, listing.seller, listing.price), "Payment failed");
        assetListing.transferOwnership(listing.assetId, listing.seller, msg.sender, listing.shareAmount);

        listing.isSold = true;

        emit ListingSold(listingId, msg.sender, listing.price);
    }

    // Place a bid on an auction listing
    function placeBid(uint256 listingId, uint256 bidAmount) external {
        Listing storage listing = listings[listingId];
        require(listing.isAuction, "Listing is not for auction");
        require(!listing.isSold, "Listing already sold");

        auctionBids[listingId].push(AuctionBid({
            bidder: msg.sender,
            bidAmount: bidAmount
        }));

        emit BidPlaced(listingId, msg.sender, bidAmount);
    }

    // Seller accepts the highest bid in an auction
    function acceptHighestBid(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.isAuction, "Listing is not for auction");
        require(msg.sender == listing.seller, "Only seller can accept bids");
        require(!listing.isSold, "Listing already sold");

        uint256 highestBidAmount = 0;
        address highestBidder;

        for (uint256 i = 0; i < auctionBids[listingId].length; i++) {
            if (auctionBids[listingId][i].bidAmount > highestBidAmount) {
                highestBidAmount = auctionBids[listingId][i].bidAmount;
                highestBidder = auctionBids[listingId][i].bidder;
            }
        }

        require(highestBidAmount > 0, "No bids placed");

        require(usdc.transferFrom(highestBidder, listing.seller, highestBidAmount), "Payment failed");
        assetListing.transferOwnership(listing.assetId, listing.seller, highestBidder, listing.shareAmount);

        listing.isSold = true;

        emit ListingSold(listingId, highestBidder, highestBidAmount);
    }
}
