# Challenge #3 - Truster

More and more lending pools are offering flash loans. In this case, a new pool has launched that is offering flash loans of DVT tokens for free.

Currently the pool has 1 million DVT tokens in balance. And you have nothing.

But don't worry, you might be able to take them all from the pool. In a single transaction.

## Solution:

`target.functionCall(data)` is extremely dangerous since it allows the caller to achieve actions on the behalf of the contract. So we will leverage this and take a flash loan of 0 but approve the caller with the balance of the pool, so we can transfer the tokens after the loan has been repaid. I.e., in the `target.functionCall(data)` we set `target:=address(damnValuableToken)` and `data:=abi.encodeWithSignature("approve(address,uint256)", address(this), damnValuableToken.balanceOf(pool))`, and we transferFrom the pool to the attacker since we have the approval.