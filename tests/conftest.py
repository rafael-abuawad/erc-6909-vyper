import pytest
import boa
from script.deploy import deploy


@pytest.fixture
def accounts():
    initial_balance = int(10**18)
    accs = []
    for _ in range(10):
        addr = boa.env.generate_address()
        boa.env.set_balance(addr, initial_balance)
        accs.append(addr)
    return accs


@pytest.fixture
def alice():
    initial_balance = int(10**18)
    addr = boa.env.generate_address()
    boa.env.set_balance(addr, initial_balance)
    return addr


@pytest.fixture
def owner():
    initial_balance = int(10**18)
    addr = boa.env.generate_address()
    boa.env.set_balance(addr, initial_balance)
    return addr


@pytest.fixture
def non_minter():
    initial_balance = int(10**18)
    addr = boa.env.generate_address()
    boa.env.set_balance(addr, initial_balance)
    return addr


@pytest.fixture
def erc6909_contract(owner):
    with boa.env.prank(owner):
        return deploy()


@pytest.fixture
def create_token(owner, erc6909_contract):
    def _create_token(name, symbol, decimals):
        with boa.env.prank(owner):
            token_id = erc6909_contract.create(name, symbol, decimals)
            erc6909_contract.mint(owner, token_id, 1000)
            return token_id

    return _create_token
