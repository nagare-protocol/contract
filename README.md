# Nagare Protocol Smart Contracts

## Overview

Nagare Protocol is a decentralized escrow and payment solution that revolutionizes how freelancers and gig workers receive payments while generating yield on idle funds.

## Problems We Solve

### Delayed Payments

Freelancers and gig workers wait days or weeks to receive payment after completing work, creating cash flow issues.

### Idle Escrow Funds

Billions in escrow funds sit idle in platform accounts, generating no value for either platforms or workers.

### Lack of Transparency

Workers have no visibility into payment status or proof of funds, creating trust issues between platforms and workers.

## Our Solution

Nagare Protocol enables clients to send payments to workers through a transparent, yield-generating escrow system:

- **Yield Generation**: Funds are deposited into Morpho Protocol to earn yield while in escrow
- **Proof-of-Work Verification**: Workers submit proof of work to claim payments through our verifier system
- **Transparency**: All agreements and payment statuses are on-chain and verifiable
- **Flexibility**: Compatible with any ERC-4626 vault and custom verifier implementations

## Architecture

Nagare Protocol consists of 3 core smart contract components:

### 1. Agreement

The main contract that manages payment agreements between clients and contractors. It handles:

- Starting new agreements with specified terms
- Managing fund transfers and escrow
- Coordinating with verifiers for payment releases

### 2. Vault

ERC-4626 compatible vault system for yield generation:

- USDC-based vaults
- Integrated with Morpho Protocol for yield optimization
- Custom vault implementations supported

### 3. Verifier

Modular verification system for proof-of-work validation:

- Custom verifier implementations for different work types
- Checkpoint and termination verification
- Pluggable architecture for various verification methods

## Workflow

1. **Agreement Creation**: Client calls `startAgreement()` with contract terms, transferring funds to the vault
2. **Work Progress**: At any time, either party can execute:
   - `checkpoint()` - Verify work progress and release partial payments
   - `terminate()` - Complete or cancel the agreement
3. **Verification**: The verifier component validates auxiliary data and returns approve/reject
4. **Payment Release**: On approval, vault tokens are transferred to the contractor
5. **Fund Recovery**: On termination, remaining funds return to the client

## Technical Interfaces

The protocol defines clear interfaces for extensibility:

- **INagareAgreement**: Core agreement management functions
- **INagareVerifier**: Pluggable verification logic
- **ERC-4626**: Standard vault compatibility for yield generation

For detailed interface specifications, see the `/src/interface/` directory.
