# 🛣️ Tokenized Road Maintenance Fund

A decentralized autonomous organization (DAO) for managing road maintenance funding through community contributions and democratic governance.

## 📝 Overview

This smart contract enables citizens to contribute STX tokens to a shared road repair fund. DAO members can vote on proposals from service providers, and approved proposals receive automatic payments.

## ✨ Features

- 💰 **Community Funding**: Citizens contribute STX to build a shared maintenance fund
- 🗳️ **Democratic Governance**: DAO members vote on repair proposals
- 📋 **Proposal System**: Service providers submit detailed repair proposals
- 💸 **Automatic Payments**: Approved proposals receive automatic fund disbursement
- 🔍 **Transparency**: All transactions and votes are recorded on-chain

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX tokens

### Installation
```bash
git clone <repository-url>
cd tokenized-road-maintenance-fund
clarinet console
```

## 📖 Usage

### 1. Contributing to the Fund 💳
```clarity
(contract-call? .tokenized-road-maintenance-fund contribute u1000000)
```

### 2. Joining the DAO 🏛️
Contributors with at least 1 STX can join the DAO:
```clarity
(contract-call? .tokenized-road-maintenance-fund join-dao)
```

### 3. Creating a Proposal 📝
```clarity
(contract-call? .tokenized-road-maintenance-fund create-proposal 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u500000
  "Repair Main St pothole at intersection")
```

### 4. Voting on Proposals 🗳️
DAO members can vote for (true) or against (false):
```clarity
(contract-call? .tokenized-road-maintenance-fund vote u1 true)
```

### 5. Executing Approved Proposals ⚡
After voting deadline with majority approval:
```clarity
(contract-call? .tokenized-road-maintenance-fund execute-proposal u1)
```

## 🔍 Read-Only Functions

### Check Fund Balance 💰
```clarity
(contract-call? .tokenized-road-maintenance-fund get-fund-balance)
```

### View Proposal Details 📋
```clarity
(contract-call? .tokenized-road-maintenance-fund get-proposal u1)
```

### Check DAO Membership 👥
```clarity
(contract-call? .tokenized-road-maintenance-fund is-dao-member 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Verify Voting Status ✅
```clarity
(contract-call? .tokenized-road-maintenance-fund has-voted u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🎯 Key Parameters

- **Minimum DAO Contribution**: 1 STX (1,000,000 microSTX)
- **Voting Period**: 1,440 blocks (~24 hours)
- **Quorum Requirement**: 50% of DAO members must vote
- **Approval Threshold**: Simple majority (>50% for votes)

## 🔐 Security Features

- Only contributors with sufficient stake can join DAO
- One vote per member per proposal
- Proposals cannot exceed available funds
- Time-locked voting periods
- Automatic execution prevents manipulation

## 📊 Contract State

The contract maintains:
- Total fund balance
- Individual contributor balances
- DAO membership registry
- Proposal history and voting records
- Execution status tracking

## 🛠️ Development

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📄 License

This project is licensed under the MIT License.
