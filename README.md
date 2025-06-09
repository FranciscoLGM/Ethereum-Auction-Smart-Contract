# 🧾 Ethereum Auction Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

A robust and secure Ethereum smart contract implementing a decentralized auction system with bid validation, automatic time extension, partial and post-auction refunds, commission handling, and full bid history tracking. Built in Solidity and deployed on the **Sepolia** testnet.

---

## 📚 Table of Contents

- [✨ Features](#-features)
- [⚙️ Constructor Parameters](#️-constructor-parameters)
- [📊 Contract Variables](#-contract-variables)
- [📂 Public Functions](#-public-functions)
- [📣 Events](#-events)
- [🛡️ Modifiers](#️-modifiers)
- [🚀 Deployment Guide](#-deployment-guide)
- [🧪 Usage Guide](#-usage-guide)
- [🔐 Security Considerations](#-security-considerations)
- [📎 External Links](#-external-links)
- [📄 License](#-license)

---

## ✨ Features

### ✅ Core Functionalities

- Place valid bids (≥ 5% higher than current highest bid).
- Automatic 10-minute extension for last-minute bids.
- Withdraw your overbid amount during auction (full refund).
- Owner can refund all losing bids after auction (2% commission retained).
- Auction can finalize automatically or manually.
- Clear winner selection after auction ends.
- Full bid history accessible through a getter.

### 🔁 Advanced Functionalities

- **Partial refund** mechanism available during active auction.
- **Post-auction refunds** with automatic commission deduction.
- **Commission tracking** and withdrawal by owner.
- **Reentrancy-protected** ETH transfers using Checks-Effects-Interactions pattern.
- **Bidder struct** for organizing bid data.
- **Finalization logic** encapsulated in a private internal function.

---

## ⚙️ Constructor Parameters

| Parameter        | Value                | Description                                       |
| ---------------- | -------------------- | ------------------------------------------------- |
| `duration`       | `7 days` (hardcoded) | Auction duration from deployment                  |
| `minBidIncrease` | `105`                | Minimum bid increment as a multiplier (105 = +5%) |
| `commissionRate` | `2`                  | Commission percentage for post-auction refunds    |
| `extensionTime`  | `600`                | 10-minute extension window (600 seconds)          |

> ℹ️ Note: These parameters are currently hardcoded in the constructor.

---

## 📊 Contract Variables

| Variable          | Type       | Description                                      |
| ----------------- | ---------- | ------------------------------------------------ |
| `owner`           | `address`  | Address of contract deployer                     |
| `endTime`         | `uint256`  | Auction end timestamp                            |
| `minBidIncrease`  | `uint256`  | Minimum bid multiplier (e.g., 105 = +5%)         |
| `commissionRate`  | `uint256`  | Commission rate (%) for post-auction refunds     |
| `extensionTime`   | `uint256`  | Additional time added for late bids (in seconds) |
| `totalCommission` | `uint256`  | Accumulated commission held for withdrawal       |
| `isAuctionEnded`  | `bool`     | Indicates if auction has ended                   |
| `allRefunded`     | `bool`     | Indicates if all non-winning bids were refunded  |
| `highestBidder`   | `Bidder`   | Current highest bid and bidder                   |
| `winner`          | `Bidder`   | Final winner and winning bid                     |
| `pendingReturns`  | `mapping`  | Refundable balances for bidders                  |
| `allBids`         | `Bidder[]` | History of all valid bids                        |

### 📦 `Bidder` Struct

```solidity
struct Bidder {
    address bidderAddress;
    uint256 amount;
}
```

---

## 📂 Public Functions

### 🔨 `bid()`

- Places a new bid.
- Requires ≥5% increase from current highest bid.
- Extends time if bid is placed within last 10 minutes.
- Emits `NewBid`.
- Finalizes auction if block timestamp ≥ `endTime`.

### 💸 `partialRefund()`

- Allows users to claim a refund of their overbid during an active auction.
- Refund is full (no commission).
- Emits `PartialRefund`.

### 🏆 `getWinner()`

- Returns winner’s address and bid amount.
- Only callable after auction ends.

### 📜 `getAllBids()`

- Returns the full array of bids placed during the auction.

### ⏳ `getRemainingTime()`

- Returns seconds left until auction ends.
- Returns `0` if auction is ended or time is up.

### 💳 `refundAll()`

- Callable by owner **after** the auction ends.
- Refunds all non-winning bidders, subtracting 2% commission.
- Transfers refund using `.call`.
- Emits `Refunded` for each address.

### 🛑 `finalizeAuction()`

- Can be called by anyone **after** auction end time.
- Finalizes auction and declares winner.
- Emits `AuctionEnded`.

### 💰 `withdrawWinningBid()`

- Transfers highest bid + commissions to owner.
- Only callable after auction ends.
- Emits `OwnerWithdrawal`.

---

## 📣 Events

| Event             | Description                                             |
| ----------------- | ------------------------------------------------------- |
| `NewBid`          | Emitted when a valid bid is placed                      |
| `AuctionEnded`    | Emitted when auction is finalized                       |
| `PartialRefund`   | Emitted when bidder claims refund during active auction |
| `Refunded`        | Emitted during post-auction refund (minus commission)   |
| `OwnerWithdrawal` | Emitted when owner withdraws winning bid + commissions  |

---

## 🛡️ Modifiers

| Modifier     | Description                                  |
| ------------ | -------------------------------------------- |
| `onlyOwner`  | Restricts access to contract owner           |
| `onlyActive` | Ensures auction is still ongoing             |
| `onlyEnded`  | Ensures auction has ended (time or manually) |

---

## 🚀 Deployment Guide

### Requirements

- Solidity ^0.8.0
- Network: Sepolia
- Tools: Hardhat / Foundry / Remix

### Steps

1. Compile the contract using your chosen tool.
2. Deploy using Sepolia testnet.
3. Fund wallet with Sepolia ETH (via faucet).
4. Verify contract via Etherscan with correct settings.

---

## 🧪 Usage Guide

### For Bidders

1. Call `bid()` sending ETH ≥ 5% more than current bid.
2. If overbid later, you may:

   - Call `partialRefund()` during auction to withdraw.
   - Wait for owner to call `refundAll()` post-auction.

### For Owner

1. Call `finalizeAuction()` after time expires (or wait for auto).
2. Call `refundAll()` to process all refunds with commission.
3. Call `withdrawWinningBid()` to collect the winning funds + commission.

---

## 🔐 Security Considerations

- Uses `.call` with reentrancy prevention (by zeroing state before external transfer).
- No upgradeability mechanism (stateless).
- Commission logic only applies post-auction.
- `pendingReturns` protect against losing funds to overbids.
- Consider integration with `ReentrancyGuard` if adding external integrations.

---

## 📎 External Links

- [Etherscan Sepolia](https://sepolia.etherscan.io/)
- [Solidity Docs](https://docs.soliditylang.org)
- [Remix IDE](https://remix.ethereum.org)

---

## 📄 License

This project is licensed under the MIT License.

---
