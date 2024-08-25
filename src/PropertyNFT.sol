
    
    /* {
  "name": "Property #123",
  "description": "A lovely 2-bedroom apartment in New York.",
  "image": "https://example.com/images/property123.png",
  "attributes": {
    "location": "New York, NY",
    "size": "1000 sq ft",
    "valuation": "$500,000"
  }
}
*/ 



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropertyNFT is ERC721, Ownable {
    uint256 public nextTokenId;
    mapping(uint256 => string) private _tokenURIs;
    IERC20 public usdc;

// Mapping of token ID to user address to their ownership share
mapping(uint256 => mapping(address => uint256)) public ownershipShares;
// Mapping of token ID to the total ownership sold
mapping(uint256 => uint256) public totalOwnershipSold;

event OwnershipPurchased(uint256 indexed tokenId, address indexed buyer, uint256 amount);
event OwnershipTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);

    constructor(address _usdc) ERC721("PropertyToken", "PROP") {
        nextTokenId = 1;
        usdc = IERC20(_usdc);

    }   

    // Function to mint a new property NFT
    function mint(address to, string memory _tokenURI) external onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        nextTokenId++;
        return tokenId;
    }

    // Function to set the token URI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
// Purchase fractional ownership in a property
function purchaseOwnership(uint256 tokenId, uint256 usdcAmount) external {
    require(ownerOf(tokenId) == address(this), "Property not available for sale");

    uint256 ownershipPercentage = (usdcAmount * 10000) / totalAssetValue(tokenId);
    ownershipShares[tokenId][msg.sender] += ownershipPercentage;
    totalOwnershipSold[tokenId] += ownershipPercentage;

    require(totalOwnershipSold[tokenId] <= 10000, "Cannot exceed 100% ownership");

    //> instead of addressthis, send it to some vault, msig. 
    usdc.transferFrom(msg.sender, address(this), usdcAmount);

    emit OwnershipPurchased(tokenId, msg.sender, ownershipPercentage);
}

// Transfer fractional ownership from one user to another
function transferOwnership(uint256 tokenId, address to, uint256 amount) external {
    require(ownershipShares[tokenId][msg.sender] >= amount, "Insufficient ownership");

    ownershipShares[tokenId][msg.sender] -= amount;
    ownershipShares[tokenId][to] += amount;

    emit OwnershipTransferred(tokenId, msg.sender, to, amount);
}

// Return the total value of the asset (placeholder)
function totalAssetValue(uint256 tokenId) public view returns (uint256) {
    // Placeholder for actual value, should be set or calculated
    return 1000000; // Example: $1,000,000
}

// Retrieve the ownership percentage of a specific user for a token
function getOwnershipPercentage(uint256 tokenId, address owner) external view returns (uint256) {
    return ownershipShares[tokenId][owner];
}

// Withdraw USDC funds (e.g., when the asset is sold)
function withdrawFunds() external onlyOwner {
    uint256 balance = usdc.balanceOf(address(this));
    usdc.transfer(owner(), balance);
}

   
}

   