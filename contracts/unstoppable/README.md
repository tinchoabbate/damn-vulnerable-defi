# Challenge #1 - Unstoppable

There's a lending pool with a million DVT tokens in balance, offering flash loans for free.

If only there was a way to attack and stop the pool from offering flash loans ...

You start with 100 DVT tokens in balance.

## Solution:

Make the check at line 40 fail. We can simply transfer some tokens to the pool so the internal accounting `poolBalance` does not get updated but the actual pool balance in the token's contract will.