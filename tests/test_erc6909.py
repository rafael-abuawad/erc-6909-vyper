import boa
import pytest

from script.deploy import base_uri, contract_uri


# ERC-165 ids from erc6909._SUPPORTED_INTERFACES
ERC165_ID = 0x01FFC9A7
ERC6909_ID = 0x0F632FB3
ERC6909_CONTENT_URI_ID = 0x20D88258
ERC6909_METADATA_ID = 0x71ABC795
ERC6909_TOKEN_SUPPLY_ID = 0xBD85B039


def test_create_token(create_token, erc6909_contract, owner):
    token_id = create_token("Test Token", "TEST", 18)
    assert token_id == 0
    assert erc6909_contract.name(token_id) == "Test Token"
    assert erc6909_contract.symbol(token_id) == "TEST"
    assert erc6909_contract.decimals(token_id) == 18
    assert erc6909_contract.totalSupply(token_id) == 1000
    assert erc6909_contract.exists(token_id) is True
    assert erc6909_contract.balanceOf(owner, token_id) == 1000


def test_transfer_token(create_token, erc6909_contract, owner, accounts):
    token_id = create_token("Test Token", "TEST", 18)
    assert erc6909_contract.totalSupply(token_id) == 1000
    assert erc6909_contract.exists(token_id) is True
    assert erc6909_contract.balanceOf(owner, token_id) == 1000

    for i, account in enumerate(accounts):
        assert erc6909_contract.balanceOf(account, token_id) == 0
        with boa.env.prank(owner):
            assert erc6909_contract.transfer(account, token_id, 100) is True
        assert erc6909_contract.balanceOf(account, token_id) == 100
        expected_balance = 1000 - ((i + 1) * 100)
        assert erc6909_contract.balanceOf(owner, token_id) == expected_balance

    assert erc6909_contract.balanceOf(owner, token_id) == 0


def test_approve_token(create_token, erc6909_contract, owner, accounts, alice):
    token_id = create_token("Test Token", "TEST", 18)
    assert erc6909_contract.totalSupply(token_id) == 1000
    assert erc6909_contract.exists(token_id) is True
    assert erc6909_contract.balanceOf(owner, token_id) == 1000

    alice_balance = 0
    for account in accounts:
        assert erc6909_contract.allowance(owner, account, token_id) == 0

        amount = 100
        with boa.env.prank(owner):
            assert erc6909_contract.approve(account, token_id, amount)

        with boa.env.prank(account):
            assert erc6909_contract.transferFrom(owner, alice, token_id, amount)
            assert erc6909_contract.allowance(owner, account, token_id) == 0

            alice_balance += amount
            assert erc6909_contract.balanceOf(alice, token_id) == alice_balance


def test_set_operator(create_token, erc6909_contract, owner, alice):
    token_id = None
    with boa.env.prank(owner):
        assert erc6909_contract.setOperator(alice, True)
        token_id = create_token("Test Token", "TEST", 18)

    assert erc6909_contract.allowance(owner, alice, token_id) == 0

    initial_balance = erc6909_contract.balanceOf(owner, token_id)
    with boa.env.prank(alice):
        assert (
            erc6909_contract.transferFrom(owner, alice, token_id, initial_balance)
            is True
        )

    assert erc6909_contract.isOperator(owner, alice) is True
    assert erc6909_contract.balanceOf(alice, token_id) == initial_balance
    assert erc6909_contract.balanceOf(owner, token_id) == 0


def test_transfer_from_without_allowance(create_token, erc6909_contract, owner, alice):
    token_id = None
    with boa.env.prank(owner):
        token_id = create_token("Test Token", "TEST", 18)

    assert erc6909_contract.allowance(owner, alice, token_id) == 0

    initial_balance = erc6909_contract.balanceOf(owner, token_id)
    with boa.env.prank(alice):
        with boa.reverts("erc6909: insufficient allowance"):
            erc6909_contract.transferFrom(owner, alice, token_id, initial_balance)

    assert erc6909_contract.balanceOf(alice, token_id) == 0
    assert erc6909_contract.balanceOf(owner, token_id) == initial_balance


def test_create_sequential_ids_increment(erc6909_contract, owner):
    with boa.env.prank(owner):
        assert erc6909_contract.create("T0", "0", 0) == 0
        assert erc6909_contract.create("T1", "1", 0) == 1
        assert erc6909_contract.create("T2", "2", 0) == 2


def test_create_without_mint_exists_false_supply_zero(erc6909_contract, owner):
    with boa.env.prank(owner):
        token_id = erc6909_contract.create("Empty", "E", 18)
    assert erc6909_contract.exists(token_id) is False
    assert erc6909_contract.totalSupply(token_id) == 0
    with boa.env.prank(owner):
        erc6909_contract.mint(owner, token_id, 1)
    assert erc6909_contract.exists(token_id) is True
    assert erc6909_contract.totalSupply(token_id) == 1


def test_two_tokens_independent_balances(create_token, erc6909_contract, owner, alice):
    t0 = create_token("A", "A", 18)
    t1 = create_token("B", "B", 18)
    assert t0 == 0
    assert t1 == 1
    with boa.env.prank(owner):
        assert erc6909_contract.transfer(alice, t0, 100) is True
    assert erc6909_contract.balanceOf(owner, t0) == 900
    assert erc6909_contract.balanceOf(alice, t0) == 100
    assert erc6909_contract.balanceOf(owner, t1) == 1000
    assert erc6909_contract.balanceOf(alice, t1) == 0


def test_transfer_to_zero_address_reverts(create_token, erc6909_contract, owner):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        with boa.reverts("erc6909: transfer to the zero address"):
            erc6909_contract.transfer(boa.eval("empty(address)"), token_id, 1)


def test_transfer_amount_exceeds_balance_reverts(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        with boa.reverts("erc6909: transfer amount exceeds balance"):
            erc6909_contract.transfer(alice, token_id, 10**24)


def test_transfer_from_by_owner_without_allowance_succeeds(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    assert erc6909_contract.allowance(owner, owner, token_id) == 0
    with boa.env.prank(owner):
        assert erc6909_contract.transferFrom(owner, alice, token_id, 50) is True
    assert erc6909_contract.balanceOf(alice, token_id) == 50
    assert erc6909_contract.balanceOf(owner, token_id) == 950


def test_transfer_from_zero_owner_zero_amount_reverts(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(alice):
        # _spend_allowance → _approve with owner == zero
        with boa.reverts("erc6909: approve from the zero address"):
            erc6909_contract.transferFrom(
                boa.eval("empty(address)"), alice, token_id, 0
            )


def test_approve_zero_spender_reverts(create_token, erc6909_contract, owner):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        with boa.reverts("erc6909: approve to the zero address"):
            erc6909_contract.approve(boa.eval("empty(address)"), token_id, 1)


def test_partial_allowance_decrements_on_transfer_from(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        erc6909_contract.approve(alice, token_id, 100)
    with boa.env.prank(alice):
        assert erc6909_contract.transferFrom(owner, alice, token_id, 60) is True
    assert erc6909_contract.allowance(owner, alice, token_id) == 40


def test_infinite_allowance_not_decremented_two_transfer_froms(
    create_token, erc6909_contract, owner, alice, accounts
):
    token_id = create_token("T", "T", 18)
    spender = accounts[0]
    with boa.env.prank(owner):
        erc6909_contract.approve(spender, token_id, boa.eval("max_value(uint256)"))
    with boa.env.prank(spender):
        assert erc6909_contract.transferFrom(owner, alice, token_id, 100) is True
        assert erc6909_contract.transferFrom(owner, alice, token_id, 100) is True
    assert erc6909_contract.allowance(owner, spender, token_id) == boa.eval(
        "max_value(uint256)"
    )


def test_set_operator_false_transfer_from_reverts(
    create_token, erc6909_contract, owner, alice
):
    with boa.env.prank(owner):
        assert erc6909_contract.setOperator(alice, True)
    token_id = create_token("T", "T", 18)
    bal = erc6909_contract.balanceOf(owner, token_id)
    with boa.env.prank(owner):
        assert erc6909_contract.setOperator(alice, False)
    assert erc6909_contract.isOperator(owner, alice) is False
    with boa.env.prank(alice):
        with boa.reverts("erc6909: insufficient allowance"):
            erc6909_contract.transferFrom(owner, alice, token_id, bal)


def test_burn_reduces_balance_and_total_supply(create_token, erc6909_contract, owner):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        erc6909_contract.burn(token_id, 200)
    assert erc6909_contract.balanceOf(owner, token_id) == 800
    assert erc6909_contract.totalSupply(token_id) == 800


def test_burn_amount_exceeds_balance_reverts(create_token, erc6909_contract, owner):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        with boa.reverts("erc6909: burn amount exceeds balance"):
            erc6909_contract.burn(token_id, 10**24)


def test_burn_from_with_allowance_succeeds(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(owner):
        erc6909_contract.approve(alice, token_id, 300)
    with boa.env.prank(alice):
        erc6909_contract.burn_from(owner, token_id, 100)
    assert erc6909_contract.balanceOf(owner, token_id) == 900
    assert erc6909_contract.totalSupply(token_id) == 900
    assert erc6909_contract.allowance(owner, alice, token_id) == 200


def test_burn_from_without_allowance_reverts(
    create_token, erc6909_contract, owner, alice
):
    token_id = create_token("T", "T", 18)
    with boa.env.prank(alice):
        with boa.reverts("erc6909: insufficient allowance"):
            erc6909_contract.burn_from(owner, token_id, 1)


@pytest.mark.parametrize("call", ["create", "mint_zero", "set_token_uri"])
def test_non_minter_reverts_access_denied(erc6909_contract, owner, non_minter, call):
    with boa.env.prank(owner):
        tid = erc6909_contract.create("Seed", "S", 18)
        erc6909_contract.mint(owner, tid, 1)

    with boa.env.prank(non_minter):
        with boa.reverts("erc6909: access is denied"):
            if call == "create":
                erc6909_contract.create("X", "X", 18)
            elif call == "mint_zero":
                erc6909_contract.mint(non_minter, tid, 1)
            elif call == "set_token_uri":
                erc6909_contract.set_token_uri(tid, "/x")


def test_set_minter_by_owner_allows_create_and_mint(
    erc6909_contract, owner, non_minter
):
    with boa.env.prank(owner):
        erc6909_contract.set_minter(non_minter, True)
    with boa.env.prank(non_minter):
        tid = erc6909_contract.create("Nm", "N", 18)
        erc6909_contract.mint(non_minter, tid, 42)
    assert erc6909_contract.balanceOf(non_minter, tid) == 42
    assert erc6909_contract.is_minter(non_minter) is True


def test_set_minter_by_non_owner_reverts(erc6909_contract, owner, alice, non_minter):
    with boa.env.prank(alice):
        with boa.reverts("ownable: caller is not the owner"):
            erc6909_contract.set_minter(non_minter, True)


def test_set_minter_zero_address_reverts(erc6909_contract, owner):
    with boa.env.prank(owner):
        with boa.reverts("erc6909: minter is the zero address"):
            erc6909_contract.set_minter(boa.eval("empty(address)"), True)


def test_set_minter_owner_address_reverts(erc6909_contract, owner):
    with boa.env.prank(owner):
        with boa.reverts("erc6909: minter is owner address"):
            erc6909_contract.set_minter(owner, True)


def test_mint_to_zero_address_reverts(erc6909_contract, owner):
    with boa.env.prank(owner):
        tid = erc6909_contract.create("Z", "Z", 18)
        with boa.reverts("erc20: mint to the zero address"):
            erc6909_contract.mint(boa.eval("empty(address)"), tid, 1)


def test_contract_uri_matches_deploy(erc6909_contract):
    assert erc6909_contract.contractURI() == contract_uri


def test_token_uri_fallback_base_plus_id_str(erc6909_contract):
    # id 99 never minted; no per-token URI set -> base_uri + decimal string of id
    expected = f"{base_uri}99"
    assert erc6909_contract.tokenURI(99) == expected


def _bytes4(x: int) -> bytes:
    return x.to_bytes(4, "big")


@pytest.mark.parametrize(
    "interface_id,expected",
    [
        (ERC165_ID, True),
        (ERC6909_ID, True),
        (ERC6909_CONTENT_URI_ID, True),
        (ERC6909_METADATA_ID, True),
        (ERC6909_TOKEN_SUPPLY_ID, True),
        (0xDEADBEEF, False),
    ],
)
def test_supports_interface(erc6909_contract, interface_id, expected):
    assert erc6909_contract.supportsInterface(_bytes4(interface_id)) is expected


def test_create_initializes_metadata_without_mint(erc6909_contract, owner):
    with boa.env.prank(owner):
        token_id = erc6909_contract.create("Meta", "M", 9)
    assert token_id == 0
    assert erc6909_contract.name(token_id) == "Meta"
    assert erc6909_contract.symbol(token_id) == "M"
    assert erc6909_contract.decimals(token_id) == 9
    assert erc6909_contract.exists(token_id) is False
    assert erc6909_contract.totalSupply(token_id) == 0


def test_transfer_ownership_updates_owner_and_minter_roles(
    erc6909_contract, owner, alice
):
    assert erc6909_contract.owner() == owner
    assert erc6909_contract.is_minter(owner) is True
    assert erc6909_contract.is_minter(alice) is False

    with boa.env.prank(owner):
        erc6909_contract.transfer_ownership(alice)

    assert erc6909_contract.owner() == alice
    assert erc6909_contract.is_minter(owner) is False
    assert erc6909_contract.is_minter(alice) is True


def test_transfer_ownership_new_owner_zero_reverts(erc6909_contract, owner):
    with boa.env.prank(owner):
        with boa.reverts("erc6909: new owner is the zero address"):
            erc6909_contract.transfer_ownership(boa.eval("empty(address)"))


def test_transfer_ownership_by_non_owner_reverts(erc6909_contract, owner, alice):
    with boa.env.prank(alice):
        with boa.reverts("ownable: caller is not the owner"):
            erc6909_contract.transfer_ownership(alice)


def test_renounce_ownership_clears_owner_and_minter(erc6909_contract, owner):
    assert erc6909_contract.owner() == owner
    assert erc6909_contract.is_minter(owner) is True
    with boa.env.prank(owner):
        erc6909_contract.renounce_ownership()
    assert erc6909_contract.owner() == boa.eval("empty(address)")
    assert erc6909_contract.is_minter(owner) is False


def test_renounce_ownership_by_non_owner_reverts(erc6909_contract, alice):
    with boa.env.prank(alice):
        with boa.reverts("ownable: caller is not the owner"):
            erc6909_contract.renounce_ownership()
