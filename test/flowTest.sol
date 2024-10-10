// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PropertyNFT.sol";
import "../src/AssetListing.sol";
import "../src/Marketplace.sol";
import "../src/Governance.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FullWorkflowTest is Test {
    PropertyNFT nft;
    AssetListing assetListing;
    Marketplace marketplace;
    Governance governance;
    IERC20 usdc;

    address owner;
    address user1;
    address user2;
    address user3;
    address user4;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        user4 = address(0x4);

        nft = new PropertyNFT();
        usdc = IERC20(address(this)); // Mock IERC20
        assetListing = new AssetListing();
        marketplace = new Marketplace(address(assetListing), address(usdc));
        governance = new Governance();

        // Initialize contracts
        assetListing.initialize(5, 0.5, address(usdc), address(nft), owner);
        governance.initialize(address(assetListing), 20, 50); // 20% quorum, 50% approval threshold

        // Mint an NFT to the owner
        nft.mint(owner, "ipfs://tokenURI");
    }

    function testFullWorkflow() public {
        // Step 1: Owner requests and lists the asset
        assetListing.requestAssetListing(1000, false); // Allow fractional ownership
        assetListing.listAsset(1, "ipfs://tokenURI");

        // Assert the asset is listed
        (,,, bool isListed,,,,,) = assetListing.assets(1);
        assertTrue(isListed);

        // Step 2: Users 1, 2, and 3 purchase fractional ownership
        assetListing.purchaseFractionalOwnership(1, 300); // User1 buys 30%
        vm.prank(user1);
        assetListing.purchaseFractionalOwnership(1, 300); // User2 buys 30%
        vm.prank(user2);
        assetListing.purchaseFractionalOwnership(1, 400); // User3 buys 40%
        vm.prank(user3);

        // Assert that the asset is fully subscribed
        (, , , , , , , , uint256 totalOwnershipSold) = assetListing.assets(1);
        assertEq(totalOwnershipSold, 10000);

        // Step 3: User3 creates a governance proposal to sell the asset
        vm.prank(user3);
        governance.createProposal(1, "Sell the asset", 1500, Governance.ProposalType.SellAsset);

        // Step 4: Users vote on the proposal
        governance.vote(1, true); // Owner votes for
        vm.prank(user1);
        governance.vote(1, true); // User1 votes for
        vm.prank(user2);
        governance.vote(1, false); // User2 votes against

        // Attempt to vote with a user that doesn't own shares
        vm.prank(user4);
        try governance.vote(1, true) {
            fail("User without ownership should not be able to vote");
        } catch {}

        // Step 5: Execute the proposal
        governance.executeProposal(1);

        // Assert that the asset is no longer listed (indicating it was sold)
        (, , , bool assetIsListed, , , , , ) = assetListing.assets(1);
        assertTrue(!assetIsListed);
    }
}
