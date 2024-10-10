// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./AssetListing.sol";

contract Governance is Initializable, Ownable {
    AssetListing public assetListing;
    uint256 public proposalCount;
    uint256 public quorumPercentage;
    uint256 public approvalThreshold;

    struct Proposal {
        uint256 id;
        uint256 assetId;
        uint256 salePrice;  //proposed sale price
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotes;
        uint256 createdAt;
        bool executed;
        bool passed;
        ProposalType proposalType;
    }

    enum ProposalType {
        SellAsset,
        DistributeFunds
        // Add more proposal types as needed
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, uint256 indexed assetId, address proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);

    function initialize(address _assetListing, uint256 _quorumPercentage, uint256 _approvalThreshold) public initializer {
        assetListing = AssetListing(_assetListing);
        quorumPercentage = _quorumPercentage;
        approvalThreshold = _approvalThreshold;
    }

    function createProposal(uint256 assetId, string memory description,uint256 salePrice, ProposalType proposalType) external {
        //  require(assetListing.assets[assetId].isListed, "Asset not listed");
         (,,, bool isListed,,,,,) = assetListing.assets(assetId);
         require(isListed, "Asset not listed");


        require(assetListing.ownershipShares(assetId, msg.sender) > 0, "Only owners can create proposals");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            assetId: assetId,
            salePrice: salePrice,
            proposer: msg.sender,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            totalVotes: 0,
            createdAt: block.timestamp,
            executed: false,
            passed: false,
            proposalType: proposalType
        });

        emit ProposalCreated(proposalCount, assetId, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterShares = assetListing.ownershipShares(proposal.assetId, msg.sender);
        require(voterShares > 0, "Only owners can vote");

        hasVoted[proposalId][msg.sender] = true;
        proposal.totalVotes += voterShares;

        if (support) {
            proposal.votesFor += voterShares;
        } else {
            proposal.votesAgainst += voterShares;
        }

        emit Voted(proposalId, msg.sender, support, voterShares);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        (,,uint256 valuation,,,,,,) = assetListing.assets(proposal.assetId);

        uint256 totalShares = valuation;
        uint256 quorum = (totalShares * quorumPercentage) / 100;
        uint256 approval = (proposal.votesFor * 100) / proposal.totalVotes;

        require(proposal.totalVotes >= quorum, "Quorum not reached");
        require(approval >= approvalThreshold, "Approval threshold not met");

        proposal.executed = true;
        proposal.passed = true;

        // Execute the action based on the proposal type
        executeProposalAction(proposal.assetId,proposalId, proposal.proposalType);

        emit ProposalExecuted(proposalId, true);
    }

    function executeProposalAction(uint256 assetId,uint256 proposalId, ProposalType proposalType) internal {
        Proposal storage proposal = proposals[proposalId];

        if (proposalType == ProposalType.SellAsset) {
            // Logic to sell the asset through the AssetListing contract
            assetListing.sellAsset(assetId,proposal.salePrice);
        } else if (proposalType == ProposalType.DistributeFunds) {
            // Logic to distribute funds to fractional owners
            assetListing.distributeFunds(assetId,proposal.salePrice);
        }
        // Add more cases as needed
    }
}
