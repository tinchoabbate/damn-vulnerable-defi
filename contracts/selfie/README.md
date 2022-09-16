# Challenge #6 - Selfie

A new cool lending pool has launched! It's now offering flash loans of DVT tokens.

Wow, and it even includes a really fancy governance mechanism to control it.

What could go wrong, right ?

You start with no DVT tokens in balance, and the pool has 1.5 million. Your objective: take them all.

## Solution:

The pool allows to flashloan governance tokens, which can grant some governance rights, like executing an action on behalf of the ``SimpleGovernance`` contract for example :smirk:. To do so we take a flashloan with the full available amount to have more than 50% of voting power, and then:

    1. Take a snapshot of our balance that the governance contract will query to check whether we have enough tokens to queue a governance action
    2. Queue the action ``SelfiePool.drainAllFunds(attacker)``
    3. Repay the flashloan and wait for 2 days to let pass the execution delay
    4. Execute the action and profit
