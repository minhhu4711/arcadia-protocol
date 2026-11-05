# Deployment (testnet only)

Do not deploy to mainnet from this repository. Testnet deployment needs explicit operator approval.

## Contracts

The contracts are already deployed on Arc Testnet (see `AGENTS.md`). To redeploy yourself:

```bash
export ADMIN_ADDRESS=0x...        # wallet that receives all admin roles
export USDC_ADDRESS=0x...         # verify against the Arc docs
cast wallet import deployer --interactive
forge script contracts/script/DeployArcadia.s.sol \
  --rpc-url $ARC_TESTNET_RPC_URL --account deployer --broadcast
```

The script deploys the risk manager, rate model, factory (which creates the USDC market in its constructor) and the vault. No follow-up configuration is needed: roles and limits are set in the constructors.

## Web app

1. Copy `.env.example` to `.env` and fill the three `VITE_ARCADIA_*` values.
2. `bun install && bunx vite build`, or build the container:

```bash
docker build -t arcadia-web \
  --build-arg VITE_ARCADIA_FACTORY=0x... \
  --build-arg VITE_ARCADIA_VAULT=0x... \
  --build-arg VITE_ARCADIA_DEPLOY_BLOCK=123 .
docker run -p 8080:80 arcadia-web
```

Never put private keys in a `VITE_` variable.

## CI

`.github/workflows/ci.yml` builds and tests the contracts (with a gas report), then lints, typechecks, tests and builds the web app.

## Not yet available

Backend API, database and indexer deployment arrive with Phases 4 and 5. Contract source verification on the explorer is not automated here.
