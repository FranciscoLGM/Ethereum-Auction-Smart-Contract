# 🧾 Ethereum Auction Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

A robust and secure Ethereum smart contract implementing a decentralized auction system with validated bidding, automatic time extension, partial and post-auction refunds, commission handling, bid history, and emergency mechanisms. Built in Solidity and deployed on the **Sepolia** testnet.

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
- First bid must be at least **1 ETH**.
- Automatic 10-minute extension for last-minute bids.
- Withdraw overbid amounts **during** auction (no fee).
- Owner can refund all losing bids **after** auction (2% commission).
- Full bid history accessible via public getter.
- Public winner retrieval after finalization.
- Auction ends automatically when time expires or owner terminates it.

### 🔁 Advanced Functionalities

- **Partial refunds** available during auction (0% fee).
- **Post-auction refunds** handled by owner with **2% commission**.
- **Commission tracking** and **withdrawal** by owner.
- Emergency **force-termination** before end time.
- **Emergency withdrawal** of contract funds by owner.
- Fully encapsulated **bidder struct** and private finalization logic.
- **receive() / fallback()** functions revert unintended ETH transfers.

---

## ⚙️ Constructor Parameters

| Parameter        | Value        | Description                                     |
| ---------------- | ------------ | ----------------------------------------------- |
| `duration`       | `7 days`     | Auction duration from deployment                |
| `minIncrease`    | `105`        | Minimum bid increment multiplier (5%)           |
| `commissionRate` | `2`          | Commission % for post-auction refunds           |
| `extensionTime`  | `10 minutes` | Time added if a bid is placed near the deadline |
| `initBid`        | `1 ether`    | Minimum value for the first bid                 |

---

## 📊 Contract Variables

| Variable           | Type       | Description                                      |
| ------------------ | ---------- | ------------------------------------------------ |
| `owner`            | `address`  | Address of the contract deployer                 |
| `endTime`          | `uint256`  | Timestamp when auction ends                      |
| `minIncrease`      | `uint256`  | Bid increment multiplier (e.g., 105 = +5%)       |
| `commissionRate`   | `uint256`  | Commission rate used on post-auction refunds     |
| `extensionTime`    | `uint256`  | Time added to auction if bid comes late          |
| `initBid`          | `uint256`  | Minimum first bid (1 ETH)                        |
| `totalCommission`  | `uint256`  | Total accumulated commissions                    |
| `isEnded`          | `bool`     | Whether auction has been finalized or terminated |
| `refundsProcessed` | `bool`     | Whether all non-winning refunds were handled     |
| `highestBidder`    | `Bidder`   | Current highest bid info                         |
| `winner`           | `Bidder`   | Winner and winning amount                        |
| `pendingRefunds`   | `mapping`  | Refund balances for outbid participants          |
| `allBids`          | `Bidder[]` | Chronological list of all bids                   |

---

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
- Enforces minimum 1 ETH and 5% increment over previous bid.
- Extends time if near deadline.
- Automatically finalizes if time expired.
- Emits `NewBid`.

### 💸 `partialRefund()`

- Allows outbid participants to withdraw their ETH **during** the auction.
- No commission applied.
- Emits `PartialRefund`.

### 🏆 `getWinner()`

- Returns the winner's address and amount.
- Only callable **after** auction ends.

### 📜 `getAllBids()`

- Returns an array with all placed bids.

### ⏳ `getRemainingTime()`

- Returns remaining seconds until auction ends.
- Returns `0` if finalized or expired.

### 🛑 `finalizeAuction()`

- Finalizes auction publicly if time has ended.
- Sets the winner.
- Emits `AuctionEnded`.

### 💳 `refundAll()`

- Callable only by owner.
- Processes all non-winning refunds with **2% fee**.
- Emits `BidRefunded` for each address.

### 💰 `withdrawWinningBid()`

- Allows owner to withdraw winning bid + commissions.
- Emits `OwnerWithdrawal`.

### 🚨 `forceTerminateAuction()`

- Lets owner force-end the auction **before** `endTime`.
- Emits `AuctionForceEnded`.

### 🆘 `emergencyWithdraw()`

- Emergency function for owner to drain contract funds.
- Emits `EmergencyWithdrawal`.

### 🚫 `receive()` / `fallback()`

```solidity
receive() external payable {
    revert("Direct ETH transfers not allowed");
}

fallback() external payable {
    revert("Invalid function call or direct ETH transfer");
}
```

- Rejects unintended ETH transfers and invalid calls.

---

## 📣 Events

| Event                 | Description                                      |
| --------------------- | ------------------------------------------------ |
| `NewBid`              | A new valid bid was submitted                    |
| `AuctionEnded`        | Auction finalized and winner declared            |
| `AuctionForceEnded`   | Auction forcibly ended by owner before `endTime` |
| `PartialRefund`       | Full refund during active auction                |
| `BidRefunded`         | Post-auction refund with 2% commission applied   |
| `OwnerWithdrawal`     | Owner withdrew winning bid + commissions         |
| `EmergencyWithdrawal` | Owner withdrew all funds (emergency only)        |

---

## 🛡️ Modifiers

| Modifier     | Description                                          |
| ------------ | ---------------------------------------------------- |
| `onlyOwner`  | Restricts access to owner-only functions             |
| `onlyActive` | Ensures the auction is still ongoing                 |
| `onlyEnded`  | Ensures the auction has ended or was forcibly ended  |
| `nonOwner`   | Prevents the owner from participating in the auction |

---

## 🚀 Deployment Guide

### Requirements

- Wallet with Sepolia ETH
- MetaMask or compatible wallet
- Hardhat, Remix, or Foundry (for compilation)

### Steps

1. Clone repository.
2. Compile contract using Solidity >0.8.0.
3. Deploy on Sepolia.
4. Save deployed address and verify via Etherscan.

---

## 🧪 Usage Guide

- Users call `bid()` with ≥1 ETH and at least 5% over last bid.
- If outbid, call `partialRefund()` to retrieve ETH.
- After end time, call `finalizeAuction()` (anyone can do this).
- Owner then must:

  - Call `refundAll()` to return non-winning funds with commission.
  - Call `withdrawWinningBid()` to claim earnings.

---

## 🔐 Security Considerations

- Complies with **Checks-Effects-Interactions** pattern.
- All ETH transfers use `.call()` and are wrapped with safety checks.
- **Reentrancy-safe**: no external calls before state updates.
- Owner is restricted from bidding (`nonOwner`).
- Full ETH transfer lockdown via `receive()` and `fallback()` rejection.
- Emergency functions (`forceTerminateAuction`, `emergencyWithdraw`) are protected by `onlyOwner`.

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
