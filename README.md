# Real-World Asset (RWA) Marketplace

This project demonstrates a blockchain-based platform for tokenizing real-world assets (RWAs), enabling fractional ownership, governance, and marketplace functionalities. Designed for Ethereum-compatible chains, the platform provides transparency, security, and decentralization to manage RWAs efficiently.

## Features and Components


#### File Structure

```plaintext
├── src/contracts
│   ├── AssetListing.sol      // Core contract for asset management and listing
│   ├── Governance.sol        // Governance system for proposals and voting
│   ├── Marketplace.sol       // Marketplace for bidding and direct asset sales
│   ├── PropertyNFT.sol       // ERC-721 implementation for asset tokenization
└── test
│   ├── AssetListing.t.sol    // Tests for AssetListing contract
│   ├── Governance.t.sol      // Tests for Governance contract
│   ├── Marketplace.t.sol     // Tests for Marketplace contract
│   └── PropertyNFT.t.sol     // Tests for PropertyNFT contract
├── README.md                 // Project documentation (this file)
├── foundry.toml              // Foundry configuration file
└── scripts
    └── deploy.s.sol          // Deployment script for contracts

```

### Concept
Real-World Asset (RWA) tokenization bridges the gap between physical and digital assets by creating tokenized representations of tangible assets such as real estate, art, and commodities. This platform includes:

- **Fractional Ownership**: Enables users to own shares of tokenized assets.
- **Governance**: Allows owners to create and vote on proposals for asset actions.
- **Marketplace**: Facilitates buying, selling, and bidding for asset shares.

### Components

#### 1. **PropertyNFT**
   - Represents tokenized real-world assets as ERC-721 NFTs.
   - Stores metadata such as valuation and ownership details.

#### 2. **AssetListing**
   - Manages fractional ownership of PropertyNFTs.
   - Allows listing assets for sale and distributing funds among fractional owners.

#### 3. **Marketplace**
   - Enables users to bid for fractional shares or purchase outright.
   - Implements first-come-first-serve mechanisms for resolving bid conflicts.

#### 4. **Governance**
   - Facilitates proposal creation and voting.
   - Manages quorum requirements, vote thresholds, and proposal execution.

### Workflow
1. **Asset Listing**:
   - A property owner requests the listing of their real-world asset by minting a PropertyNFT.
   - Asset is tokenized into fractional ownership shares.

2. **Marketplace Bidding**:
   - Users bid on fractional shares, adhering to the minimum price set by the owner.
   - After the bidding deadline, the highest bidder is awarded the shares.

3. **Governance Proposals**:
   - Owners propose actions (e.g., asset sale) and specify a sale price.
   - Other owners vote; based on the outcome, the action is executed.

4. **Execution**:
   - Approved proposals trigger corresponding actions (e.g., selling the asset or distributing proceeds).

### Testing Workflow
- A detailed test suite demonstrates:
  - Asset listing and ownership validation.
  - Partial purchases of shares until fully subscribed.
  - Proposal creation, voting, and execution.
  - Edge cases, such as unauthorized votes or invalid actions.

## Getting Started

### Prerequisites
- Node.js and npm
- Foundry (for Solidity testing)
- Hardhat or Truffle (optional, for deployment)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/0zkillua/RWA_V2.git
   cd RWA_V2
   ```
2. Install dependencies:
   ```
   forge build
   ```

### Foundry Tests
Run the tests to validate the complete workflow:

```bash

forge test

```

Tests cover:
- Asset listing and fractionalization.
- Marketplace bidding and conflict resolution.
- Governance proposal creation and voting.
- Edge cases (e.g., unauthorized votes).

## Future Enhancements
- **Audit**: Review Design choices, Security of codebase.
- **KYC Integration**: Add identity verification for participants.
- **Quadratic Voting**: Ensure fair representation in governance.
- **Cross-Chain Compatibility**: Expand to other EVM-compatible chains.
- **Liquidity Pools**: Enable share trading on decentralized exchanges.

## License
This project is licensed under the MIT License.

---

