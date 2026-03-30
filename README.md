# ERC-6909 (Vyper)

Gas-efficient [EIP-6909](https://eips.ethereum.org/EIPS/eip-6909) multi-token implementation in Vyper, with optional metadata, content URI, and total-supply extensions. Core transfers, allowances, and operator semantics follow the standard; the main contract also layers snekmate `ownable` plus minter controls, mint/burn hooks, and helpers described in the NatSpec of [`src/erc6909.vy`](src/erc6909.vy).

## Standards and interfaces

- **ERC-165** — `supportsInterface` via built-in `IERC165`
- **ERC-6909** — [`src/interfaces/IERC6909.vyi`](src/interfaces/IERC6909.vyi)
- **Content URI** — [`src/interfaces/IERC6909ContentURI.vyi`](src/interfaces/IERC6909ContentURI.vyi)
- **Metadata** (`name` / `symbol` / `decimals` per token id) — [`src/interfaces/IERC6909Metadata.vyi`](src/interfaces/IERC6909Metadata.vyi)
- **Token supply** — [`src/interfaces/IERC6909TokenSupply.vyi`](src/interfaces/IERC6909TokenSupply.vyi)

Declared interface IDs are listed in `_SUPPORTED_INTERFACES` in [`src/erc6909.vy`](src/erc6909.vy).

## Layout

| Path | Purpose |
|------|---------|
| [`src/erc6909.vy`](src/erc6909.vy) | Main token implementation |
| [`src/interfaces/`](src/interfaces/) | `.vyi` interface files |
| [`src/mocks/erc6909_mock.vy`](src/mocks/erc6909_mock.vy) | Mock for testing/integration |
| [`moccasin.toml`](moccasin.toml) | Moccasin project config (e.g. snekmate dependency) |

## Tooling

- **Vyper** — `pragma version ~=0.4.3` (see contracts)
- **Moccasin** — project orchestration ([documentation](https://cyfrin.github.io/moccasin))
- **snekmate** — `ownable` module (declared in `moccasin.toml`)

## Development

Compile the project (outputs under `out/`):

```bash
mox compile
```

Run `mox --help` for other commands (`test`, `run`, `deploy`, etc.).

**Note:** The default `script/deploy.py` and `tests/` fixtures still follow the upstream Moccasin Counter template and are not wired to `erc6909`. Until those are updated, use `mox compile` (or a custom script) as the reliable path to build this contract.

## Function selectors (Foundry)

[`cast sig`](https://book.getfoundry.sh/reference/cast/cast-sig) prints each function’s **selector**: the first four bytes of `keccak256` of the canonical ABI signature. Under [EIP-165](https://eips.ethereum.org/EIPS/eip-165), an **interface identifier** is the bitwise XOR of every selector in that interface. The values exposed by `supportsInterface` on this contract are the fixed `bytes4` entries in `_SUPPORTED_INTERFACES` in [`src/erc6909.vy`](src/erc6909.vy), not the output of a single `cast sig` call.

Commands used to generate selectors for the public methods that make up these interfaces:

```bash
# IERC6909 
cast sig "balanceOf(address,uint256)" &&
cast sig "allowance(address,address,uint256)" &&
cast sig "isOperator(address,address)" &&
cast sig "transfer(address,uint256,uint256)" &&
cast sig "transferFrom(address,address,uint256,uint256)" &&
cast sig "approve(address,uint256,uint256)" &&
cast sig "setOperator(address,bool)"
```

```bash
# IERC6909 ContentURI 
cast sig "contractURI()" &&
cast sig "tokenURI(uint256)"
```

```bash
# IERC6909 Metadata 
cast sig "name(uint256)" &&
cast sig "symbol(uint256)" &&
cast sig "decimals(uint256)"
```

```bash
# IERC6909 Token Supply 
cast sig "totalSupply(uint256)"
```
