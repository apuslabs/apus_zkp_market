# -*- coding:utf-8 -*-
import json
import os
import sys

# Localhost
url = 'http://1.117.58.173:8545'
chain_id = 1337
gas_limit = 3000000  # 您可能需要根据合约函数的复杂性和资源消耗进行调整

env = dict()
with open(".env", "r") as file:
    for line in file:
        line = line.strip()
        if line and not line.startswith("#"):
            key, value = line.split("=")
            env[key.strip()] = value.strip()

url = env['APUS_RPC']
chain_id = int(env['APUS_CHAIN_ID'])
gas_limit = int(env['GAS_LIMIT'])

public_to_private_keys = {
    '0xC2600C80Beb521CC4E2f1b40B9D169c46E391390' :'0x91c6c377cc072cd187fed1caaa6527896f58f10cb20667235c87b07c64b33955'
}

# # Sepolia
# url = 'https://eth-sepolia.g.alchemy.com/v2/j1yrdLvznv5AQ5NfphKOQZsFDU7-Jc8W'
# chain_id = 11155111
#
# # opBNB test_net
# url = 'https://opbnb-testnet-rpc.bnbchain.org'
# chain_id = 5611
#
# # Scroll Sepolia
# url = 'https://sepolia-rpc.scroll.io'
# chain_id = 534351

# Taiko Jolnir
url = 'https://rpc.jolnir.taiko.xyz'
chain_id = 167007


public_to_private_keys = {
    '0x863c9b8159B3F95687a600B1b21aE159618b31b1': '082994a2939818f4d539c7704cdd64a8ba20caf326b2cf731db5b2249c18c985'
}


class _role:
    _contract_owner = '0x863c9b8159B3F95687a600B1b21aE159618b31b1'
    _provider = '0x863c9b8159B3F95687a600B1b21aE159618b31b1'
    _user = '0x863c9b8159B3F95687a600B1b21aE159618b31b1'

    @classmethod
    def private_key(cls, public_key):
        return public_to_private_keys.get(public_key, None)

    @property
    def contract_owner(self):
        return type("owner", (), dict(public_key=self._contract_owner, private_key=self.private_key(self._contract_owner)))

    @property
    def provider(self):
        return type("provider", (), dict(public_key=self._provider, private_key=self.private_key(self._provider)))

    @property
    def user(self):
        return type("user", (), dict(public_key=self._user, private_key=self.private_key(self._user)))


role = _role()


def get_config(fileName):
    return json.load(open(os.path.join(os.getcwd(), "build/contract_address", fileName)))['address'], json.load(open(os.path.join(os.getcwd(), "build/contracts", fileName)))['abi']


market_contract_address, market_abi = get_config("Market.json")
apus_task_address, apus_task_abi = get_config('ApusProofTask.json')
# apus_task_address = env['APUS_TASK_CONTRACT_ADDRESS']

__all__ = ['role', 'url', 'chain_id', 'gas_limit', 'market_contract_address', 'market_abi', 'apus_task_address', 'apus_task_abi']

if __name__ == '__main__':
    print(role.provider.public_key)
    print(role.provider.private_key)
