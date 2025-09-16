
# Multi-Signature Wallet Contract

## Overview

This project implements a **Multi-Signature Wallet Contract** built on Clarity, with **enhanced security and optimization** features.
The wallet allows multiple owners to manage assets collectively, enforce configurable confirmation thresholds, and support transaction batching.

Key features include:

* Multiple wallet owners with role-based access (Owner, Admin, Super-Admin).
* Configurable confirmation threshold for executing transactions.
* Support for transaction batching.
* Daily spending limits with automated resets.
* Comprehensive transaction history for auditing.
* Emergency lock/unlock mechanisms for added security.

---

## Features

### Owner & Role Management

* Add or remove wallet owners through confirmed transactions.
* Assign roles (`Owner = 1`, `Admin = 2`, `Super-Admin = 3`) with different levels of control.
* Configurable threshold of confirmations required to execute transactions.

### Transaction Support

* **STX Transfers** – send STX with multi-signature approval.
* **Contract Calls** – execute contract functions securely.
* **Add/Remove Owner** – adjust wallet ownership.
* **Change Threshold** – update confirmation requirements.
* **Batch Transactions** – group multiple transactions into a single proposal.

### Security

* Wallet lock/unlock functions (Admin and Super-Admin only).
* Daily spending limit to prevent draining funds.
* Automatic expiry for transactions.
* Nonce-based validation to prevent replay attacks.
* Signature-based confirmation tracking.

### Auditing & History

* Each action (propose, confirm, revoke, execute) is logged in `transaction-history`.
* Role assignments, spending resets, and emergency actions are also recorded.

---

## Data Structures

* **Owners**: Stored in `wallet-owners` and `owner-roles`.
* **Transactions**: Managed in `transactions` with metadata (proposer, type, confirmations, expiry).
* **Confirmations**: Tracked per owner and transaction in `confirmations`.
* **Batch Transactions**: Stored in `batch-transactions` with group execution support.
* **History**: Logged in `transaction-history` for full traceability.
* **Daily Spending**: Maintained in `daily-spending` with reset logic.

---

## Public Functions

* `initialize-wallet (owners threshold)` → Initializes wallet with owners and threshold.
* `propose-transaction (...)` → Propose a new transaction.
* `confirm-transaction (transaction-id signature)` → Confirm a pending transaction.
* `execute-transaction (transaction-id)` → Execute a confirmed transaction.
* `revoke-confirmation (transaction-id)` → Revoke a prior confirmation.
* `emergency-lock` → Lock wallet (Admin role required).
* `unlock-wallet` → Unlock wallet (Super-Admin required).
* `update-daily-limit (new-limit)` → Propose update to daily spending limit.

---

## Read-Only Functions

* `get-transaction (transaction-id)` → Fetch transaction details.
* `get-confirmation (transaction-id owner)` → Check confirmation status.
* `is-wallet-owner (user)` → Verify if a user is an owner.
* `get-owner-role-info (owner)` → Get role details of an owner.
* `get-wallet-info` → Get wallet state (owners, threshold, locked status, daily limit, etc.).
* `get-transaction-history (history-id)` → Fetch historical actions.
* `get-transaction-confirmations (transaction-id owners)` → Batch confirmation query.
* `get-pending-transactions-for-owner (owner)` → View pending transactions (recommend off-chain indexing).

---

## Security & Optimization

* **Gas Optimized**: Uses maps and lightweight role checks.
* **Daily Spending Limit**: Prevents excessive withdrawals in a short time.
* **Role-Based Controls**: Admins can lock, Super-Admins can unlock.
* **Transaction Expiry**: Prevents stale or replayed transactions.
* **Nonce Validation**: Ensures uniqueness of transactions.

---

## Usage Workflow

1. **Initialize Wallet** → Add initial owners and set threshold.
2. **Propose Transaction** → Owner proposes a transfer, contract call, or update.
3. **Confirm Transaction** → Other owners confirm until threshold is met.
4. **Execute Transaction** → Any owner executes once confirmations are sufficient.
5. **Audit History** → Review proposals, confirmations, and executions via `transaction-history`.

---

## Limits & Parameters

* **Max Owners**: 20
* **Min Owners**: 2
* **Max Threshold**: 20
* **Min Threshold**: 2
* **Transaction Expiry**: 1 day (min) – 1 year (max)
* **Daily Spending Limit**: Default 10 STX

---

## Future Improvements

* Support for fungible/non-fungible token transfers.
* Enhanced batch transaction execution.
* Off-chain indexing integrations for faster queries.

