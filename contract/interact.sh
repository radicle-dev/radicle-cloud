#!/bin/bash
export ETH_RPC_URL=https://rinkeby.arbitrum.io/rpc
export ETH_FROM=
export ETH_GAS=1000000000
export RADICLE_CLOUD=

echo "From: $ETH_FROM"
echo "Contract: $RADICLE_CLOUD"

org=$(seth --to-address 0xc1912fee45d61c87cc5ea59dae31190fffff232d)
owner=$(seth --to-address 0xc1912fee45d61c87cc5ea59dae31190fffff232d)

seth send $RADICLE_CLOUD 'buyOrRenew(address,address)' $org $owner --value=200
#seth call $RADICLE_CLOUD 'getPrice()'
#seth call $RADICLE_CLOUD 'dep(address)' $org
#seth send $RADICLE_CLOUD 'cancelDeployment(address)' $org
#seth send $RADICLE_CLOUD 'suspendDeployment(address)' $org
