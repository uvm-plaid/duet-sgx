import json
import requests
import base64
import Crypto
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
from Crypto.Hash import SHA
#from Crypto import Random

#with open('/tmp/duetpublickey') as key_file:
#    key_data=key_file.read()

key_data = requests.get("http://localhost:5000/pubkey")
key_json = key_data.json()

e = key_json['e']
n = key_json['n']
#print("Key Size (bits): " + str(key_json['size'] * 8))
#print("e: " + str(e))
#print("n: " + str(n))
#print("")

public_key = RSA.construct((long(n), long(e)))
print(public_key.exportKey())
message = "1,27"

# default hash Algorithm is SHA1, mask generation function is MGF1, no label is specified
# https://pycryptodome.readthedocs.io/en/latest/src/cipher/oaep.html
cipher = PKCS1_OAEP.new(public_key)
encrypted_message = base64.encodestring(cipher.encrypt(message)).replace("\n","")

data = { "value" : encrypted_message }
headers = { 'Content-type': 'application/json', 'Accept': 'application/json' }
requests.post('http://localhost:5000/insert', data=json.dumps(data), headers=headers)
#print(encrypted_message)
