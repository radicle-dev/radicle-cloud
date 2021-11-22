#!/bin/bash
export ETH_RPC_URL=https://rinkeby.arbitrum.io/rpc
export ETH_FROM=
export ETH_GAS=1000000000

echo "From: $ETH_FROM"

price=$(seth --to-uint256 1)
duration=$(seth --to-uint256 200)
owner=$(seth --to-address $ETH_FROM)

dapp create EthRadicleCloud $price $duration $owner
