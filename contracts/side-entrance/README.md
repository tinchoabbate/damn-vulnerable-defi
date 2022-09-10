# Challenge #4 - Side entrance

A surprisingly simple lending pool allows anyone to deposit ETH, and withdraw it at any point in time.

This very simple lending pool has 1000 ETH in balance already, and is offering free flash loans using the deposited ETH to promote their system.

You must take all ETH from the lending pool.

## Solution:

`flashLoan` only checks that the overall balance of the contract is sound after the `execute` hook. We can then reinvest the amount we get with `flashLoan` in the contract by depositing that amount, that is then accounted for us, and the overall balance of the contract is sound. After `flashLoan` we can redeem the deposited amount and drain the contract.