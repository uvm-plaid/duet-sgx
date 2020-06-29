module Main where

import Duet
import Encryption (pubPEM, pubJson, genKeyPair, signRSA, verifyRSA, decryptRSA, decryptString)
import System.Directory
import Control.Concurrent

import Data.Text (Text (..))
import qualified Data.Text as T (head, splitOn, filter, map)
import qualified Data.ByteString as BS
import qualified Data.Text.Encoding as D
import System.IO as IO
import Data.Text.IO as I
import System.IO.Unsafe as UIO

import qualified Prelude as P (head, (<=) ,(/=), truncate, abs)
import qualified Crypto.PubKey.RSA as RSA

initEnv ∷ 𝕏 ⇰ Type RNF
initEnv = dict
  [ var "sign" ↦ ((Nil :* ℝT) :⊸: (ι 1 :* ℝT))
  -- , var "pmmap" ↦ (A@p ⊸⋆ B) ⊸∞ M[c,ℓ|m,n]A@(mnp) ⊸⋆ M[U,ℓ|m,n]B
  ]

parseMode ∷ 𝕊 → Ex_C PRIV_C PRIV_W
parseMode s = case list $ splitOn𝕊 "." s of
  _ :& "eps" :& "duet" :& Nil → Ex_C EPS_W
  _ :& "ed" :& "duet" :& Nil → Ex_C ED_W
  _ :& "renyi" :& "duet" :& Nil → Ex_C RENYI_W
  _ :& "tcdp" :& "duet" :& Nil → Ex_C TC_W
  _ :& "zcdp" :& "duet" :& Nil → Ex_C ZC_W
  _ → error "BAD FILE NAME"

parseMatrix𝔻  ∷ 𝕊 → ExMatrix 𝔻
parseMatrix𝔻 s = unID $ do
  Main.traceM "PARSING MATRIX…"
  let dss ∷ 𝐼 (𝐼 𝔻)
      dss = map (map read𝕊 ∘ iter ∘ splitOn𝕊 ",") $ filter (\x → not (isEmpty𝕊 x)) $ splitOn𝕊 "\n" s
      dss' ∷ 𝐿 (𝐿 𝔻)
      dss' = list $ map list dss
  xu dss' $ \ m → do
    Main.traceM "DONE"
    return $ ExMatrix $ xvirt m

maybeDecrypt ∷ RSA.PrivateKey -> 𝕊 → 𝕊 → IO 𝕊
maybeDecrypt prvkey s fileName = case list $ splitOn𝕊 "." fileName of
  _ :& _ :& "encrypted" :& Nil → do
    let lines ∷ 𝐿 𝕊 = list $ filter (\x → not (isEmpty𝕊 x)) $ splitOn𝕊 "\n" s
    decrypted <- map (intercalate "\n") $ mapM (decryptRSA prvkey) $ lines
    return $ Main.trace (pprender decrypted) decrypted
  _ → return s

trace :: 𝕊 → a → a
trace s x = unsafePerformIO $ do
  out s
  return x

traceM ∷ (Monad m) ⇒ 𝕊 → m ()
traceM msg = Main.trace msg skip

-- TODO: detect line endings or make an arg
buildArgs ∷ (Pretty r) ⇒ RSA.PrivateKey -> 𝐿 (Type r) → 𝐿 𝕊 → IO (𝐿 Val)
buildArgs key Nil Nil = return Nil
buildArgs key (τ:&τs) (a:&as) = Main.trace ("parsing " ⧺ a) $ case τ of
  -- TODO: currently the assumption is to read in RealVs
  (𝕄T _ _ _ (RexpME r τ)) → do
    sᵢ ← readUTF8 a
    s <- maybeDecrypt key sᵢ a
    case parseMatrix𝔻 s of
      ExMatrix m →  do
        let m' = case τ of
              𝔻T ℝT → map RealV m
              𝔻T ℕT → map (NatV ∘ intNat ∘ P.truncate) m
        let m'' = MatrixV $ ExMatrix $ m'
        r ← buildArgs key τs as
        return $ m'' :& r
  (𝕄T _ _ _ (ConsME τ m)) → do
    csvs₁ ← readUTF8 a
    csvs <- maybeDecrypt key csvs₁ a
    let csvss = map (splitOn𝕊 ",") $ filter (\x → not (isEmpty𝕊 x)) $ splitOn𝕊 "\n" csvs
    let csvm = csvToDF (list $ map list csvss) (schemaToTypes (ConsME τ m))
    r ← buildArgs key τs as
    return $ csvm :& r
  SetT (τ₁ :×: τ₂) → do
    csvs ← readUTF8 a
    let csvss = map (splitOn𝕊 ",") $ filter (\x → not (isEmpty𝕊 x)) $ splitOn𝕊 "\n" csvs
    let csvm = csvToPairSet (list $ map list csvss) (list [τ₁, τ₂])
    r ← buildArgs key τs as
    return $ csvm :& r
  ℕT → do
    s ← readUTF8 a
    let (v :& _) = list $ splitOn𝕊 "\n" s
    r ← buildArgs key τs as
    return $ NatV (read𝕊 v) :& r
  ℕˢT _ → do
    s ← readUTF8 a
    let (v :& _) = list $ splitOn𝕊 "\n" s
    r ← buildArgs key τs as
    return $ NatV (read𝕊 v) :& r
  ℝT → do
    s ← readUTF8 a
    let (v :& _) = list $ splitOn𝕊 "\n" s
    r ← buildArgs key τs as
    return $ RealV (read𝕊 v) :& r
  ℝˢT _ → do
    s ← readUTF8 a
    let (v :& _) = list $ splitOn𝕊 "\n" s
    r ← buildArgs key τs as
    return $ RealV (read𝕊 v) :& r
  _ → error $ "unexpected arg type in main: " ⧺ (ppshow τ)
buildArgs _ _ _ = error "number of args provided does not match function signature"

drop :: ℕ -> IO (𝐼 𝕊) -> IO (𝐼 𝕊)
drop x as = do
  as' ← as
  case list as' of
    Nil → return empty𝐼
    (_ :& ys) → do
      case x ≡ 1 of
        True → return $ iter ys
        False → drop (x-1) (return (iter ys))

intercalate ∷ 𝕊 → 𝐿 𝕊 → 𝕊
intercalate sep arr = case arr of
  Nil -> ""
  (x :& Nil) -> x
  (x :& xs) -> x ⧺ sep ⧺ intercalate sep xs

readUTF8 :: 𝕊 → IO 𝕊
readUTF8 s = readFileUTF8 $ chars s

readFileUTF8 :: FilePath -> IO Text
readFileUTF8 s = do
  handle <- IO.openFile s IO.ReadMode
  contents <- BS.hGetContents handle
  hClose handle
  return $ D.decodeUtf8 contents

main ∷ IO ()
main = do
  --------------- duet-sgx initialization ---------------
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  (pubkey, privkey) <- genKeyPair
  --write "/tmp/duetpublickey" $ fromChars $ pubJson pubkey
  pubPEM pubkey $ chars "/tmp/duetpublickey.pem"

  (tohs ∘ list) ^⋅ args ≫= \case
    ["parse",fn] → do
      do pprint $ ppHeader "READING"
      s ← readUTF8 fn
      do pprint $ ppHeader "TOKENIZING"
      ts ← tokenizeIO tokDuet $ stream $ list $ tokens s
      do pprint $ ppHeader "PARSING"
      unpack_C (parseMode fn) $ \ mode →
        parseIOMain (pSkip tokSkip $ pFinal $ parSExp mode) $ stream ts
    ["check",fn] → do
      do pprint $ ppHeader "READING"
      s :* tRead ← timeIO $ readUTF8 fn
      do out $ "(" ⧺ show𝕊 (secondsTimeD tRead) ⧺ "s)"
      do pprint $ ppHeader "TOKENIZING"
      ts :* tToken ← timeIO $ tokenizeIO tokDuet $ stream $ list $ tokens s
      do out $ "(" ⧺ show𝕊 (secondsTimeD tToken) ⧺ "s)"
      unpack_C (parseMode fn) $ \ mode → do
        do pprint $ ppHeader "PARSING"
        e :* tParse ← timeIO $ parseIO (pSkip tokSkip $ pFinal $ parSExp mode) $ stream ts
        do out $ "(" ⧺ show𝕊 (secondsTimeD tParse) ⧺ "s)"
        do pprint $ ppHeader "TYPE CHECKING"
        r :* tCheck ← time (\ () → runSM dø initEnv dø $ inferSens e) ()
        out ("Privacy cost: " ⧺ (pprender $ getPrivacyCost r))
        do out $ "(" ⧺ show𝕊 (secondsTimeD tCheck) ⧺ "s)"
        -- _ ← shell $ "echo " ⧺ show𝕊 (secondsTimeD tCheck) ⧺ " >> typecheck-times"
        do pprint $ ppHeader "DONE"
        do pprint r
    "lr-accuracy":xsfn:ysfn:mdfn:[] → do
      do pprint $ ppHeader "ACCURACY TEST"
      sxs ← read xsfn
      sys ← read ysfn
      smd ← read mdfn
      case (parseMatrix𝔻 sxs,parseMatrix𝔻 sys,parseMatrix𝔻 smd) of
        (ExMatrix mxs,ExMatrix mys,ExMatrix mmd) → do
          let xs ∷ ExMatrix 𝔻
              xs = ExMatrix mxs
              ys ∷ DuetVector 𝔻
              ys = list mys
              md ∷ DuetVector 𝔻
              md = list mmd
              (r :* w) = accuracy xs ys md
          write "out/acc.csv" (intercalate "," (map show𝕊 (list [r,w])))
          pprint (r,w)
          pprint $ concat [ pretty (100.0 × dbl r / dbl (r+w)) , ppText "%" ]
    "run":fn:_ → do
      all_args ← drop 2 args

      --------- retrieve our initial epsilon and delta values --------
      let (epsilonFilename :& deltaFilename :& fnargs) = list all_args
      e <- readUTF8 epsilonFilename
      (epsilon':_) <- return $ T.splitOn "," e
      epsilon <-return $ (T.filter (P./= '"')) epsilon'
      d <- readUTF8 deltaFilename
      (delta':_) <- return $ T.splitOn "," d
      delta <- return $ (T.filter (P./= '"')) delta'

      ----------- sign provided epsilon and delta on startup ----------
      ε_sig <- signRSA privkey $ fromChars $ show epsilon
      write epsilonFilename $ (fromChars $ show epsilon) ⧺ "," ⧺ ε_sig
      δ_sig <- signRSA privkey $ fromChars $ show delta
      write deltaFilename $ (fromChars $ show delta) ⧺ "," ⧺ δ_sig

      --------------- start main execution loop ----------------
      runProg (pubkey, privkey) fn (read𝕊 epsilon) (read𝕊 delta)
    _ → do
      pprint $ ppHeader "USAGE"
      out $ "duet parse <file>"
      out $ "duet check <file>"

getPrivacyCost ∷ TypeError ∨ ((𝕏 ⇰ Sens RNF) ∧ Type RNF) → (𝔻, 𝔻)
getPrivacyCost τ =
  case τ of
    Inr (_ :* ((_ :* PArgs ((_ :* pp) :& Nil)) :⊸⋆: _)) →
      case pp of
        Priv (Quantity (EDPriv ε δ)) →
          case (ε, δ) of
            (NNRealRNF εₙ, NNRealRNF δₙ) → (εₙ, δₙ)
            (_, _) → error $ "Failed to find constant privacy cost in: " ⧺ (pprender (ε, δ))
        _ → error $ "Wrong shape for type: " ⧺ (pprender τ)

staging ∷ (RSA.PublicKey, RSA.PrivateKey) → Text → 𝔻 -> 𝔻 -> IO ()
staging (pubkey, privkey) fn ε_total δ_total = do
  all_args ← drop 2 args

  --------- retrieve our signed epsilon and delta values ---------
  let (epsilonFilename :& deltaFilename :& fnargs) = list all_args
  e <- readUTF8 epsilonFilename
  (epsilon : esig : _) <- return $ T.splitOn "," e
  d <- readUTF8 deltaFilename
  (delta : dsig : _) <- return $ T.splitOn "," d

  --------------- verify epsilon and delta signatures ----------------
  case (verifyRSA pubkey epsilon esig, verifyRSA pubkey delta dsig) of
    (True, True) -> do
      out "Successfully verified signatures for epsilon and delta"
      runProg (pubkey, privkey) fn (read𝕊 epsilon) (read𝕊 delta)
    (False, True) -> do out "Cannot verify the signature of epsilon."
    (True, False) -> do out "Cannot verify the signature of delta."
    (False, False) -> do out "Cannot verify the signature of epsilon and delta."

runProg ∷ (RSA.PublicKey, RSA.PrivateKey) → Text → 𝔻 -> 𝔻 -> IO ()
runProg (pubkey, privkey) fn ε_total δ_total = do
  toggle ← readUTF8 "/tmp/runquery"
  status ← return $ T.head toggle
  case status of
    '0' → do
      threadDelay $ tohs $ 𝕫32 100000
      runProg (pubkey, privkey) fn ε_total δ_total
    '1' → do
      do pprint $ ppHeader "READING"
      s ← readUTF8 fn
      do pprint $ ppHeader "TOKENIZING"
      ts ← tokenizeIO tokDuet $ stream $ list $ tokens s
      do pprint $ ppHeader "PARSING"
      unpack_C (parseMode fn) $ \ mode → do
        e ← parseIO (pSkip tokSkip $ pFinal $ parSExp mode) $ stream ts
        do pprint $ ppHeader "TYPE CHECKING"
        let τ = runSM dø initEnv dø $ inferSens e

        -- ε and δ are real values (doubles)
        let (ε, δ) = getPrivacyCost τ
        out ("Privacy cost: " ⧺ (pprender (ε, δ)))

        do out $ ppshow τ
        do pprint $ ppHeader "RUNNING"
        let r = seval dø (extract e)
        do out $ ppshow r

        -- ignore the executable name and Duet file name
        all_args ← drop 2 args

        -- the first two arguments are the files for the epsilon and delta *budgets*
        let (epsilonFilename :& deltaFilename :& fnargs) = list all_args

        -- calc new budget
        let ε_new = ε_total - ε
        let δ_new = δ_total - δ

        -- we reject queries that reduce epsilon or delta to 0 or below
        case (ε_new P.<= 0.0, δ_new P.<= 0.0)  of
          (True, _) -> do
            do pprint $ ppHeader "QUERY REJECTED"
            write "/tmp/output.json" "\"ERROR\""
            pprint $ ppHeader "DONE"
            write "/tmp/runquery" "0"
            runProg (pubkey, privkey) fn ε_total δ_total
          (_, True) -> do
            do pprint $ ppHeader "QUERY REJECTED"
            write "/tmp/output.json" "\"ERROR\""
            pprint $ ppHeader "DONE"
            write "/tmp/runquery" "0"
            runProg (pubkey, privkey) fn ε_total δ_total
          (False, False) -> do
            -- sign and write out new budgets
            ε_sig <- signRSA privkey $ fromChars $ show ε_new
            write epsilonFilename $ (fromChars $ show ε_new) ⧺ "," ⧺ ε_sig
            δ_sig <- signRSA privkey $ fromChars $ show δ_new
            write deltaFilename $ (fromChars $ show δ_new) ⧺ "," ⧺ δ_sig

            case τ of
              Inr rv → do
                case rv of
                  _ :* (_ :* PArgs pargs) :⊸⋆: _ → do
                    let τs = map fst pargs
                    do pprint $ ppHeader "Parsing command-line arguments..."
                    as ← buildArgs privkey τs (list fnargs)
                    do pprint $ ppHeader "Done parsing arguments"
                    --do pprint $ pprender as
                    case r of
                      PFunV xs (ExPriv (Ex_C e₁)) γ → do
                        r' ← peval (assoc (zip xs as) ⩌ γ) e₁
                        case r' of
                          MatrixV m → do
                            out $ ppshow r'
                            write "out/model.csv" (intercalate "\n" (map (intercalate ",") (mapp (show𝕊 ∘ urv) (toRows m))))
                          _ → do
                            out $ ppshow r'
                            write "/tmp/output.json" $ printJSON r'
                        pprint $ ppHeader "DONE"
                        write "/tmp/runquery" "0"
                        staging (pubkey, privkey) fn ε_new δ_new
                      _ → error "expected pλ at top level"
                  _ → error "expected pλ at top level"
              _ → error "typechecking phase encountered an error"
    _ → do
      IO.putStrLn $ show status
      out $ "error parsing /tmp/runquery"

printJSON ∷ Val → 𝕊
printJSON v =  (printJSONr v) ⧺ "\n"

printJSONr ∷ Val → 𝕊
printJSONr v = case v of
  NatV n → show𝕊 n
  RealV n → show𝕊 n
  BoolV True → "\"True\""
  BoolV False → "\"False\""
  PairV (v₁ :* v₂) → "[ " ⧺ (printJSONr v₁) ⧺ ", " ⧺ (printJSONr v₂) ⧺ " ]"
  SetV vs → "[\n" ⧺ (intercalate ",\n" $ map printJSONr (list vs)) ⧺ " ]"
  MatrixV (ExMatrix v) → "[" ⧺ (intercalate ",\n" $ map (\row → (intercalate "," $ map printJSONr $ list row)) $ list $ xsplit v) ⧺ "]"
  StrV v → v
  _ → show𝕊 v

intNat ∷ ℤ → ℕ
intNat = natΩ ∘ P.abs
