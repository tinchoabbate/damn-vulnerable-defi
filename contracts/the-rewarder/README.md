# Challenge #5 - The rewarder

There's a pool offering rewards in tokens every 5 days for those who deposit their DVT tokens into it.

Alice, Bob, Charlie and David have already deposited some DVT tokens, and have won their rewards!

You don't have any DVT tokens. But in the upcoming round, you must claim most rewards for yourself.

Oh, by the way, rumours say a new pool has just landed on mainnet. Isn't it offering DVT tokens in flash loans? 

## Solution:

The issue here is that the snapshot is taken right after the ``mint``, so any deposit when ``isNewRewardsRound()`` returns true will be accounted for in a round it should not belong to. So adding liquidity then will 

#### State of the ``AccountingToken`` before the attack:
Snapshots:
```
    currentSnapshotId = 2
    _accountBalanceSnapshots[Alice]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Bob]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Charlie]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[David]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[attacker]:
        ids         = []
        values      = []

    _totalSupplySnapshots:
        ids         = [1]
        values      = [0]
```

Balances:
```
    balances[Alice]     = 100
    balances[Bob]       = 100
    balances[Charlie]   = 100
    balances[David]     = 100
    balances[attacker]  = 0
```

Total supply = ``400``.

Querying ``balanceOfAt({Alice,Bob,Charlie or David}, currentSnapshotId) == 100`` and ``balanceOfAt(attacker, currentSnapshotId) == 0``

### The attack:

The attacker wait for ``isNewRewardsRound()==true`` and does flashmint for amount ``X`` -> deposits -> withdraws -> repay flash loan.

#### State of the ``AccountingToken`` after the attacker calls ``deposit(X)``:
Snapshots:
```
    currentSnapshotId = 3
    _accountBalanceSnapshots[Alice]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Bob]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Charlie]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[David]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[attacker]:
        ids         = [2]
        values      = [0]

    _totalSupplySnapshots:
        ids         = [1,  2 ]
        values      = [0, 400]
```

Balances:
```
    balances[Alice]     = 100
    balances[Bob]       = 100
    balances[Charlie]   = 100
    balances[David]     = 100
    balances[attacker]  = X
```

Total supply = ``400+X``.

#### State of the ``AccountingToken`` after the attack:
Snapshots:
```
    currentSnapshotId = 3
    _accountBalanceSnapshots[Alice]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Bob]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[Charlie]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[David]:
        ids         = [1]
        values      = [0]
    _accountBalanceSnapshots[attacker]:
        ids         = [2, 3]
        values      = [0, X]

    _totalSupplySnapshots:
        ids         = [1,  2 ,   3  ]
        values      = [0, 400, 400+X]
```

Balances:
```
    balances[Alice]     = 100
    balances[Bob]       = 100
    balances[Charlie]   = 100
    balances[David]     = 100
    balances[attacker]  = 0
```

Total supply = ``400``.

During the ``deposit(X)`` phase, the snapshot of the attacker is ``Snapshot(ids=[2], values=[0])`` and currentSnapshotId is incremented to 3, so querying for ``balanceOfAt(attacker, 3)`` will return ``X`` for the amount to be accounted for rewards distribution, and the shares of the other participants gets diluted in the massive increase of total token supply ``400+X``. So for roundNumber 3, the attacker will get ``X/(400+X)`` reward tokens and each normal participant will get ``100/(400+X)``.

The correct way to to it would be to first distribute the rewards and then mint the ``AccountingToken``.