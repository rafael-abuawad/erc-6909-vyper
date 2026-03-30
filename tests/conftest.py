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
def erc6909_contract():
    return deploy()
