# TOBMATE Blockchain — Phase 5 DEX Core

Classification: INTERNAL
Public Distribution: PROHIBITED until reviewed

## Baseline

- Previous phase: Oracle Framework
- Baseline build: PASS
- Baseline tests: 120/120 PASS
- Baseline tag: phase4-oracle-v1
- Development branch: feature/dex-core

## Implementation Scope

- DEX Registry
- Pool Registration
- Swap Routing
- Constant Product Integration
- GOLDPEG Pool Integration
- NFT Fraction Pool Integration
- LP Mint/Burn Integration
- Multi-Fee Accounting
- Treasury Fee Integration
- Insurance Fee Integration
- Reward Fee Integration
- Oracle Price Guard
- Pause and Version Control

## Existing Modules Reused

- liquidity_pool.move
- lp_reward_distributor.move
- fee_vault.move
- revenue_router.move
- treasury.move
- insurance_fund.move
- oracle_price_router.move
- goldpeg.move
- gold_nft.move

## Initial Design Decisions

1. liquidity_pool.move remains the underlying constant-product AMM engine.
2. dex.move becomes the routing, policy, validation, accounting, and integration layer.
3. DEX price validation uses oracle_price_router.move only.
4. Existing liquidity pool accounting must not be duplicated.
5. Multi-fee accounting must conserve the full collected fee amount.
6. Public documents must exclude confidential security and operational details.

## Initial Invariants

- DEX registry and admin capability IDs must match.
- A paused DEX cannot register pools or execute swaps.
- A paused or inactive pool cannot execute swaps.
- Swap input and output amounts must be greater than zero.
- Actual output must be greater than or equal to minimum output.
- Swap deadline must not be expired.
- Total fee allocation must equal the collected trading fee.
- Oracle-guarded pools require a canonical, fresh price.
- Oracle deviation must remain within configured limits.
- Existing liquidity pool accounting invariants must remain valid.

## State Transitions

### DEX Registry

- Created
- Active
- Paused
- Active
- Version Upgraded

### DEX Pool Record

- Registered
- Active
- Inactive
- Active
- Disabled

### Swap

- Requested
- Validated
- Oracle Checked
- Executed
- Fee Accounted
- Completed

## Test Baseline

- Build: PASS
- Tests: 120/120 PASS
- Failed: 0

## Planned DEX Tests

- Registry initialization
- Admin capability validation
- Pool registration
- Duplicate pool rejection
- Pause lifecycle
- Version lifecycle
- Inactive pool rejection
- Zero-input rejection
- Deadline validation
- Slippage validation
- X-to-Y swap
- Y-to-X swap
- Constant-product invariant
- Multi-fee conservation
- Treasury fee accounting
- Insurance fee accounting
- Reward fee accounting
- Oracle readiness validation
- Oracle freshness validation
- Oracle deviation validation
- Swap volume accounting
- Swap count accounting

## Security Notes

Internal only. Do not publish without security review.

## Git Milestones

- phase4-oracle-v1
- Phase 5 DEX milestone pending

## Remaining Work

- Inspect exact liquidity pool interfaces
- Implement dex.move registry
- Implement pool registration
- Implement swap routing
- Implement fee policy
- Integrate Oracle guard
- Integrate Treasury, Insurance, and Rewards
- Add DEX tests
- Run full regression tests
- Run security validation
