<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="vyper-logo-dark.png">
    <img src="vyper-logo.png" width="140" alt="Vyper logo">
  </picture>
</p>

# erc-6909-vyper

Gas-efficient, extended Vyper module for the [EIP-6909](https://eips.ethereum.org/EIPS/eip-6909): a minimal multi-token standard with optional **metadata**, **content URI**, and **total supply** extensions. The main contract composes multiple `.vyi` interfaces and [snekmate](https://github.com/pcaversaccio/snekmate) `ownable`, adds minter controls, mint/burn hooks, and helpers documented in the NatSpec of [`src/erc6909.vy`](src/erc6909.vy).

## Contracts

| Path | Description |
|------|-------------|
| [`src/erc6909.vy`](src/erc6909.vy) | Main token implementation (ERC-165, ERC-6909, extensions, ownable, minter hooks) |
| [`src/interfaces/IERC6909.vyi`](src/interfaces/IERC6909.vyi) | Core ERC-6909 interface |
| [`src/interfaces/IERC6909ContentURI.vyi`](src/interfaces/IERC6909ContentURI.vyi) | Content URI extension |
| [`src/interfaces/IERC6909Metadata.vyi`](src/interfaces/IERC6909Metadata.vyi) | Metadata extension |
| [`src/interfaces/IERC6909TokenSupply.vyi`](src/interfaces/IERC6909TokenSupply.vyi) | Token supply extension |
| [`src/mocks/erc6909_mock.vy`](src/mocks/erc6909_mock.vy) | Mock that initialises the module (used by tests and [`script/deploy.py`](script/deploy.py)) |
| [`moccasin.toml`](moccasin.toml) | Moccasin project config (e.g. snekmate dependency, networks) |

**Standards:** [EIP-165](https://eips.ethereum.org/EIPS/eip-165) via built-in `IERC165`; EIP-6909 and the optional extensions above. Declared interface IDs are listed in `_SUPPORTED_INTERFACES` in [`src/erc6909.vy`](src/erc6909.vy).

## Dependencies

- [Vyper](https://docs.vyperlang.org/) `~=0.4.3` (see contract pragmas)
- [Moccasin](https://github.com/Cyfrin/moccasin) (build, test, deploy)
- [snekmate](https://github.com/pcaversaccio/snekmate) `>=0.1.2` (`ownable` module)
- [Titanoboa](https://github.com/vyperlang/titanoboa) (`boa`, test backend via Moccasin)

## Install

```bash
pip install moccasin
mox install
```



## Build

```bash
mox compile
```

Artifacts are written under `out/`.

## Test

```bash
mox test
```

[`tests/conftest.py`](tests/conftest.py) deploys [`src/mocks/erc6909_mock.vy`](src/mocks/erc6909_mock.vy) via [`script/deploy.py`](script/deploy.py). The mock wraps the [`src/erc6909.vy`](src/erc6909.vy) module for a concrete constructor and tests; production deployment of the bare module differs (constructor/initialisation per your integration).

## Deploy

```bash
mox run deploy
```

Deploys the mock from [`script/deploy.py`](script/deploy.py) (see `base_uri` / `contract_uri` there). For a live network, add or use a `[networks.*]` section in [`moccasin.toml`](moccasin.toml) and run:

```bash
mox run deploy --network <network-name> --account <keystore>
```

## EIP-165 interface identifiers

[`supportsInterface(bytes4)`](https://eips.ethereum.org/EIPS/eip-165) must return **true** for each **interface identifier** (EIP-165 `bytes4` ID) the contract implements. Per [EIP-165](https://eips.ethereum.org/EIPS/eip-165), an interface identifier is the bitwise XOR of the **[function selectors](https://docs.soliditylang.org/en/latest/abi-spec.html#function-selector)** (first four bytes of `keccak256` of the canonical ABI signature) of every function declared in that interface.

The **authoritative** values this contract advertises are the fixed `bytes4` entries in `_SUPPORTED_INTERFACES` in [`src/erc6909.vy`](src/erc6909.vy). They are **not** the output of a single [`cast sig`](https://book.getfoundry.sh/reference/cast/cast-sig) call.

### Verifying selectors (Foundry)

[`cast sig`](https://book.getfoundry.sh/reference/cast/cast-sig) prints each function’s **selector**. To cross-check an interface ID, XOR **all** selectors in that interface; the result must match the corresponding entry in `_SUPPORTED_INTERFACES` (XOR is associative and commutative, so order does not matter).

**IERC6909**

```bash
cast sig "balanceOf(address,uint256)" &&
cast sig "allowance(address,address,uint256)" &&
cast sig "isOperator(address,address)" &&
cast sig "transfer(address,uint256,uint256)" &&
cast sig "transferFrom(address,address,uint256,uint256)" &&
cast sig "approve(address,uint256,uint256)" &&
cast sig "setOperator(address,bool)"
```

**IERC6909 ContentURI**

```bash
cast sig "contractURI()" &&
cast sig "tokenURI(uint256)"
```

**IERC6909 Metadata**

```bash
cast sig "name(uint256)" &&
cast sig "symbol(uint256)" &&
cast sig "decimals(uint256)"
```

**IERC6909 TokenSupply**

```bash
cast sig "totalSupply(uint256)"
```

## Reference

- [EIP-6909: Multi-Token](https://eips.ethereum.org/EIPS/eip-6909)
- [EIP-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165)
- [Moccasin documentation](https://cyfrin.github.io/moccasin)
- [OpenZeppelin ERC-1155](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol) (design inspiration noted in contract NatSpec)

---

*This is an unaudited reference implementation for educational and development purposes. It is not production-ready software. Use at your own risk. The authors accept no liability for losses or damages arising from its use or deployment. Contract headers license the code under GNU Affero General Public License v3.0 only.*
