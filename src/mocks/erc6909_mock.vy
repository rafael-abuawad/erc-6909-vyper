# pragma version ~=0.4.3
# pragma nonreentrancy off
"""
@title `erc6909` Module Reference Implementation
@custom:contract-name erc6909_mock
@license GNU Affero General Public License v3.0 only
@author rafael-abuawad
"""


# @dev We import and implement the `IERC20Permit`
# interface, which is written using standard Vyper
# syntax.
from ..interfaces import IERC6909
implements: IERC6909


# @dev We import and initialise the `ownable` module.
from snekmate.auth import ownable as ow
initializes: ow


# @dev We import and initialise the `erc20` module.
from .. import erc6909
initializes: erc6909[ownable := ow]


# @dev We export (i.e. the runtime bytecode exposes these
# functions externally, allowing them to be called using
# the ABI encoding specification) all `external` functions
# from the `erc20` module. The built-in dunder method
# `__interface__` allows you to export all functions of a
# module without specifying the individual functions (see
# https://github.com/vyperlang/vyper/pull/3919). Please take
# note that if you do not know the full interface of a module
# contract, you can get the `.vyi` interface in Vyper by using
# `vyper -f interface your_filename.vy` or the external interface
# by using `vyper -f external_interface your_filename.vy`.
# @notice Please note that you must always also export (if
# required by the contract logic) `public` declared `constant`,
# `immutable`, and state variables, for which Vyper automatically
# generates an `external` getter function for the variable.
exports: erc6909.__interface__


@deploy
@payable
def __init__(
    base_uri_: String[80],
    contract_uri_: String[512],
):
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    @notice The initial supply of the token as well
            as the `owner` role will be assigned to
            the `msg.sender`.
    @param base_uri_ The maximum 80-character user-readable
           string base URI for `tokenURI` (may be empty; see `_token_uri`).
    @param contract_uri_ The maximum 512-character contract-level URI
           stored in `_CONTRACT_URI` and returned by `contractURI`.
    """
    # The following line assigns the `owner`
    # to the `msg.sender`.
    ow.__init__()
    erc6909.__init__(base_uri_, contract_uri_)
