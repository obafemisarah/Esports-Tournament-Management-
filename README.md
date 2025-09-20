# Esports Tournament Management Smart Contract

A comprehensive Clarity smart contract for managing esports tournaments on the Stacks blockchain. This contract handles tournament creation, player registration, match management, and automated prize distribution.

## Features

### Core Functionality
- **Tournament Creation**: Organizers can create tournaments with custom entry fees and participant limits
- **Player Registration**: Automatic entry fee collection and participant tracking
- **Match Management**: Create matches, report results, and track tournament progression  
- **Prize Distribution**: Automated prize pool calculation and payout to winners
- **Tournament States**: Complete lifecycle management (Open → Ongoing → Completed/Cancelled)

### Security Features
- Input validation for all user data
- Access control with organizer permissions
- Balance verification before transfers
- Duplicate registration prevention
- Emergency withdrawal for contract owner

## Contract Structure

### Constants
```clarity
max-entry-fee: 1,000,000 microSTX
max-round: 100
max-prize-pool: 100,000,000 microSTX
platform-fee: 5% (configurable)
```

### Tournament Status
- `0` - Open (accepting registrations)
- `1` - Ongoing (matches in progress)
- `2` - Completed (winner declared)
- `3` - Cancelled (refunds available)

## Public Functions

### Tournament Management
- `create-tournament`: Create a new tournament with specified parameters
- `start-tournament`: Begin tournament matches (organizer only)
- `cancel-tournament`: Cancel tournament and enable refunds
- `finalize-tournament`: Complete tournament and distribute prizes

### Player Functions
- `register-for-tournament`: Join tournament and pay entry fee
- `withdraw-refund`: Claim refund from cancelled tournaments

### Match Management
- `create-match`: Create match between two players (organizer only)
- `report-match-result`: Report match winner and eliminate loser

### Administrative
- `set-platform-fee`: Update platform fee percentage (contract owner only)
- `emergency-withdraw`: Emergency fund recovery (contract owner only)

## Usage Examples

### Creating a Tournament
```clarity
(contract-call? .tournament-contract create-tournament 
    "Spring Championship" 
    u10000     ;; 0.01 STX entry fee
    u16        ;; 16 players max
    u1000)     ;; Start at block 1000
```

### Registering for Tournament
```clarity
(contract-call? .tournament-contract register-for-tournament u1)
```

### Creating a Match
```clarity
(contract-call? .tournament-contract create-match 
    u1                    ;; Tournament ID
    'SP1ABC...            ;; Player 1
    'SP2DEF...            ;; Player 2  
    u1)                   ;; Round 1
```

### Reporting Match Results
```clarity
(contract-call? .tournament-contract report-match-result 
    u1                    ;; Match ID
    'SP1ABC...)           ;; Winner
```

## Read-Only Functions

- `get-tournament`: Retrieve tournament details
- `get-match`: Get match information
- `get-user-stats`: View player statistics
- `is-participant`: Check if user is registered
- `get-platform-fee`: Current platform fee percentage

## Prize Distribution

Prizes are automatically distributed when tournaments are finalized:
- **Winner**: 70% of prize pool
- **Runner-up**: 20% of prize pool  
- **Platform Fee**: 5% (configurable)
- **Remaining**: 5% stays in contract

## Error Codes

- `u100` - Owner only operation
- `u101` - Resource not found
- `u102` - Unauthorized access
- `u103` - Invalid state transition
- `u104` - Insufficient funds
- `u105` - Resource already exists
- `u106` - Tournament full
- `u107` - Invalid parameters

## Security Considerations

### Input Validation
All user inputs are validated against maximum limits:
- Entry fees capped at 1M microSTX
- Round numbers limited to 100
- Prize pools capped at 100M microSTX

### Access Control
- Tournament organizers control match creation and results
- Only contract owner can modify platform settings
- Participants can only register for open tournaments

### Fund Safety
- STX transfers use native Clarity functions
- Balance checks before all transfers
- Emergency withdrawal available to contract owner
- Automatic refunds for cancelled tournaments

## Deployment Requirements

- Stacks blockchain testnet/mainnet
- Clarity compiler version 2.0+
- Sufficient STX for contract deployment

## Testing

Recommended test scenarios:
1. Tournament creation with various parameters
2. Player registration and capacity limits
3. Match creation and result reporting
4. Prize distribution calculations
5. Cancellation and refund processes
6. Access control enforcement

