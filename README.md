# 🧾 Ethereum Auction Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

A robust, feature-rich Ethereum smart contract implementing a decentralized auction system with automated bid validation, time extension, partial refunds, commission-based finalization, and secure fund management. Built in Solidity and deployed on the **Sepolia** testnet.

---

## 📚 Table of Contents

- [Features](#features)
- [Constructor Parameters](#constructor-parameters)
- [Contract Variables](#contract-variables)
- [Public Functions](#public-functions)
- [Events](#events)
- [Modifiers](#modifiers)
- [Deployment Guide](#deployment-guide)
- [Usage Guide](#usage-guide)
- [Security Considerations](#security-considerations)
- [License](#license)

---

## ✨ Features

### ✅ Core Functionalities

- Place valid bids (≥ 5% higher than current highest bid).
- Automatic 10-minute extension for last-minute bids.
- Withdraw overbid amounts (full refund during auction, minus 2% commission after).
- View auction winner and winning bid.
- Full bid history for transparency.
- Owner-only auction termination and fund withdrawal.

### 🔁 Advanced Functionalities

- **Partial refund mechanism**: Users can reclaim overbid funds from previous offers.
- **Time extension logic**: Any bid made in the last 10 minutes extends the auction by 10 more minutes.
- **Commission-based refund**: After auction ends, losers receive refunds minus 2% commission.
- **Secure ETH handling**: Prevents reentrancy and ensures safe transfers.

---

## ⚙️ Constructor Parameters

The contract is initialized with the following default parameters:

| Parameter        | Value     | Description                                  |
| ---------------- | --------- | -------------------------------------------- |
| `endTime`        | +7 days   | Auction duration from contract deployment    |
| `minBidIncrease` | `105`     | 5% minimum bid increment                     |
| `commissionRate` | `2`       | 2% commission on post-auction refunds        |
| `extensionTime`  | `10 mins` | Extra time if bid placed in final 10 minutes |

---

## 📊 Contract Variables

| Variable         | Type       | Description                               |
| ---------------- | ---------- | ----------------------------------------- |
| `owner`          | `address`  | Contract deployer and manager             |
| `endTime`        | `uint256`  | Auction expiration timestamp              |
| `highestBidder`  | `Bidder`   | Struct of current top bidder and amount   |
| `allBids`        | `Bidder[]` | Array storing all bids                    |
| `pendingReturns` | `mapping`  | Tracks refundable amounts for each bidder |
| `isAuctionEnded` | `bool`     | Tracks whether auction has been finalized |

### `Bidder` Struct

```solidity
struct Bidder {
    address bidderAddress;
    uint256 amount;
}
```

---

## 📂 Public Functions

### 🔨 `bid()`

- Place a bid with `msg.value`.
- Must be ≥ 5% higher than current bid.
- Extends auction by 10 minutes if bid placed in final 10 minutes.
- Triggers `NewBid` event.
- Automatically ends auction if `block.timestamp ≥ endTime`.

### 🏆 `getWinner()`

- View winner address and final bid amount.
- Callable **only after auction ends**.

### 📜 `getAllBids()`

- Returns an array of all valid bids.
- Useful for bid history auditing.

### 💸 `withdraw()`

- Refunds previous bids.
- During auction: full refund.
- After auction: refund minus 2% commission.
- Fires `Refunded` or `PartialRefund`.

### ⏳ `getRemainingTime()`

- Returns seconds left until auction ends.
- Returns `0` if already ended.

### 🛑 `endAuction()`

- Callable only by the contract `owner`.
- Forces auction finalization.
- Triggers `AuctionEnded` event.

### 💰 `withdrawWinningBid()`

- Allows `owner` to withdraw winning bid after auction ends.
- Sends full amount (no commission).

---

## 📣 Events

| Event             | Trigger Condition                                    |
| ----------------- | ---------------------------------------------------- |
| `NewBid`          | When a valid new bid is placed                       |
| `AuctionEnded`    | When auction is finalized (auto or manually)         |
| `Refunded`        | Refund to bidder **after** auction (with commission) |
| `PartialRefund`   | Refund to bidder **during** auction (full refund)    |
| `OwnerWithdrawal` | Owner withdraws final bid amount after auction       |

---

## 🛡️ Modifiers

| Modifier     | Purpose                                   |
| ------------ | ----------------------------------------- |
| `onlyOwner`  | Restricts function to contract deployer   |
| `onlyActive` | Restricts to when auction is still active |
| `onlyEnded`  | Restricts to after auction is ended       |

---

## 🚀 Deployment Guide

### Requirements

- Solidity compiler ^0.8.0
- Ethereum-compatible testnet (Sepolia recommended)
- Recommended tools: **Remix**, **Hardhat**, or **Foundry**

### Verifying Contract

Use Etherscan’s Contract Verification Tool with the same compiler version used to deploy the contract.

---

## 🧪 Usage Guide

### Bidders

1. Call `bid()` with a value ≥ 5% more than the current highest bid.
2. If outbid, retrieve your ETH via `withdraw()`.
3. After auction ends, call `getWinner()` to see who won.

### Owner

1. Call `endAuction()` after auction time expires.
2. Call `withdrawWinningBid()` to retrieve the final amount.

---

## 🔐 Security Considerations

- ✅ Reentrancy-safe ETH transfers (`.call{value: ...}` with `pendingReturns[msg.sender] = 0`)
- ✅ Validations ensure bid logic correctness (e.g., 5% rule).
- ✅ Restricted access with modifiers (`onlyOwner`, `onlyActive`, `onlyEnded`)
- ✅ Internal `_finalizeAuction()` to avoid duplicate finalization

---

## 📎 External Links

- 🔗 **Contract (Sepolia)**: \[Paste Verified Etherscan Link Here]
- 💾 **GitHub Repository**: \[Paste GitHub Repo Link Here]

---

## 📄 License

This smart contract is licensed under the [MIT License](./LICENSE).
