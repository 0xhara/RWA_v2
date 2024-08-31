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
        uint256 minPrice; // Minimum acceptable price
        uint256 highestBid;
        address highestBidder;
        uint256 deadline; // Auction deadline
        bool isSold;
    }

    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;

    event ListingCreated(uint256 indexed listingId, uint256 assetId, address seller, uint256 shareAmount, uint256 minPrice, uint256 deadline);
    event NewBid(uint256 indexed listingId, address bidder, uint256 bidAmount);
    event ListingSold(uint256 indexed listingId, address buyer, uint256 salePrice);

    constructor(address _assetListing, address _usdc) {
        assetListing = AssetListing(_assetListing);
        usdc = IERC20(_usdc);
    }

    // Create a listing for reselling shares with a minimum price and a deadline
    function createListing(uint256 assetId, uint256 shareAmount, uint256 minPrice, uint256 duration) external {
        require(assetListing.ownershipShares(assetId, msg.sender) >= shareAmount, "Insufficient ownership");

        uint256 deadline = block.timestamp + duration;

        listings[nextListingId] = Listing({
            assetId: assetId,
            seller: msg.sender,
            shareAmount: shareAmount,
            minPrice: minPrice,
            highestBid: 0,
            highestBidder: address(0),
            deadline: deadline,
            isSold: false
        });

        emit ListingCreated(nextListingId, assetId, msg.sender, shareAmount, minPrice, deadline);
        nextListingId++;
    }

    // Function to bid on a listing
    function placeBid(uint256 listingId, uint256 bidAmount) external {
        Listing storage listing = listings[listingId];
        require(block.timestamp < listing.deadline, "Auction ended");
        require(bidAmount >= listing.minPrice, "Bid is below minimum price");
        // require(bidAmount > listing.highestBid || (bidAmount == listing.highestBid && msg.sender == listing.highestBidder), "There is a higher or equal bid already");

        // If the bid amount is equal to the current highest bid, the earliest bid wins (FCFS)
        if (bidAmount > listing.highestBid || (bidAmount == listing.highestBid && listing.highestBidder == address(0))) {
            listing.highestBid = bidAmount;
            listing.highestBidder = msg.sender;

            emit NewBid(listingId, msg.sender, bidAmount);
        } else {
            revert("Bid amount is not higher than the current highest bid");
        }
    }

    // Function to finalize the sale after the auction deadline
    function finalizeSale(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(block.timestamp >= listing.deadline, "Auction is still ongoing");
        require(!listing.isSold, "Listing already sold");

        if (listing.highestBidder != address(0)) {
            // Transfer the shares
            assetListing.transferOwnership(listing.assetId, listing.seller, listing.highestBidder, listing.shareAmount);

            // Mark as sold and transfer funds to the seller
            listing.isSold = true;
            usdc.transferFrom(listing.highestBidder, listing.seller, listing.highestBid);

            emit ListingSold(listingId, listing.highestBidder, listing.highestBid);
        } else {
            revert("No bids were placed");
        }
    }
}
