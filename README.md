# StackLend

A decentralized lending protocol built on the Stacks blockchain that allows users to deposit STX as collateral and borrow against it.

## Features

- Deposit STX as collateral
- Borrow STX against your collateral
- Repay loans with interest
- Liquidation mechanism for undercollateralized positions
- Protocol fees for sustainability

## Smart Contract Functions

### User Functions

- `deposit`: Deposit STX as collateral
- `withdraw`: Withdraw STX from your collateral
- `borrow`: Borrow STX against your collateral
- `repay`: Repay your borrowed STX

### Protocol Functions

- `liquidate`: Liquidate undercollateralized positions
- `get-collateral-ratio`: Check the collateral ratio of a user
- `get-deposit`: Get deposit information for a user
- `get-loan`: Get loan information for a user

## Security Considerations

- Minimum collateral ratio of 150%
- Liquidation threshold at 130%
- All functions include proper checks and balances

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://github.com/blockstack/stacks.js)

### Testing

\`\`\`bash
clarinet check
clarinet test
