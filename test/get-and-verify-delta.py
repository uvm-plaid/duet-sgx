import json
import requests
import base64
import Crypto
from Crypto.PublicKey import RSA
from Crypto.Signature import PKCS1_PSS
from Crypto.Hash import SHA

privacy_data = requests.get("http://localhost:5000/delta")
privacy_json = privacy_data.json()
message = privacy_json['delta']
sig = privacy_json['signature']

key_data = requests.get("http://localhost:5000/pubkey")
key_json = key_data.json()
e = key_json['e']
n = key_json['n']

# https://pycryptodome.readthedocs.io/en/latest/src/signature/pkcs1_pss.html
public_key = RSA.construct((long(n), long(e)))
h = SHA.new(message)
verifier = PKCS1_PSS.new(public_key)
if verifier.verify(h, base64.decodestring(sig)):
    print("The signature is authentic.")
    print("The value of delta is " + message)
else:
    print("The signature is not authentic.")
