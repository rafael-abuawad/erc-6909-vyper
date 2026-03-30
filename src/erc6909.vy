# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title Modern and Gas-Efficient ERC-6909 Implementation
@custom:contract-name erc6909
@license GNU Affero General Public License v3.0 only
@author rafael-abuawad
@notice These functions implement the ERC-6909
        standard interface:
        - https://eips.ethereum.org/EIPS/eip-6909.
        In addition, the following functions have
        been added for convenience:
        - `set_token_uri` (`external` function),
        - `set_name` (`external` function),
        - `set_symbol` (`external` function),
        - `set_decimals` (`external` function),
        - `exists` (`external` `view` function),
        - `burn` (`external` function),
        - `is_minter` (`external` `view` function),
        - `mint` (`external` function),
        - `set_minter` (`external` function),
        - `owner` (`external` `view` function),
        - `transfer_ownership` (`external` function),
        - `renounce_ownership` (`external` function),
        - `_before_token_transfer` (`internal` function),
        - `_after_token_transfer` (`internal` function).
        The implementation is inspired by OpenZeppelin's implementation here:
        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol.
"""


# @dev We import and implement the `IERC165` interface,
# which is a built-in interface of the Vyper compiler.
from ethereum.ercs import IERC165
implements: IERC165


# @dev We import and implement the `IERC6909` interface,
# which is written using standard Vyper syntax.
from .interfaces import IERC6909
implements: IERC6909


# @dev We import and implement the `IERC6909ContentURI` interface,
# which is written using standard Vyper syntax.
from .interfaces import IERC6909ContentURI
implements: IERC6909ContentURI


# @dev We import and implement the `IERC6909Metadata` interface,
# which is written using standard Vyper syntax.
from .interfaces import IERC6909Metadata
implements: IERC6909Metadata


# @dev We import and implement the `IERC6909TokenSupply` interface,
# which is written using standard Vyper syntax.
from .interfaces import IERC6909TokenSupply
implements: IERC6909TokenSupply


# @dev We import and use the `ownable` module.
from snekmate.auth import ownable
uses: ownable


# @dev We export (i.e. the runtime bytecode exposes these
# functions externally, allowing them to be called using
# the ABI encoding specification) the `external` getter
# function `owner` from the `ownable` module.
# @notice Please note that you must always also export (if
# required by the contract logic) `public` declared `constant`,
# `immutable`, and state variables, for which Vyper automatically
# generates an `external` getter function for the variable.
exports: (
    # @notice This ERC-6909 implementation includes the `transfer_ownership`
    # and `renounce_ownership` functions, which incorporate
    # the additional built-in `is_minter` role logic and are
    # therefore not exported from the `ownable` module.
    ownable.owner,
)


# @dev Stores the ERC-165 interface identifier for each
# imported interface. The ERC-165 interface identifier
# is defined as the XOR of all function selectors in the
# interface.
# @notice If you are not using the full feature set of
# this contract, please ensure you exclude the unused
# ERC-165 interface identifiers in the main contract.
_SUPPORTED_INTERFACES: constant(bytes4[5]) = [
    0x01FFC9A7, # The ERC-165 identifier for ERC-165.
    0x0f632fb3, # The ERC-165 identifier for ERC-6909.
    0x20d88258, # The ERC-165 identifier for the ERC-6909 content URI extension.
    0x71abc795, # The ERC-165 identifier for the ERC-6909 metadata extension.
    0xbd85b039, # The ERC-165 identifier for the ERC-6909 token supply extension.
]


# @dev Stores the base URI for computing `uri`.
_BASE_URI: immutable(String[80])


# @dev Struct for token metadata.
struct TokenMetadata:
    name: String[25]
    symbol: String[5]
    decimals: uint8


# @dev Stores per-address balances: amount of token 
# `id` owned by each address.
# @notice If you declare a variable as `public`,
# Vyper automatically generates an `external`
# getter function for the variable.
_balances: HashMap[address, HashMap[uint256, uint256]]


# @dev Allowance for (`owner`, `spender`) on token `id`
_allowances: HashMap[address, HashMap[address, HashMap[uint256, uint256]]]


# @dev `True` if `operator` is approved to move any amount of
# any token `id` on behalf of `owner`.
_operator_approvals: HashMap[address, HashMap[address, bool]]


# @dev Total minted supply per token `id` (token supply extension).
_total_supply: HashMap[uint256, uint256]


# @dev Mapping from token `id` to metadata
_token_metadata: HashMap[uint256, TokenMetadata]


# @dev Returns `True` if an `address` has been
# granted the minter role.
is_minter: public(HashMap[address, bool])


# @dev Mapping from token id to token URI.
# @notice Since the Vyper design requires
# strings of fixed size, we arbitrarily set
# the maximum length for `_token_uris` to 432
# characters. Since we have set the maximum
# length for `_BASE_URI` to 80 characters,
# which implies a maximum character length
# for `tokenURI` of 512.
_token_uris: HashMap[uint256, String[432]]


# @dev Contract URI
_CONTRACT_URI: immutable(String[512])


# @dev Emitted when the status of a `minter`
# address is changed.
event RoleMinterChanged:
    minter: indexed(address)
    status: bool


# @dev The name of the token of type `id` was updated to `newName`.
event ERC6909NameUpdated:
    id: indexed(uint256)
    newName: String[25]


# @dev The symbol for the token of type `id` was updated to `newSymbol`.
event ERC6909SymbolUpdated:
    id: indexed(uint256)
    newSymbol: String[5]


# @dev The decimals value for token of type `id` was updated to `newDecimals`.
event ERC6909DecimalsUpdated:
    id: indexed(uint256)
    newDecimals: uint8


@deploy
@payable
def __init__(base_uri_: String[80], contract_uri_: String[512]):
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    @notice At initialisation time, the `owner` role will be
            assigned to the `msg.sender` since we `uses` the
            `ownable` module, which implements the aforementioned
            logic at contract creation time.
    @param base_uri_ The maximum 80-character user-readable
           string base URI for `tokenURI` (may be empty; see `_token_uri`).
    @param contract_uri_ The maximum 512-character contract-level URI
           stored in `_CONTRACT_URI` and returned by `contractURI`.
    """
    _BASE_URI = base_uri_
    _CONTRACT_URI = contract_uri_
    
    self.is_minter[msg.sender] = True
    log RoleMinterChanged(minter=msg.sender, status=True)


@external
def transfer(to: address, id: uint256, amount: uint256) -> bool:
    """
    @dev Transfers `amount` tokens of token `id` from the caller's
         account to `to`.
    @notice `to` cannot be the zero address. The caller must have a balance
            of token `id` of at least `amount`.
    @param to The 20-byte receiver address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be transferred.
    """
    self._transfer(msg.sender, to, id, amount, msg.sender)
    return True


@external
def transferFrom(owner: address, to: address, id: uint256, amount: uint256):
    """
    @dev Transfers `amount` tokens of token `id` from `owner` to `to`.
    @notice `owner` and `to` cannot be the zero address. `owner` must have
            a balance of at least `amount`. The caller must be `owner`, an
            operator for `owner` (`isOperator`), or have an allowance of at
            least `amount` for token `id`. Allowance is not decreased
            when the caller is `owner` or an operator. When allowance is
            used and is not `max_value(uint256)`, it is decreased by `amount`.

            WARNING: Infinite allowance (`max_value(uint256)`) is not decreased.
    @param owner The 20-byte address debited by the transfer.
    @param to The 20-byte receiver address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be transferred.
    """
    if msg.sender != owner:
        if not self._operator_approvals[owner][msg.sender]:
            self._spend_allowance(owner, msg.sender, id, amount)
    self._transfer(owner, to, id, amount, msg.sender)


@external
def approve(spender: address, id: uint256, amount: uint256):
    """
    @dev Sets the allowance of `spender` for token `id` of the caller
         to `amount` and emits `Approval`.
    @notice `spender` cannot be the zero address.
    @param spender The 20-byte spender address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount `spender` may transfer on behalf
           of the caller.
    """
    self._approve(msg.sender, spender, id, amount)



@external
def set_token_uri(id: uint256, token_uri: String[432]):
    """
    @dev Sets the Uniform Resource Identifier (URI)
         for token `id`.
    @notice Decoupled from minting: further supply may be minted for the same
            token id `id` later. Only addresses with `is_minter` may set URIs.
    @param id The 32-byte token id.
    @param token_uri The maximum 432-character user-readable
           string URI segment combined with `_BASE_URI` in `tokenURI`.
    """
    assert self.is_minter[msg.sender], "erc6909: access is denied"
    self._set_token_uri(id, token_uri)


@external
def burn(id: uint256, amount: uint256):
    """
    @dev Destroys `amount` tokens of token `id` from the caller.
    @notice `amount` cannot exceed the balance of token `id` of the caller.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be burned.
    """
    self._burn(msg.sender, id, amount)


@external
def burn_from(owner: address, id: uint256, amount: uint256):
    """
    @dev Destroys `amount` tokens from `owner`,
         deducting from the caller's allowance.
    @notice Note that `owner` cannot be the
            zero address. Also, the caller must
            have an allowance for `owner`'s tokens
            of at least `amount`.
    @param owner The 20-byte owner address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be destroyed.
    """
    self._spend_allowance(owner, msg.sender, id, amount)
    self._burn(owner, id, amount)


@external
def mint(owner: address, id: uint256, amount: uint256):
    """
    @dev Creates `amount` tokens of token `id` and assigns them to `owner`.
    @notice Only authorised minters can access this function.
            Note that `owner` cannot be the zero address.
    @param owner The 20-byte owner address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be created.
    """
    assert self.is_minter[msg.sender], "erc6909: access is denied"
    self._mint(owner, id, amount)


@external
def set_minter(minter: address, status: bool):
    """
    @dev Adds or removes an address `minter` to/from the
         list of allowed minters. Note that only the
         `owner` can add or remove `minter` addresses.
         Also, the `minter` cannot be the zero address.
         Eventually, the `owner` cannot remove himself
         from the list of allowed minters.
    @param minter The 20-byte minter address.
    @param status The Boolean variable that sets the status.
    """
    ownable._check_owner()
    assert minter != empty(address), "erc6909: minter is the zero address"
    # We ensured in the previous step `ownable._check_owner`
    # that `msg.sender` is the `owner`.
    assert minter != msg.sender, "erc6909: minter is owner address"
    self.is_minter[minter] = status
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

    self.is_minter[msg.sender] = False
    log RoleMinterChanged(minter=msg.sender, status=False)

    ownable._transfer_ownership(new_owner)
    self.is_minter[new_owner] = True
    log RoleMinterChanged(minter=new_owner, status=True)


@external
def renounce_ownership():
    """
    @dev Leaves the contract without an owner.
    @notice Renouncing ownership will leave the
            contract without an owner, thereby
            removing any functionality that is
            only available to the owner. Note
            that the `owner` is also removed from
            the list of allowed minters.

            WARNING: All other existing `minter`
            addresses will still be able to create
            new tokens. Consider removing all non-owner
            minter addresses first via `set_minter`
            before calling `renounce_ownership`.
    """
    ownable._check_owner()
    self.is_minter[msg.sender] = False
    log RoleMinterChanged(minter=msg.sender, status=False)
    ownable._transfer_ownership(empty(address))


@external
def set_name(id: uint256, new_name: String[25]):
    """
    @dev Sets the human-readable name for token `id`.
    @param id The 32-byte token id.
    @param new_name The maximum 25-character name of the token.
    """
    assert self.is_minter[msg.sender], "erc6909: access is denied"
    self._token_metadata[id].name = new_name
    log ERC6909NameUpdated(id=id, newName=new_name)


@external
def set_symbol(id: uint256, new_symbol: String[5]):
    """
    @dev Sets the ticker symbol for token `id`.
    @param id The 32-byte token id.
    @param new_symbol The maximum 5-character symbol of the token.
    """
    assert self.is_minter[msg.sender], "erc6909: access is denied"
    self._token_metadata[id].symbol = new_symbol
    log ERC6909SymbolUpdated(id=id, newSymbol=new_symbol)


@external
def set_decimals(id: uint256, new_decimals: uint8):
    """
    @dev Sets the number of decimal places used for amounts of token `id`.
    @param id The 32-byte token id.
    @param new_decimals The number of decimal places used for amounts of token `id`.
    """
    assert self.is_minter[msg.sender], "erc6909: access is denied"
    self._token_metadata[id].decimals = new_decimals
    log ERC6909DecimalsUpdated(id=id, newDecimals=new_decimals)


@external
@view
def supportsInterface(interface_id: bytes4) -> bool:
    """
    @dev Returns `True` if this contract implements the
         interface defined by `interface_id`.
    @param interface_id The 4-byte interface identifier.
    @return bool The verification whether the contract
            implements the interface or not.
    """
    return interface_id in _SUPPORTED_INTERFACES


@external
@view
def name(id: uint256) -> String[25]:
    """
    @dev Returns the human-readable name for token `id`.
    @param id The 32-byte token id.
    @return String The maximum 25-character name of the token
            id `id`.
    """
    return self._token_metadata[id].name


@external
@view
def symbol(id: uint256) -> String[5]:
    """
    @dev Returns the ticker symbol for token `id`.
    @param id The 32-byte token id.
    @return String The maximum 5-character symbol of the token
            id `id`.
    """
    return self._token_metadata[id].symbol


@external
@view
def decimals(id: uint256) -> uint8:
    """
    @dev Returns the number of decimal places used for amounts
         of token `id`.
    @param id The 32-byte token id.
    @return uint8 The decimals value for token id `id`.
    """
    return self._token_metadata[id].decimals


@external
@view
def balanceOf(owner: address, id: uint256) -> uint256:
    """
    @dev Returns the amount of tokens of token
         id `id` owned by `owner`.
    @param owner The 20-byte owner address.
    @param id The 32-byte token id.
    @return uint256 The 32-byte token amount owned
            by `owner`.
    """
    return self._balances[owner][id]


@external
@view
def allowance(owner: address, spender: address, id: uint256) -> uint256:
    """
    @dev Returns the amount of tokens of token
         id `id` that `spender` is allowed to spend on
         behalf of `owner`.
    @param owner The 20-byte owner address.
    @param spender The 20-byte spender address.
    @param id The 32-byte token id.
    @return uint256 The 32-byte token amount that `spender`
            is allowed to spend on behalf of `owner`.
    """
    return self._allowances[owner][spender][id]


@external
@view
def isOperator(owner: address, operator: address) -> bool:
    """
    @dev Returns `True` if `operator` is approved to transfer
         any amount of any token id on behalf of `owner`.
    @param owner The 20-byte owner address.
    @param operator The 20-byte operator address.
    @return bool The verification whether `operator` is approved
            or not.
    """
    return self._operator_approvals[owner][operator]


@external
def setOperator(operator: address, approved: bool) -> bool:
    """
    @dev Grants or revokes unlimited transfer permissions for `operator`
         for any token id on behalf of the caller.
    @notice MUST set the operator status to `approved`.
            MUST log the `OperatorSet` event.
            MUST return `True`.
    @param operator The 20-byte operator address.
    @param approved The new operator approval status for `operator`.
    @return bool Always returns `True`.
    """
    self._operator_approvals[msg.sender][operator] = approved
    log IERC6909.OperatorSet(
        _owner=msg.sender, _operator=operator, _approved=approved
    )
    return True


@external
@view
def contractURI() -> String[512]:
    """
    @dev Returns the Uniform Resource Identifier (URI) for the contract.
    @return String The maximum 512-character user-readable
            string contract URI.
    """
    return _CONTRACT_URI
    

@external
@view
def tokenURI(id: uint256) -> String[512]:
    """
    @dev Returns the Uniform Resource Identifier (URI)
         for token `id`.
    @notice If the `{id}` substring is present in the URI,
            it must be replaced by clients with the actual
            token id. Note that the `tokenURI` function must
            not be used to check for the existence of a token
            as it is possible for the implementation to return
            a valid string even if the token does not exist.
    @param id The 32-byte token id.
    @return String The maximum 512-character user-readable
            string token URI for token id `id`.
    """
    return self._token_uri(id)


@external
@view
def exists(id: uint256) -> bool:
    """
    @dev Returns whether token id `id` exists: `True` if total supply
         for `id` is non-zero (`totalSupply(id) != 0`).
    @param id The 32-byte token id.
    @return bool Whether any amount of token id `id` has been minted.
    """
    return self._total_supply[id] != empty(uint256)


@external
@view
def totalSupply(id: uint256) -> uint256:
    """
    @dev Returns the total supply of token id `id` (token supply extension).
    @param id The 32-byte token id.
    @return uint256 The cumulative minted amount for `id`.
    """
    return self._total_supply[id]


@internal
def _before_token_transfer(owner: address, to: address, id: uint256, amount: uint256):
    """
    @dev Hook called before any transfer of token id `id`; no-op here.
         Override via inheritance patterns if extending this contract.
    @param owner The 20-byte address debited by the transfer.
    @param to The 20-byte receiver address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount moved.
    """
    pass


@internal
def _after_token_transfer(owner: address, to: address, id: uint256, amount: uint256):
    """
    @dev Hook called after any transfer of token id `id`; no-op here.
    @param owner The 20-byte address debited by the transfer.
    @param to The 20-byte receiver address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount moved.
    """
    pass


@internal
def _mint(owner: address, id: uint256, amount: uint256):
    """
    @dev Creates `amount` tokens and assigns
         them to `owner`, increasing the
         total supply.
    @notice This is an `internal` function without
            access restriction. Note that `owner`
            cannot be the zero address.
    @param owner The 20-byte owner address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be created.
    """
    assert owner != empty(address), "erc20: mint to the zero address"

    self._before_token_transfer(empty(address), owner, id, amount)

    self._total_supply[id] = unsafe_add(self._total_supply[id], amount)
    self._balances[owner][id] = unsafe_add(self._balances[owner][id], amount)
    log IERC6909.Transfer(_caller=empty(address), _from=empty(address), _to=owner, _id=id, _value=amount)

    self._after_token_transfer(empty(address), owner, id, amount)



@internal
def _burn(owner: address, id: uint256, amount: uint256):
    """
    @dev Destroys `amount` tokens of token `id` from `owner`,
         reducing the total supply.
    @notice Note that `owner` cannot be the
            zero address. Also, `owner` must
            have at least `amount` tokens.
    @param owner The 20-byte owner address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be destroyed.
    """
    assert owner != empty(address), "erc20: burn from the zero address"

    self._before_token_transfer(owner, empty(address), id, amount)

    account_balance: uint256 = self._balances[owner][id]
    assert account_balance >= amount, "erc6909: burn amount exceeds balance"
    self._balances[owner][id] = unsafe_sub(account_balance, amount)
    self._total_supply[id] = unsafe_sub(self._total_supply[id], amount)
    log IERC6909.Transfer(_caller=owner, _from=owner, _to=empty(address), _id=id, _value=amount)

    self._after_token_transfer(owner, empty(address), id, amount)


@internal
def _approve(owner: address, spender: address, id: uint256, amount: uint256):
    """
    @dev Sets the allowance of `spender` for token `id` of `owner`
         to `amount` and emits `IERC6909.Approval`.
    @notice `owner` and `spender` cannot be the zero address.
    @param owner The 20-byte owner address.
    @param spender The 20-byte spender address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount `spender` may transfer on
           behalf of `owner` for this token `id`.
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
    @dev Moves `amount` of token `id` from `owner` to `to`.
    @notice Runs `_before_token_transfer` then `_after_token_transfer`.
            Emits `IERC6909.Transfer` with `_caller`, `_from`, `_to`,
            `_id`, and `_value` per the interface. `owner` and `to`
            cannot be zero; `owner` must have sufficient balance.
    @param owner The 20-byte address debited by the transfer.
    @param to The 20-byte receiver address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to be transferred.
    @param caller The 20-byte address that initiated the transfer
           (`msg.sender` for external entrypoints).
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
def _spend_allowance(owner: address, spender: address, id: uint256, amount: uint256):
    """
    @dev Decreases `spender`'s allowance on token `id` for `owner`
         by `amount` when the stored allowance is less than `max_value(uint256)`.
    @notice Does not decrease allowance when it equals `max_value(uint256)`.
            Reverts if the current allowance is below `amount` (except on
            infinite allowance). The `amount` parameter is the transfer size,
            not the remaining allowance.
    @param owner The 20-byte owner address.
    @param spender The 20-byte spender address.
    @param id The 32-byte token id.
    @param amount The 32-byte token amount to consume from the allowance.
    """
    current_allowance: uint256 = self._allowances[owner][spender][id]
    if current_allowance < max_value(uint256):
        # The following line allows the commonly known address
        # poisoning attack, where `transferFrom` instructions
        # are executed from arbitrary addresses with an `amount`
        # of `0`. However, this poisoning attack is not an on-chain
        # vulnerability. All assets are safe. It is an off-chain
        # log interpretation issue.
        assert current_allowance >= amount, "erc6909: insufficient allowance"
        self._approve(owner, spender, id, unsafe_sub(current_allowance, amount))



@internal
def _set_token_uri(id: uint256, token_uri: String[432]):
    """
    @dev Sets the Uniform Resource Identifier (URI)
         for token `id`.
    @notice This is an `internal` function without access
            restriction. This function is decoupled from
            `_mint`, as multiple of the same `id` can be
            minted.
    @param id The 32-byte token id.
    @param token_uri The maximum 432-character user-readable
           string URI segment for `tokenURI`.
    """
    self._token_uris[id] = token_uri


@internal
@view
def _token_uri(id: uint256) -> String[512]:
    """
    @dev An `internal` helper function that returns the Uniform
         Resource Identifier (URI) for token `id`.
    @notice If the `{id}` substring is present in the URI,
            it must be replaced by clients with the actual
            token `id`. Do not use `tokenURI` to infer
            token existence; a non-empty URI does not imply
            a positive balance or supply.
    @param id The 32-byte token id.
    @return String The maximum 512-character user-readable
            string token URI for token id `id`.
    """
    token_uri: String[432] = self._token_uris[id]

    base_uri_length: uint256 = len(_BASE_URI)
    # If there is no base URI, return the token URI.
    if base_uri_length == empty(uint256):
        return token_uri
    # If both are set, concatenate the base URI
    # and token URI.
    elif len(token_uri) != empty(uint256):
        return concat(_BASE_URI, token_uri)
    # If there is no token URI but a base URI,
    # concatenate the base URI and token id.
    elif base_uri_length != empty(uint256):
        # Please note that for projects where the
        # substring `{id}` is present in the URI
        # and this URI is to be set as `_BASE_URI`,
        # it is recommended to remove the following
        # concatenation and simply return `_BASE_URI`
        # for easier off-chain handling.
        return concat(_BASE_URI, uint2str(id))

    return ""
