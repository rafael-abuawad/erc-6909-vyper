def test_total_supply_is_zero(erc6909_contract):
    import boa

    for i in range(int(boa.eval("max_value(uint8)"))):
        assert erc6909_contract.totalSupply(i) == 0
