# tangible_assignement

## Intro

The aim of this assignment is to design and implement a mechanism to price a basket of assets, in this case real estate
properties. As each property is represented by a TFNT (ERC721, enumerable), we assume that a large amount can exist at
the same time, and the pricing needs to be efficient in this case.

For the sake of the assignment we will only consider two elements when pricing a property: its value, and monthly rent,
and will exclude other metrics from TPV such as taxes, insurances and fees.

The production design includes a vault that collects and deposits rent on a daily basis, but we will instead
use a system similar to liquidity mining where the rent money is deposited in the vault, and the money vests linearly
and can be claimed whenever convenient, to replicate the future production design.

## Design choices

As users will mint and redeem regularly, the value of the basket need to be kept up to date very often. I can see two
options in order to determine the value of the basket:
- the value of the basket is computed on the fly every time there is a mint or a redemption
- the value of the basket is stored inside the contract, and updated whenever there is a change to it

The issue with the first option is that as the value depends on all the TNFTs, storage will be read extensively and the
gas cost will be high, and will most likely eventually brick.

The design used here relies on the fact that there is an inherent element of trust in the oracle system. Since off chain
data will be broadcasted into the oracle contract, every one of these transactions will also update on the fly the price
of the basket itself if the TFNT is part of the basket. That way the gas is subsidized by the oracle operator, and every
update on the basket is processed only once.

The basket will keep track of the total values of the TNFTs held, as well as the ever-increasing rent of said
properties. If any of these data is updated in the oracle, only the delta will need to be updated in the basket. When
users mint using a TFNT, the oracle is queried to fetch the TPV, and that value is added to the current basket total
price. When a user redeems his tokens, the oracle is queried again, the TPV deducted from the total value of
the basket, and the property rent removed from the vault.

The Vault contract keeps track of the rental amount owed by the tenants. The current version is a very crude
implementation that assumes that only properties paying rent are part of the basket, as the basket will query the
outstanding balance to compute the price during a mint or redeem. Another possible implementation would allow rent
collecting for every TNFT, basket or not, in which case the rental amount will also be stored in the ReUSD contract
and computed to exclude the outstanding rent from non-basket properties.

## Contracts

- TNFT - TangibleREstate (RLTY): 0x29613FbD3e695a669C647597CEFd60bA255cc1F8

## Potential edge case

1. In the case of a "bank run", latest creditors could be stuck. This example assumes that the user can choose the split
between rent and TFNT value, but the edge case also works if the split is set beforehand. Let's illustrate:
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
 - a solution to this problem would be to allow redeems to be made by "topping up" in a combination of erc20 + stable to
cover the rent that was taken by another user
 - another solution would be to cap the upper limit of rent money that can be redeemed to the amount that was accrued by
the TNFT provided by each user, but it requires more computations, variables, and ultimately, gas
