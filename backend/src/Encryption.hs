{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GADTs #-}

module Encryption where

import           Crypto.Cipher.AES (AES128)
import           Crypto.Cipher.Types (BlockCipher(..), Cipher(..), nullIV, KeySizeSpecifier(..), IV, makeIV)
import           Crypto.Error (CryptoFailable(..), CryptoError(..))

import qualified Crypto.Random.Types as CRT

import           Data.ByteArray (ByteArray, Bytes)
import           Data.ByteString (ByteString)
import           Data.Word (Word8)
import           Data.ByteArray.Encoding as BAE
--import           Data.ByteString.Char8 (pack)
import           Data.ByteString.Char8 as C8 (pack, unpack)
import           Data.ByteArray.Parse
import           Data.ByteString as BS (unpack, take, drop, pack)
import Debug.Trace

import UVMHS.Init
import Prelude (Either(Left, Right), Maybe(Just, Nothing), return, (>>), (>>=), String, Int, putStrLn, fmap, (.), (++))

-------------------------

import qualified Crypto.PubKey.RSA as RSA
import qualified Crypto.PubKey.RSA.OAEP as OAEP
import qualified Crypto.PubKey.RSA.PSS as PSS
import qualified Crypto.Hash.Algorithms as HASH
import qualified GHC.Natural as Nat
import Data.Text
import qualified Data.Text.Encoding as E
import qualified Crypto.Store.X509 as PEM
import qualified Data.X509 as X509

--import Data.Either

pubJson :: RSA.PublicKey -> String
pubJson p = (chars "{\"size\": ") ++ (show (RSA.public_size p)) ++
            (chars ",\"n\": ") ++ (show (RSA.public_n p)) ++
            (chars ",\"e\": ") ++ (show (RSA.public_e p)) ++ (chars " }")

pubPEM :: RSA.PublicKey -> String -> IO ()
pubPEM p path = PEM.writePubKeyFile path (X509.PubKeyRSA p : [])

-- 512 bytes = 4096 bit keys
genKeyPair :: CRT.MonadRandom m => m (RSA.PublicKey, RSA.PrivateKey)
genKeyPair = RSA.generate (Nat.naturalToInt 512) (Nat.naturalToInteger 65537)

encryptRSA :: CRT.MonadRandom m => RSA.PublicKey -> Text -> m (Text)
encryptRSA p a = do
  bs <- return $ E.encodeUtf8 a
  x <- OAEP.encrypt (OAEP.defaultOAEPParams HASH.SHA1) p bs
  case x of
    Left e -> return $ fromChars $ show e
    Right b -> return $ E.decodeUtf8 $ BAE.convertToBase BAE.Base64 b

decryptRSA :: CRT.MonadRandom m => RSA.PrivateKey -> Text -> m (Text)
decryptRSA r a = do
  bs <- return $ fromB64str a
  x <- OAEP.decryptSafer (OAEP.defaultOAEPParams HASH.SHA1) r bs
  case x of
    Left e -> return $ fromChars $ show e
    Right b -> return $ E.decodeUtf8 $ b

fromB64str :: Text -> ByteString
fromB64str t = case BAE.convertFromBase BAE.Base64 (C8.pack $ chars t) of
  Left str -> C8.pack str
  Right msg -> msg

-- (key, message) -> signature
signRSA :: CRT.MonadRandom m => RSA.PrivateKey -> Text -> m (Text)
signRSA r a = do
  bs <- return $ E.encodeUtf8 a
  x <- PSS.signSafer PSS.defaultPSSParamsSHA1 r bs
  case x of
    Left e -> return $ fromChars $ show e
    Right b -> return $ E.decodeUtf8 $ BAE.convertToBase BAE.Base64 b

-- (key , message , signature) -> verify_result
verifyRSA :: RSA.PublicKey -> Text -> Text -> Bool
verifyRSA p m sig = PSS.verify PSS.defaultPSSParamsSHA1 p (C8.pack $ chars m) (fromB64str sig)

-------------------------

-- | Not required, but most general implementation
data Key c a where
  Key :: (BlockCipher c, ByteArray a) => a -> Key c a

-- | Generates a string of bytes (key) of a specific length for a given block cipher
genSecretKey :: forall m c a. (CRT.MonadRandom m, BlockCipher c, ByteArray a) => c -> Int -> m (Key c a)
genSecretKey _ = fmap Key . CRT.getRandomBytes

mkKey :: forall c a. (BlockCipher c, ByteArray a) => a -> (Key c a)
mkKey b = Key b

-- | Generate a random initialization vector for a given block cipher
genRandomIV :: forall m c. (CRT.MonadRandom m, BlockCipher c) => c -> m (Maybe (IV c))
genRandomIV _ = do
  bytes :: ByteString <- CRT.getRandomBytes $ blockSize (undefined :: c)
  return $ makeIV bytes

-- | Initialize a block cipher
initCipher :: (BlockCipher c, ByteArray a) => Key c a -> Either CryptoError c
initCipher (Key k) = case cipherInit k of
  CryptoFailed e -> Left e
  CryptoPassed a -> Right a

encrypt :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> a -> Either CryptoError a
encrypt secretKey initIV msg =
  case initCipher secretKey of
    Left e -> Left e
    Right c -> Right $ ctrCombine c initIV msg

decrypt :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> a -> Either CryptoError a
decrypt = encrypt

-- exampleAES128 :: ByteString -> IO ()
-- exampleAES128 msg = do
--   -- secret key needs 128 bits (16 * 8)
--   secretKey <- genSecretKey (undefined :: AES128) 16
--   mInitIV <- genRandomIV (undefined :: AES128)
--   case mInitIV of
--     Nothing -> error "Failed to generate an initialization vector."
--     Just initIV -> do
--       let encryptedMsg = encrypt secretKey initIV msg
--           decryptedMsg = decrypt secretKey initIV =<< encryptedMsg
--       case (,) <$> encryptedMsg <*> decryptedMsg of
--         Left err -> error $ show err
--         Right (eMsg, dMsg) -> do
--           putStrLn $ "Original Message: " ++ show msg
--           putStrLn $ "Message after encryption: " ++ show eMsg
--           putStrLn $ "Message after decryption: " ++ show dMsg

-- example1AES128 :: [ByteString] -> IO ()
-- example1AES128 msg = do
--   -- secret key needs 128 bits (16 * 8)
--   secretKey <- genSecretKey (undefined :: AES128) 16
--   mInitIV <- genRandomIV (undefined :: AES128)
--   case mInitIV of
--     Nothing -> error "Failed to generate and initialization vector."
--     Just initIV -> do
--       let encryptedMsg = encryptCSV secretKey initIV msg
--           decryptedMsg = decryptCSV secretKey initIV encryptedMsg
--       case (encryptedMsg, decryptedMsg) of
--         (eMsg, dMsg) -> do
--           putStrLn $ "Original Message: " ++ show msg
--           putStrLn $ "Message after encryption: " ++ show eMsg
--           putStrLn $ "Message after decryption: " ++ show dMsg

encryptCSV :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> [a] -> [a]
encryptCSV _ _ [] = []
encryptCSV secretKey initIV (x:xs) =
  case encrypt secretKey initIV x of
    Left err -> error $ fromChars $ show err
    Right eMsg -> eMsg : encryptCSV secretKey initIV xs

decryptCSV :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> [a] -> [a]
decryptCSV = encryptCSV

testData = [ "4QRgTpBlb3SrlSuNZoEb81gGg8loAY0WPMrvDjw="
           , "I1hsCJeIvXyDayInWk6cUxBjWeabdbQPsYrZCgcemnrqPp0usiZvgxpEeb+B"
           , "XslX0ge8va7RzIJigLttGQWKjR5LHXNmnrFw3MUTF1FibY1pnZLWlB28HWjs"
           , "cWE6Fx5yZh05p+OHKfkFb0RPMyBjAC4A5/OmuJy9ST4ezz7Jp0iRl+kjs4ww"
           , "UbBHGq2X3vU6+bEJgl/KEr9ZE0cE6sPb+H3dtyO1xRKDzxxeSvdK9Msneyn1"
           ]

-- expect 128-bit AES/GCM/no padding
-- 16 bit IV
-- base64-encoded
-- IV prepended to ciphertext
helioKey = "zhSbzcTqb9kLJw2mJpmfFw=="

-- main = exampleAES128 "Hello, World!"
-- main = example1AES128 ["Hello, World!", "Goodbye, World!"]

blockSize' :: forall c. (BlockCipher c) => P c -> Int
blockSize' _ =
  let ~tmp = (undefined :: c)
  in blockSize tmp

getIV :: forall c. (BlockCipher c) => P c -> ByteString -> Maybe (IV c)
getIV _ bs =
  let ivBytes :: ByteString = BS.take (blockSize' @ c P) bs
  in makeIV ivBytes

getIVs :: forall c. (BlockCipher c) => P c -> ByteString -> ByteString
getIVs _ bs =
  let ivBytes :: ByteString = BS.take (blockSize' @ c P) bs
  in ivBytes

getMsg :: forall c. (BlockCipher c) => P c -> ByteString -> ByteString
getMsg _ bs =
  let msgBytes :: ByteString = BS.drop (blockSize' @ c P) bs
  in msgBytes

decryptString :: String -> String
decryptString msg =
  let keyByteString :: ByteString = C8.pack $ chars helioKey
      key :: Either String ByteString = BAE.convertFromBase BAE.Base64 keyByteString
  in case key of
    Right k ->
      let key' = mkKey @ AES128 k
      in case BAE.convertFromBase BAE.Base64 $ C8.pack msg of
        Right testD ->
          let ivBytes :: ByteString = getIVs @ AES128 P testD
              ivM :: Maybe (IV AES128) = getIV @ AES128 P testD
              msg' :: ByteString = getMsg @ AES128 P testD
          in case ivM of
            Just iv -> C8.unpack $ decryptOne key' iv msg'
            _ -> error $ fromChars $ show msg
        Left e -> error $ fromChars $ show e

encryptOne :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> a -> a
encryptOne secretKey initIV x =
  case encrypt secretKey initIV x of
    Left err -> error $ fromChars $ show err
    Right eMsg -> eMsg

decryptOne :: (BlockCipher c, ByteArray a) => Key c a -> IV c -> a -> a
decryptOne = encryptOne


main = do
  (p,r) <- genKeyPair
  putStrLn $ show "Encrypted string with public key:"
  c <- encryptRSA p "Hello123"
  putStrLn $ show c
  putStrLn $ show "Decrypted string with private key:"
  d <- decryptRSA r c
  putStrLn $ show d
  putStrLn $ show "Signature of Hello123:"
  s <- signRSA r d
  putStrLn $ show s
  putStrLn $ show "Verifying Signature:"
  v <- return $ verifyRSA p d s
  putStrLn $ show v

--main = do
--  putStrLn $ decryptString $ chars "4QRgTpBlb3SrlSuNZoEb81gGg8loAY0WPMrvDjw="
--  putStrLn $ decryptString $ chars "p8r8qdmh/AvWyd2Fh257tP+iduiuSHZIs1DeqO6nF5FRpLiMQxU99bG2T65NupmMp9pbaK/K9XEQtsyhf1f9j1CgTSh+2mKX1XxD3aJNazMn1LySgye0P6xqkzzwNbmRloy+"
--  putStrLn $ decryptString $ chars "hjWq++DlsJMUgjqIFVxfJy48rLGo+urBdbeSUOnoNOaWKCsSMWkC9eCZhxT134XgvRtuvX12zfnCDZv87kAyGEZVIxpmV3FyqThH6Rv2au51zW9ZM69rR+g90jDG5TW+yQ=="

-- main = do
--   let keyByteString :: ByteString = pack helioKey
--   --let keyWords :: [Word8] = Data.ByteString.unpack keyByteString
--   -- should be 16 bytes! how do we write this annotation?
--   let key :: Either String ByteString = BAE.convertFromBase BAE.Base64 keyByteString
--   case key of
--     Right k -> do
--       let key' = mkKey (undefined :: AES128) k
--           msg :: ByteString = pack "hello"
--       putStrLn $ "Bytes of decoded key: " ++ (show $ BS.unpack k)
--       mInitIV <- genRandomIV (undefined :: AES128)

--       let testDB :: ByteString = pack $ head testData
--       case BAE.convertFromBase BAE.Base64 $ testDB of
--         Right testD -> do
--           let ivBytes :: ByteString = getIVs (undefined :: AES128) testD
--           putStrLn $ "bytes of iv: " ++ (show $ BS.unpack ivBytes)

--           let ivM :: Maybe (IV AES128) = getIV (undefined :: AES128) testD
--               msg :: ByteString = getMsg (undefined :: AES128) testD
--           putStrLn $ "bytes of encrypted message: " ++ (show $ BS.unpack testD)
--           putStrLn $ "bytes of just message part: " ++ (show $ BS.unpack msg)
--           case ivM of
--             Just iv -> putStrLn $ show $ decryptCSV key' iv [msg]
--             _ -> error $ "Failed to compute IV"
--         Left e -> error $ show e

--     Left err -> error $ show err

