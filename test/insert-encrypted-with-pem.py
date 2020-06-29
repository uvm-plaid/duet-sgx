import json
import requests
import base64
import Crypto
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
from Crypto.Hash import SHA
#from Crypto import Random

public_key = RSA.importKey(open('/tmp/duetpublickey.pem').read())
message = "1,27"

# default hash Algorithm is SHA1, mask generation function is MGF1, no label is specified
# https://pycryptodome.readthedocs.io/en/latest/src/cipher/oaep.html
cipher = PKCS1_OAEP.new(public_key)
encrypted_message = base64.encodestring(cipher.encrypt(message)).replace("\n","")

data = { "value" : encrypted_message }
headers = { 'Content-type': 'application/json', 'Accept': 'application/json' }
requests.post('http://localhost:5000/insert', data=json.dumps(data), headers=headers)
#print(encrypted_message)
