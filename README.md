# 🧠 ABC MetaFunHub – Smart Contract System (MFH)

Welcome to the **ABC MFH Smart Contract Suite**, a comprehensive Web3 ecosystem for meme NFTs, marketplace trading, rentals, lending, staking, and gamified rewards.

> Built with Solidity ^0.8.20, Hardhat, OpenZeppelin contracts, and Chainlink VRF. Features modular architecture, escrow mechanics, 2-of-3 multisig security, royalty distribution, and installment payment systems.

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue)](https://soliditylang.org/)
[![Hardhat](https://img.shields.io/badge/Hardhat-Development-yellow)](https://hardhat.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Contracts-4E5EE4)](https://openzeppelin.com/)

---

## 📋 Project Status

✅ **COMPLETE** - All 19 contracts implemented and tested  
🔒 **SECURITY AUDITED** - ReentrancyGuard, Pausable, Multisig controls added  
📦 **DEPLOYMENT READY** - All deployment scripts verified and updated  

See [PROJECT_COMPLETION_REPORT.txt](./PROJECT_COMPLETION_REPORT.txt) for detailed completion report.

---

## 📁 Project Structure

```
MFH-Dev-A-Smart-Con/
├── contracts/
│   ├── token/              # MFH token, staking, treasury
│   ├── nft/                # NFT minting, royalties, boost
│   ├── marketplace/        # Trading, auctions, BNPL
│   ├── rentals/            # NFT rental system
│   ├── finance/            # Loans, installments
│   ├── rewards/            # Daily check-ins, jackpot
│   └── escrow/             # Asset custody, multisig
├── deploy/                 # Hardhat deployment scripts
├── test/                   # Contract test suites
├── scripts/                # Utility scripts
├── hardhat.config.js       # Hardhat configuration
├── package.json            # Dependencies
└── README.md               # This file
```

---

## 🔗 Smart Contracts Overview

### **Token Module** (3 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `MFHToken.sol` | ERC20 utility token | 1B supply, pausable, mintable, burnable |
| `TreasuryVault.sol` | Platform revenue collector | Multisig withdrawals, token deposits |
| `StakingRewards.sol` | Stake MFH for rewards | Time-based rewards, early withdrawal penalty |

### **NFT Module** (3 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `NFTMinting.sol` | Meme NFT creation | Pay in MFH, 5 NFTs per wallet max |
| `RoyaltyManager.sol` | Creator royalties | Up to 10% on resales, auto-distribution |
| `BoostEngine.sol` | NFT visibility boost | Pay to boost, time-based expiry |

### **Marketplace Module** (4 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `MarketplaceCore.sol` | Buy/sell NFTs | Fixed price listings, 5% platform fee |
| `BuyNowPayLater.sol` | Installment purchases | Escrow integration, payment plans |
| `AuctionModule.sol` | Timed auctions | Minimum bid, highest bidder wins |
| `BiddingSystem.sol` | Open bidding | Place/cancel bids, seller accepts |

### **Rentals Module** (2 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `RentalEngine.sol` | NFT rental system | Direct rent(), return, default tracking |
| `LeaseAgreement.sol` | Lease contracts | Start/end leases, duration control |

### **Finance Module** (2 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `LoanModule.sol` | NFT-backed loans | Borrow MFH, installment repayment, liquidation |
| `InstallmentLogic.sol` | Payment library | Shared installment logic (library) |

### **Rewards Module** (3 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `RewardDistributor.sol` | Batch reward airdrops | Owner distributes to multiple users |
| `SecretJackpot.sol` | Random jackpot | Chainlink VRF, staker eligibility |
| `CheckInReward.sol` | Daily check-in rewards | 24-hour cooldown, MFH rewards |

### **Escrow & Admin Module** (2 contracts)
| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `EscrowManager.sol` | Secure NFT custody | ReentrancyGuard, pausable, multisig release |
| `MultiSigAdmin.sol` | 2-of-3 multisig wallet | Transaction proposals, confirmations, safe execution |

**Total: 19 production-ready contracts** ✅

---

## 🚀 Quick Start

### 1️⃣ Install Dependencies

```bash
npm install
```

### 2️⃣ Configure Environment

Copy the example environment file and configure it:

```bash
cp example_for_env .env
```

Edit `.env` with your settings:

```env
# Deployer wallet
PRIVATE_KEY=your_private_key_here

# Network RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Etherscan API (for verification)
ETHERSCAN_API_KEY=your_etherscan_api_key

# Multisig Signers (3 different addresses)
MULTISIG_SIGNER_1=0x...
MULTISIG_SIGNER_2=0x...
MULTISIG_SIGNER_3=0x...

# Chainlink VRF Configuration
VRF_COORDINATOR=0x...
LINK_TOKEN=0x...
KEY_HASH=0x...

# Treasury address
TREASURY_ADDRESS=0x...
```

### 3️⃣ Compile Contracts

```bash
npx hardhat compile
```

---

## 📡 Deployment

### Full Deployment (All Modules)

```bash
npx hardhat run deploy/deploy-A.js --network sepolia
```

### Modular Deployment (By Module)

Deploy specific modules using tags:

```bash
# Deploy token module only
npx hardhat deploy --tags TokenModule --network sepolia

# Deploy NFT + Marketplace
npx hardhat deploy --tags NFTModules,MarketplaceModule --network sepolia

# Deploy everything
npx hardhat deploy --tags TokenModule,NFTModules,EscrowModule,MarketplaceModule,RentalsModule,FinanceModule,RewardsModule --network sepolia
```

### Post-Deployment Setup

**Important:** Run this after initial deployment to configure contract integrations:

```bash
npx hardhat run deploy/postDeploySetup.js --network sepolia
```

This script will:
- Inject MFHToken address into all modules
- Set TreasuryVault addresses
- Whitelist trusted modules in EscrowManager (BNPL, Loans, Rentals)
- Link RoyaltyManager to MarketplaceCore

---

## 🧪 Testing

### Run All Tests

```bash
npx hardhat test
```

### Run Specific Test Files

```bash
npx hardhat test test/token.test.js
npx hardhat test test/marketplace.test.js
npx hardhat test test/escrow.test.js
```

### Test Coverage

The test suite covers:
- ✅ Token operations (mint, burn, pause, transfer)
- ✅ Staking rewards calculation and distribution
- ✅ NFT minting with payment validation
- ✅ Marketplace listings, purchases, and fees
- ✅ Auction mechanics and bidding
- ✅ BNPL installment payments
- ✅ Rental system (rent, return, default)
- ✅ Loan creation and repayment
- ✅ Escrow lock/release flows
- ✅ Multisig transaction execution
- ✅ Reward distribution systems

---

## 🔐 Security Features

This project implements multiple layers of security:

### Access Control
- 🔒 **OpenZeppelin Ownable** - Owner-only functions for admin tasks
- 🔒 **2-of-3 Multisig** - Critical operations require 2 signatures
- 🔒 **Trusted Module Whitelist** - Only approved contracts can access escrow

### Security Mechanisms
- 🛡️ **ReentrancyGuard** - Prevents reentrancy attacks on EscrowManager
- ⏸️ **Pausable** - Emergency pause functionality for critical contracts
- 🔐 **Safe External Calls** - Using OpenZeppelin's Address library
- ✅ **Input Validation** - Zero address checks, duplicate prevention

### Escrow Protection
- 📦 **Locked Asset Tracking** - NFTs marked as locked during loans/BNPL/rentals
- 🔓 **Multisig Release** - Only multisig can release/forfeit escrowed assets
- 🚨 **Emergency Withdrawal** - Owner can rescue stuck assets (when paused)

---

## 🔧 Key Features

### 💰 Token Economics
- **MFH Token**: ERC20 utility token with 1 billion max supply
- **Staking**: Lock MFH to earn time-based rewards
- **Early Withdrawal Penalty**: 10% penalty if unstaking before 7 days
- **Treasury Management**: Multisig-controlled platform revenue

### 🎨 NFT Ecosystem
- **Meme NFT Minting**: Pay 10 MFH to mint, 5 NFTs per wallet limit
- **Creator Royalties**: Up to 10% royalty on secondary sales
- **NFT Boosting**: Pay to boost NFT visibility for X days
- **Rentals**: Rent out your NFTs for others to use

### 🛒 Marketplace
- **Fixed Price Listings**: List and sell NFTs instantly
- **Auctions**: Time-based auctions with minimum bids
- **Buy Now Pay Later**: Purchase NFTs with installment payments
- **Bidding System**: Open bidding on any NFT

### 🏦 Finance
- **NFT-Backed Loans**: Use NFTs as collateral to borrow MFH
- **Installment Payments**: Flexible payment plans via library
- **Liquidation**: Automatic liquidation on loan default
- **Escrow Protection**: Assets secured during all transactions

### 🎁 Rewards
- **Daily Check-In**: Claim MFH rewards every 24 hours
- **Secret Jackpot**: Random jackpot using Chainlink VRF
- **Batch Airdrops**: Admin can distribute rewards to multiple users

---

## 📜 Contract Verification

After deployment, verify contracts on Etherscan:

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

Example:
```bash
npx hardhat verify --network sepolia 0x123... "0xTokenAddress"
```

---

## 🎯 Pre-Deployment Checklist

Before deploying to testnet or mainnet:

- [ ] Configure 3 different multisig signer addresses
- [ ] Set up Chainlink VRF coordinator and LINK token addresses
- [ ] Configure treasury address for platform fees
- [ ] Fund deployer wallet with enough ETH for gas
- [ ] Update RPC URLs for target network
- [ ] Test on local Hardhat network first
- [ ] Run full test suite (`npx hardhat test`)
- [ ] Review gas costs and optimize if needed
- [ ] Prepare LINK tokens for SecretJackpot (Chainlink VRF)
- [ ] Prepare MFH tokens for reward contracts

---

## 🔄 Post-Deployment Tasks

After successful deployment:

1. **Whitelist Trusted Modules**
   ```bash
   npx hardhat run deploy/postDeploySetup.js --network sepolia
   ```

2. **Fund Reward Contracts**
   - Transfer MFH to RewardDistributor for airdrops
   - Transfer MFH to CheckInReward for daily rewards (e.g., 100,000 MFH)
   - Transfer MFH to SecretJackpot for jackpot pool (e.g., 50,000 MFH)
   - Transfer LINK to SecretJackpot for VRF fees (e.g., 10 LINK)

3. **Configure Multisig**
   - Test transaction submission
   - Test 2-of-3 confirmation flow
   - Transfer ownership of critical contracts to multisig

4. **Verify on Etherscan**
   - Verify all contract source code
   - Add contract descriptions and links

5. **Test Integration**
   - Mint test NFT
   - List on marketplace
   - Test BNPL flow
   - Test loan creation
   - Test rental system
   - Trigger jackpot (if testing VRF)

---

## 🧩 Integration Notes

### EscrowManager Integration
The following contracts interact with EscrowManager:
- **BuyNowPayLater**: Locks NFTs during installment payments
- **LoanModule**: Locks NFTs as loan collateral
- **RentalEngine**: Can integrate for rental escrow (future)

These contracts must be whitelisted using `EscrowManager.setTrusted(address, true)`.

### InstallmentLogic Library
`InstallmentLogic.sol` is a **library**, not a contract. It's used by:
- **LoanModule**: For loan repayment installments

No separate deployment needed - it's compiled into contracts that use it.

### Multisig Operations
Critical operations requiring multisig approval:
- Releasing escrowed NFTs (`EscrowManager.releaseAsset`)
- Forfeiting defaulted NFTs (`EscrowManager.forfeitAsset`)
- Withdrawing from TreasuryVault (large amounts)
- Changing multisig signers

---

## 📚 Additional Resources

- **Specification Document**: `Smart contract dev-a.txt` - Full technical specs
- **Completion Report**: `PROJECT_COMPLETION_REPORT.txt` - Implementation details
- **OpenZeppelin Docs**: https://docs.openzeppelin.com/
- **Hardhat Docs**: https://hardhat.org/docs
- **Chainlink VRF**: https://docs.chain.link/vrf

---

## ⚠️ Known Limitations

1. **EscrowManager Multisig**: Every release requires 2-of-3 approval. Consider auto-release for completed BNPL in future versions.

2. **InstallmentLogic**: Simple total-based tracking. No specific due dates per installment.

3. **RentalEngine**: No built-in pricing logic. Rental fees must be handled separately.

4. **SecretJackpot**: Requires LINK tokens for Chainlink VRF. Keep contract funded.

5. **No Upgradeability**: Contracts are not upgradeable. Future changes require new deployments.

---

## 🤝 Contributing

This is a private project for ABC MetaFunHub. For any issues or suggestions, contact the development team.

---

## 📄 License

MIT License - See LICENSE file for details

---

## 👥 Team

**Developer A** - Smart Contract Development  
**Project**: ABC MetaFunHub (MFH)  
**Date**: November 2025

---

## 🔗 Links

- **Website**: [Coming Soon]
- **Twitter**: [Coming Soon]
- **Discord**: [Coming Soon]
- **Documentation**: [Coming Soon]

---

**Built with ❤️ for the Web3 community**
