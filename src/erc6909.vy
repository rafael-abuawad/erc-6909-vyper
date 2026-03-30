# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title Modern and Gas-Efficient ERC-6909 Implementation
@custom:contract-name erc6909
@license GNU Affero General Public License v3.0 only
@author rafael-abuawad
@notice ERC-6909 multi-token contract with optional metadata, content-URI, and total-supply
        extensions (https://eips.ethereum.org/EIPS/eip-6909). Adds snekmate `ownable`, a minter
        role, `create` / `mint` / `burn`, URI helpers, and no-op transfer hooks for extensions.
"""


# Built-in ERC-165 plus project interfaces for ERC-6909 and its optional extensions.
from ethereum.ercs import IERC165
implements: IERC165


from .interfaces import IERC6909
implements: IERC6909


from .interfaces import IERC6909ContentURI
implements: IERC6909ContentURI


from .interfaces import IERC6909Metadata
implements: IERC6909Metadata


from .interfaces import IERC6909TokenSupply
implements: IERC6909TokenSupply


from snekmate.auth import ownable
uses: ownable


exports: (ownable.owner,)


_SUPPORTED_INTERFACES: constant(bytes4[5]) = [
    0x01FFC9A7,  # ERC-165
    0x0f632fb3,  # ERC-6909 core
    0x20d88258,  # ERC-6909 content URI extension
    0x71abc795,  # ERC-6909 metadata extension
    0xbd85b039,  # ERC-6909 token supply extension
]


_BASE_URI: immutable(String[80])
_CONTRACT_URI: immutable(String[512])


_balances: HashMap[address, HashMap[uint256, uint256]]
_allowances: HashMap[address, HashMap[address, HashMap[uint256, uint256]]]
_operator_approvals: HashMap[address, HashMap[address, bool]]
_total_supply: HashMap[uint256, uint256]
_token_metadata: HashMap[uint256, TokenMetadata]
_token_uris: HashMap[uint256, String[432]]
_counter: uint256
_is_minter: HashMap[address, bool]


struct TokenMetadata:
    name: String[25]
    symbol: String[5]
    decimals: uint8


# @dev Emitted when the status of a `minter`
# address is changed.
event RoleMinterChanged:
    minter: indexed(address)
    status: bool


# Emitted when a new token id is created with metadata.
event ERC6909MetadataSet:
    id: indexed(uint256)
    name: String[25]
    symbol: String[5]
    decimals: uint8


@deploy
@payable
def __init__(base_uri_: String[80], contract_uri_: String[512]):
    """
    @dev `payable` avoids extra `msg.value` checks in the creation bytecode.
    @notice `ownable` assigns `owner` to `msg.sender`; deployer is also initial minter.
    @param base_uri_ Optional prefix for `tokenURI` (see `_token_uri`); max 80 chars.
    @param contract_uri_ Value returned by `contractURI`; max 512 chars.
    """
    _BASE_URI = base_uri_
    _CONTRACT_URI = contract_uri_

    self._counter = empty(uint256)
    self._is_minter[msg.sender] = True
    log RoleMinterChanged(minter=msg.sender, status=True)


@external
@view
def supportsInterface(interface_id: bytes4) -> bool:
    """
    @dev ERC-165 `supportsInterface`.
    @param interface_id EIP-165 interface id.
    @return bool Whether this contract supports `interface_id`.
    """
    return interface_id in _SUPPORTED_INTERFACES


@external
@view
def name(id: uint256) -> String[25]:
    """
    @dev Metadata extension: name for `id`.
    @param id Token id.
    @return String Name (max 25 chars).
    """
    return self._token_metadata[id].name


@external
@view
def symbol(id: uint256) -> String[5]:
    """
    @dev Metadata extension: symbol for `id`.
    @param id Token id.
    @return String Symbol (max 5 chars).
    """
    return self._token_metadata[id].symbol


@external
@view
def decimals(id: uint256) -> uint8:
    """
    @dev Metadata extension: decimals for `id`.
    @param id Token id.
    @return uint8 Decimals.
    """
    return self._token_metadata[id].decimals


@external
@view
def balanceOf(owner: address, id: uint256) -> uint256:
    """
    @dev Balance of `id` for `owner` (EIP-6909).
    @param owner Account holding tokens.
    @param id Token id.
    @return uint256 Balance.
    """
    return self._balances[owner][id]


@external
@view
def allowance(owner: address, spender: address, id: uint256) -> uint256:
    """
    @dev Allowance of `spender` for `id` on behalf of `owner` (EIP-6909).
    @param owner Token holder.
    @param spender Delegated spender.
    @param id Token id.
    @return uint256 Allowance amount.
    """
    return self._allowances[owner][spender][id]


@external
@view
def isOperator(owner: address, operator: address) -> bool:
    """
    @dev Whether `operator` may move any `id` for `owner` (EIP-6909).
    @param owner Token holder.
    @param operator Operator account.
    @return bool Approved operator status.
    """
    return self._operator_approvals[owner][operator]


@external
@view
def contractURI() -> String[512]:
    """
    @dev Content-URI extension: contract-level metadata URI.
    @return String URI (immutable, max 512 chars).
    """
    return _CONTRACT_URI


@external
@view
def tokenURI(id: uint256) -> String[512]:
    """
    @dev Content-URI extension: URI for `id` (base + per-token segment; see `_token_uri`).
    @notice Clients replace `{id}` in the returned string if present (EIP-6909). MAY revert or
            return data for nonexistent ids per extension semantics.
    @param id Token id.
    @return String Full URI (max 512 chars).
    """
    return self._token_uri(id)


@external
@view
def totalSupply(id: uint256) -> uint256:
    """
    @dev Token supply extension: `totalSupply` for `id`.
    @param id Token id.
    @return uint256 Supply after mints minus burns.
    """
    return self._total_supply[id]


@external
@view
def exists(id: uint256) -> bool:
    """
    @dev Convenience: `True` iff `totalSupply(id) != 0` (this implementation).
    @param id Token id.
    @return bool Whether supply has ever been positive.
    """
    return self._total_supply[id] != empty(uint256)


@external
@view
def is_minter(minter: address) -> bool:
    """
    @dev Whether `minter` is authorized to mint tokens.
    @param minter Address to check.
    @return bool Authorization status.
    """
    return self._is_minter[minter]


@external
def transfer(to: address, id: uint256, amount: uint256) -> bool:
    """
    @dev EIP-6909 `transfer`: caller sends `amount` of `id` to `to`.
    @notice Reverts on insufficient balance; this implementation forbids zero `to` (`_transfer`).
    @param to Recipient.
    @param id Token id.
    @param amount Amount moved.
    @return bool `True` per EIP-6909.
    """
    self._transfer(msg.sender, to, id, amount, msg.sender)
    return True


@external
def transferFrom(
    owner: address, to: address, id: uint256, amount: uint256
) -> bool:
    """
    @dev EIP-6909 `transferFrom`: moves `amount` of `id` from `owner` to `to`.
    @notice Caller must be `owner`, an operator, or have sufficient allowance. Allowance is
            skipped for self/operator; infinite allowance (`max_value(uint256)`) is not reduced.
            Reverts on insufficient balance; zero `to` is disallowed (`_transfer`).
    @param owner Debited account.
    @param to Recipient.
    @param id Token id.
    @param amount Amount moved.
    @return bool `True` per EIP-6909.
    """
    if msg.sender != owner:
        if not self._operator_approvals[owner][msg.sender]:
            self._spend_allowance(owner, msg.sender, id, amount)
    self._transfer(owner, to, id, amount, msg.sender)
    return True


@external
def approve(spender: address, id: uint256, amount: uint256) -> bool:
    """
    @dev EIP-6909 `approve`; emits `Approval`.
    @notice zero address checks on `spender` reverts (`_approve`).
    @param spender Delegate.
    @param id Token id.
    @param amount New allowance.
    @return bool `True` per EIP-6909.
    """
    self._approve(msg.sender, spender, id, amount)
    return True


@external
def setOperator(operator: address, approved: bool) -> bool:
    """
    @dev EIP-6909 `setOperator`; emits `OperatorSet`.
    @param operator Account to approve or revoke.
    @param approved New operator flag.
    @return bool `True` per EIP-6909.
    """
    self._operator_approvals[msg.sender][operator] = approved
    log IERC6909.OperatorSet(
        _owner=msg.sender, _operator=operator, _approved=approved
    )
    return True


@external
def set_token_uri(id: uint256, token_uri: String[432]):
    """
    @dev Sets per-token URI segment (concatenated with immutable `_BASE_URI` in `tokenURI`).
    @notice Minters only; independent of mint timing.
    @param id Token id.
    @param token_uri Suffix segment (max 432 chars).
    """
    assert self._is_minter[msg.sender], "erc6909: access is denied"
    self._set_token_uri(id, token_uri)


@external
def burn(id: uint256, amount: uint256):
    """
    @dev Burns `amount` of `id` from caller; decreases total supply.
    @param id Token id.
    @param amount Amount burned.
    """
    self._burn(msg.sender, id, amount)


@external
def burn_from(owner: address, id: uint256, amount: uint256):
    """
    @dev Burns `amount` of `id` from `owner` using caller's allowance (`_spend_allowance` then `_burn`).
    @notice Does not grant operator bypass; allowance must cover the burn.
    @param owner Debited account.
    @param id Token id.
    @param amount Amount burned.
    """
    self._spend_allowance(owner, msg.sender, id, amount)
    self._burn(owner, id, amount)


@external
def create(name: String[25], symbol: String[5], decimals: uint8) -> uint256:
    """
    @dev Allocates the next id, stores metadata, emits `ERC6909MetadataSet`.
    @notice Minters only.
    @return uint256 New token id.
    """
    assert self._is_minter[msg.sender], "erc6909: access is denied"
    token_id: uint256 = self._counter
    self._counter = token_id + 1
    self._token_metadata[token_id] = TokenMetadata(
        name=name, symbol=symbol, decimals=decimals
    )
    log ERC6909MetadataSet(
        id=token_id, name=name, symbol=symbol, decimals=decimals
    )
    return token_id


@external
def mint(owner: address, id: uint256, amount: uint256) -> uint256:
    """
    @dev Minter-only mint to `owner` for existing `id`.
    @notice zero address checks on `owner` reverts (`_mint`).
    @param owner Recipient.
    @param id Token id.
    @param amount Amount created.
    @return uint256 `id` for convenience.
    """
    assert self._is_minter[msg.sender], "erc6909: access is denied"
    self._mint(owner, id, amount)
    return id


@external
def set_minter(minter: address, status: bool):
    """
    @dev Owner-only minter flag. Cannot target zero address or the owner (`msg.sender`).
    @param minter Address receiving minter role change.
    @param status `True` to grant, `False` to revoke.
    """
    ownable._check_owner()
    assert minter != empty(address), "erc6909: minter is the zero address"
    assert minter != msg.sender, "erc6909: minter is owner address"
    self._is_minter[minter] = status
    log RoleMinterChanged(minter=minter, status=status)


@external
def transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner`.
    @notice Note that this function can only be
            called by the current `owner`. Also,
            the `new_owner` cannot be the zero address.

            WARNING: The ownership transfer also removes
            the previous owner's minter role and assigns
            the minter role to `new_owner` accordingly.
    @param new_owner The 20-byte address of the new owner.
    """
    ownable._check_owner()
    assert new_owner != empty(address), "erc6909: new owner is the zero address"

    self._is_minter[msg.sender] = False
    log RoleMinterChanged(minter=msg.sender, status=False)

    ownable._transfer_ownership(new_owner)
    self._is_minter[new_owner] = True
    log RoleMinterChanged(minter=new_owner, status=True)


@external
def renounce_ownership():
    """
    @dev Sets owner to zero and strips caller's minter flag (snekmate `renounce_ownership` path).
    @notice Other minters remain able to mint; revoke them via `set_minter` first if undesired.
    """
    ownable._check_owner()
    self._is_minter[msg.sender] = False
    log RoleMinterChanged(minter=msg.sender, status=False)
    ownable._transfer_ownership(empty(address))


@internal
def _before_token_transfer(
    owner: address, to: address, id: uint256, amount: uint256
):
    """
    @dev Pre-transfer hook; no-op (override in a derived contract if needed).
    """
    pass


@internal
def _after_token_transfer(
    owner: address, to: address, id: uint256, amount: uint256
):
    """
    @dev Post-transfer hook; no-op (override in a derived contract if needed).
    """
    pass


@internal
def _mint(owner: address, id: uint256, amount: uint256):
    """
    @dev Increases `_total_supply` and `_balances`; emits mint-shaped `Transfer` (`_from` zero).
    @notice zero address checks on `owner` reverts. `_caller` in the event is zero (internal path).
    """
    assert owner != empty(address), "erc20: mint to the zero address"

    self._before_token_transfer(empty(address), owner, id, amount)

    self._total_supply[id] = unsafe_add(self._total_supply[id], amount)
    self._balances[owner][id] = unsafe_add(self._balances[owner][id], amount)
    log IERC6909.Transfer(
        _caller=empty(address),
        _from=empty(address),
        _to=owner,
        _id=id,
        _value=amount,
    )

    self._after_token_transfer(empty(address), owner, id, amount)


@internal
def _burn(owner: address, id: uint256, amount: uint256):
    """
    @dev Decreases balance and supply; emits burn-shaped `Transfer` (`_to` zero).
    @notice zero address checks on `owner` reverts; `amount` must not exceed balance.
    """
    assert owner != empty(address), "erc20: burn from the zero address"

    self._before_token_transfer(owner, empty(address), id, amount)

    account_balance: uint256 = self._balances[owner][id]
    assert account_balance >= amount, "erc6909: burn amount exceeds balance"
    self._balances[owner][id] = unsafe_sub(account_balance, amount)
    self._total_supply[id] = unsafe_sub(self._total_supply[id], amount)
    log IERC6909.Transfer(
        _caller=owner, _from=owner, _to=empty(address), _id=id, _value=amount
    )

    self._after_token_transfer(owner, empty(address), id, amount)


@internal
def _approve(owner: address, spender: address, id: uint256, amount: uint256):
    """
    @dev Writes allowance and emits `Approval`
    @notice zero address checks on `owner` or `spender` reverts.
    """
    assert owner != empty(address), "erc6909: approve from the zero address"
    assert spender != empty(address), "erc6909: approve to the zero address"

    self._allowances[owner][spender][id] = amount
    log IERC6909.Approval(_owner=owner, _spender=spender, _id=id, _value=amount)


@internal
def _transfer(
    owner: address, to: address, id: uint256, amount: uint256, caller: address
):
    """
    @dev Core transfer: hooks, balance checks, `Transfer` with `_caller` as given (typically `msg.sender`).
    @notice Zero address checks on `owner` or `to` reverts.
    """
    assert owner != empty(address), "erc6909: transfer from the zero address"
    assert to != empty(address), "erc6909: transfer to the zero address"

    self._before_token_transfer(owner, to, id, amount)

    owner_balance: uint256 = self._balances[owner][id]
    assert owner_balance >= amount, "erc6909: transfer amount exceeds balance"
    self._balances[owner][id] = unsafe_sub(owner_balance, amount)
    self._balances[to][id] = unsafe_add(self._balances[to][id], amount)
    log IERC6909.Transfer(
        _caller=caller, _from=owner, _to=to, _id=id, _value=amount
    )

    self._after_token_transfer(owner, to, id, amount)


@internal
def _spend_allowance(
    owner: address, spender: address, id: uint256, amount: uint256
):
    """
    @dev Pulls `amount` from `(owner, spender, id)` allowance unless unlimited.
    @notice No-op on `max_value(uint256)`; otherwise requires `allowance >= amount` then subtracts.
    """
    current_allowance: uint256 = self._allowances[owner][spender][id]
    if current_allowance < max_value(uint256):
        # Allows `transferFrom` with `amount == 0` from any `msg.sender` (zero decrement allowed).
        assert current_allowance >= amount, "erc6909: insufficient allowance"
        self._approve(owner, spender, id, unsafe_sub(current_allowance, amount))


@internal
def _set_token_uri(id: uint256, token_uri: String[432]):
    """
    @dev Stores per-id URI segment; callers must enforce auth (e.g. `set_token_uri`).
    """
    self._token_uris[id] = token_uri


@internal
@view
def _token_uri(id: uint256) -> String[512]:
    """
    @dev Builds full `tokenURI`: `token_uri` only, or `base || token_uri`, or `base || dec(id)` fallback.
    @notice If `_BASE_URI` contains `{id}`, consider returning it verbatim per EIP client substitution.
    """
    token_uri: String[432] = self._token_uris[id]

    base_uri_length: uint256 = len(_BASE_URI)
    if base_uri_length == empty(uint256):
        return token_uri
    elif len(token_uri) != empty(uint256):
        return concat(_BASE_URI, token_uri)
    elif base_uri_length != empty(uint256):
        return concat(_BASE_URI, uint2str(id))

    return ""
