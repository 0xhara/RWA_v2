// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PropertyNFT.sol";

contract FractionalOwnership is ERC20, Ownable {
    PropertyNFT public propertyTokenContract;

    // Mapping from property ID to the total fractional tokens issued
    mapping(uint256 => uint256) public totalFractionsIssued;

    // Constructor to set the token name, symbol, and property token contract
    constructor(address _propertyTokenContract) ERC20("FractionalPropertyToken", "FPT") {
        propertyTokenContract = PropertyNFT(_propertyTokenContract);
    }

    // Function to issue fractional tokens for a specific property
    function issueFractionalTokens(uint256 propertyId, uint256 amount) public onlyOwner {
        require(propertyTokenContract.ownerOf(propertyId) == msg.sender, "Caller is not the property owner");
        require(totalFractionsIssued[propertyId] == 0, "Fractional tokens already issued for this property");

        _mint(msg.sender, amount);
        totalFractionsIssued[propertyId] = amount;
    }

    // Function to allow buying fractional tokens (could be expanded to include pricing, etc.)
    function buyFractionalTokens(uint256 propertyId, uint256 amount) public payable {
        require(totalFractionsIssued[propertyId] > 0, "No fractional tokens issued for this property");

        // Implement logic to handle the payment and transfer of tokens
        _transfer(owner(), msg.sender, amount);
    }

    // Function to sell fractional tokens back
    function sellFractionalTokens(uint256 propertyId, uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to sell");

        // Implement logic to handle the return of tokens and payment
        _transfer(msg.sender, owner(), amount);
    }

    // Function to distribute income (like rent) to fractional token holders
    function distributeIncome(uint256 propertyId, uint256 totalIncome) public onlyOwner {
        require(totalFractionsIssued[propertyId] > 0, "No fractional tokens issued for this property");

        uint256 incomePerToken = totalIncome / totalFractionsIssued[propertyId];

        for (uint256 i = 0; i < totalSupply(); i++) {
            address tokenHolder = address(uint160(i));
            uint256 holderBalance = balanceOf(tokenHolder);
            if (holderBalance > 0) {
                payable(tokenHolder).transfer(holderBalance * incomePerToken);
            }
        }
    }
}
