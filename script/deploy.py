from src.mocks import erc6909_mock as ERC6909
from moccasin.boa_tools import VyperContract

base_uri = "https://example.com"
contract_uri = "https://example.com/contract"


def deploy() -> VyperContract:
    erc6909: VyperContract = ERC6909.deploy(base_uri, contract_uri)
    return erc6909


def moccasin_main() -> VyperContract:
    return deploy()
