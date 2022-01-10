# 🌱 Radicle Cloud :cloud:

This repository includes the operator and the contracts you need to become a service provider for Radicle seed nodes.

## Contract

You can deploy ETH and ERC-20 based contracts located inside [contract](contract/) and then point your operator to your deployed contract. An example script is provided for you in [deploy.sh](contract/deploy.sh) which deploys [EthRadicleCloud.sol](contract/src/EthRadicleCloud.sol) to Arbitrum Rinkeby Testnet. You can change network by changing `ETH_RPC_URL`. You must have [dapp.tools](https://github.com/dapphub/dapptools) installed.

**IMPORTANT:** replace `ETH_FROM` with your own wallet and make sure the key can be found in your local keystore. If you want to import a private key, use:

```
$ geth account import /path/to/private-key
```

Finally, make `CONTRACT_ADDRESS` point to your own deployed contract in `.env.operator`.

## Deploy Operator

You can deploy operator with Ansible after filling in your `.env.operator`, which you can sample from [`.env.sample`](.env.sample).

### SSH Key

Generate an SSH key for your operator, if you already don't have one, with:

```
$ ssh-keygen -t ed25519
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user/.ssh/id_ed25519): cloud-operator
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in cloud-operator.
Your public key has been saved in cloud-operator.pub.
The key fingerprint is:
SHA256:... user@host
The key's randomart image is:
+--[ED25519 256]--+
|                 |
|                 |
|       ...       |
+----[SHA256]-----+
```

Upload the pub key to your cloud, e.g. Hetzner and add the name (`HETNZER_SSH_NAME`) to your `.env.operator` file.


### Deploying

Make sure your private SSH key can be found locally in `~/.ssh/local_ssh_name` and that `LOCAL_SSH_PATH` in `.env.operator` file matches:

```
# .env.operator (truncated)
LOCAL_SSH_PATH=~/.ssh/cloud-operator
```

Finally:

```
$ ansible-playbook ansible/deploy-operator.yml --inventory=root@x.x.x.x, --private-key=~/.ssh/key-to-server --extra-vars="local_ssh_name=cloud-operator db_name=radicle db_user=postgres db_password=postgres"
```

### `.env`

| Name                   | Description           |
| ---------------------- | ---------------------------------------------------------------------------------------------- |
| `HETNZER_TOKEN`        | Hetzner Cloud API Token                                                                        |
| `HETNZER_SSH_NAME`     | Name of the SSH Key you created in your Hetzner Console                                        |
| `LOCAL_SSH_PATH`       | Path where operator can access SSH Key which is in cloud as well e.g. `~/.ssh/cloud-operator`  |
| `POSTGRES`             | Postgres connection URL e.g. `postgres://postgres:postgres@localhost:5432/radicle`             |
| `CONTRACT_L2_WSS`      | e.g. `wss://arb-rinkeby.g.alchemy.com/v2/...` (if you're not on L2, just use same value as L1) | 
| `CONTRACT_L1_WSS`      | e.g. `wss://eth-rinkeby.alchemyapi.io/v2/...` (needed even if you're on L2)                    |
| `CONTRACT_ADDRESS`     | Address of the contract that you've deployed e.g. `0x...`                                      |
| `RAD_SUBGRAPH`         | Corresponds to `--subgraph` when running [`org-node`](https://github.com/radicle-dev/radicle-client-services/#running) |
| `RAD_RPC_URL`          | Corresponds to `--rpc-url` when running [`org-node`](https://github.com/radicle-dev/radicle-client-services/#running)  |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API Token with DNS access                                                           |
| `CLOUDFLARE_DOMAIN`    | Domain on Cloudflare which will be used to give out FQDNs e.g. `domain.tld`                    |