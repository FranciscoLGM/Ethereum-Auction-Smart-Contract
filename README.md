# 🧾 Ethereum Auction Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

A robust and secure Ethereum smart contract implementing a decentralized auction system with validated bidding, automatic time extension, partial and post-auction refunds, commission handling, and full bid history tracking. Built in Solidity and deployed on the **Sepolia** testnet.

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
- Withdraw your overbid amount **during** auction (full refund).
- Owner can refund all losing bids **after** auction (2% commission retained).
- Anyone can finalize auction once it ends.
- Winner is publicly retrievable after auction finalization.
- Full bid history available via getter.

### 🔁 Advanced Functionalities

- **Partial refund** system available during active auction (no commission).
- **Post-auction refunds** processed by the owner with commission applied.
- **Commission tracking** and withdrawal by the owner.
- **Bidder struct** for clean, structured bid management.
- **Finalization logic** encapsulated in a private function.
- **Reentrancy protection** using the Checks-Effects-Interactions pattern.
- **receive() / fallback()** implemented to reject unintended ETH transfers.

---

## ⚙️ Constructor Parameters

| Parameter        | Value         | Description                                       |
| ---------------- | ------------- | ------------------------------------------------- |
| `duration`       | `7 days`      | Auction duration from deployment                  |
| `minBidIncrease` | `105`         | Minimum bid increment as a multiplier (105 = +5%) |
| `commissionRate` | `2`           | Commission % deducted from post-auction refunds   |
| `extensionTime`  | `600 seconds` | Extra time added if bid placed in last 10 minutes |

> ℹ️ These values are currently hardcoded but can be made configurable in future upgrades.

---

## 📊 Contract Variables

| Variable          | Type       | Description                                    |
| ----------------- | ---------- | ---------------------------------------------- |
| `owner`           | `address`  | Address of contract deployer                   |
| `endTime`         | `uint256`  | Auction end timestamp                          |
| `minBidIncrease`  | `uint256`  | Minimum bid multiplier (e.g., 105 = +5%)       |
| `commissionRate`  | `uint256`  | Commission % applied to refunds                |
| `extensionTime`   | `uint256`  | Additional time added to last-minute bids      |
| `totalCommission` | `uint256`  | Total commission accumulated (from refunds)    |
| `isAuctionEnded`  | `bool`     | True if auction has been finalized             |
| `allRefunded`     | `bool`     | True if all non-winning refunds were processed |
| `highestBidder`   | `Bidder`   | Current highest bidder and bid                 |
| `winner`          | `Bidder`   | Final winner and winning bid                   |
| `pendingReturns`  | `mapping`  | Refundable balances for overbid participants   |
| `allBids`         | `Bidder[]` | Complete bid history (in order of arrival)     |

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

- Places a new valid bid.
- Requires at least 5% more than the current highest bid.
- Adds previous highest bid to `pendingReturns`.
- Extends `endTime` by 10 minutes if bid is close to deadline.
- Emits `NewBid`.
- Automatically finalizes auction if time has expired.

### 💸 `partialRefund()`

- Lets users withdraw their refundable bids during the **active** auction.
- Emits `PartialRefund`.
- No commission is deducted.

### 🏆 `getWinner()`

- Returns address and amount of the winning bid.
- Only available **after** the auction is finalized.

### 📜 `getAllBids()`

- Returns full history of all bids placed.

### ⏳ `getRemainingTime()`

- Returns remaining time in seconds until auction ends.
- Returns `0` if auction has ended.

### 🛑 `finalizeAuction()`

- Publicly callable.
- Finalizes the auction if the time has passed and sets the winner.
- Emits `AuctionEnded`.

### 💳 `refundAll()`

- Owner-only.
- Refunds all non-winning bids with a 2% commission deducted.
- Uses `.call()` for fund transfers.
- Emits `Refunded` for each address.

### 💰 `withdrawWinningBid()`

- Transfers winning bid amount plus accumulated commissions to owner.
- Emits `OwnerWithdrawal`.

### 🚫 `receive()` / `fallback()`

- Rejects any direct ETH transfers or invalid calls.
- Protects the contract from unintended deposits or `selfdestruct` attacks.
- Reverts with a clear error message:

```solidity
receive() external payable {
    revert("Direct ETH transfers not allowed");
}

fallback() external payable {
    revert("Invalid function call or direct ETH transfer");
}
```

---

## 📣 Events

| Event             | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| `NewBid`          | Emitted when a valid bid is submitted                       |
| `AuctionEnded`    | Emitted when auction is finalized and winner is declared    |
| `PartialRefund`   | Emitted when bidder claims refund during auction (full)     |
| `Refunded`        | Emitted during owner-triggered post-auction refund (2% fee) |
| `OwnerWithdrawal` | Emitted when owner collects funds after auction ends        |

---

## 🛡️ Modifiers

| Modifier     | Description                                             |
| ------------ | ------------------------------------------------------- |
| `onlyOwner`  | Restricts function to the contract owner                |
| `onlyActive` | Ensures the auction is still ongoing                    |
| `onlyEnded`  | Ensures the auction has ended (time-based or finalized) |
| `notOwner`   | Prevents the owner from placing bids                    |

---

## 🚀 Deployment Guide

### Requirements

- Wallet with Sepolia ETH (for testing)
- MetaMask or other Web3 wallet

### Steps

1. Clone repository.
2. Compile the contract.
3. Deploy to Sepolia.
4. Confirm deployment via Etherscan.

---

## 🧪 Usage Guide

- Bidders call `bid()` with ETH value ≥ 5% of the current bid.
- If outbid, they can call `partialRefund()` any time before auction ends.
- Once ended, anyone can call `finalizeAuction()`.
- Owner must then call:

  - `refundAll()` — to return non-winning bids minus commission.
  - `withdrawWinningBid()` — to receive the winning bid and accumulated commissions.

---

## 🔐 Security Considerations

- Follows **Checks-Effects-Interactions** pattern.
- All external transfers done via `.call()` with **reentrancy protection**.
- Owner cannot place bids (`notOwner` modifier).
- Refunds and withdrawals are protected from repeated access.
- ✅ **ETH Transfer Lockdown**: both `receive()` and `fallback()` functions are explicitly defined to **revert** any unintended ETH transfers or invalid function calls, ensuring funds are only accepted via the controlled `bid()` logic.

---

## 📎 External Links

- 🔗 [Sepolia Faucet](https://sepoliafaucet.com/)
- 🧠 [Solidity Docs](https://docs.soliditylang.org/)
- 🛠️ [Remix IDE](https://remix.ethereum.org/)
- 📡 [Etherscan (Sepolia)](https://sepolia.etherscan.io/)

---

## 📄 License

This project is licensed under the MIT License.

---
