# tangible_assignement

## Contracts

- TNFT - TangibleREstate (RLTY): 0x29613FbD3e695a669C647597CEFd60bA255cc1F8

## Some edge cases out of the scope of this assignment

1. In the case of a "bank run", latest creditors could be stuck. Let's illustrate:
 - user A deposits a property worth $90k -> gets 90k $ReUSD (100% of supply)
 - user B deposits a property worth $210k -> gets 210k $ReUSD (70% of supply)
 - user C deposits a property worth $300k -> gets 300k $ReUSD (50% of supply)
 - over time, $60k of rent is deposited in the contract -> total supply 660k
 - user D deposits a property worth $270k -> gets 270k $ReUSD (~29% of supply)
 - contract now holds 4 properties and $60k stables from rent
 - shares:
   - user A ~99k $ReUSD (~10.6%)
   - user B ~231k $ReUSD (~24.9%)
   - user C 330k $ReUSD (~35.5%)
   - user D 270k $ReUSD (~29%)
 - user C decides to redeem his assets claiming $60k stables from rent plus the $270k TNFT
 - now there is a situation where:
   - the contract holds three TFNTs valued 90k, 210k and 300k
   - the contract doesn't hold any stable
   - there are three claims for $99k, $231k and $270k
 - two users could claim the TFNTs of lower values and take a haircut, but the third user would be stuck
 - a solution to this problem would be to allow redeems to be made by "topping up" in a combination of erc20 + stable to cover the rent that was taken by another user
 - another solution would be to cap the upper limit of rent money that can be redeemed to the amount that was accrued by the TNFT provided by each user, but it requires more computations, variables, and ultimately, gas
