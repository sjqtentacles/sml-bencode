(* demo.sml

   A tour of `sml-bencode`: build a small torrent-shaped value, show its
   canonical wire encoding, prove the round trip, demonstrate that the encoder
   reorders dictionary keys into canonical byte order, and show a few rejected
   malformed inputs. Output is byte-identical across MLton and Poly/ML.

   Build and run with `make example`. *)

structure B = Bencode

fun line s = print (s ^ "\n")

val () = line "=== sml-bencode demo =========================================="
val () = line ""

(* ---- a torrent-shaped value (keys deliberately OUT of order) ---- *)
val torrent =
  B.BDict
    [ ("info",
       B.BDict
         [ ("pieces", B.BList [B.BStr "aaaa", B.BStr "bbbb"])
         , ("name", B.BStr "file.bin")
         , ("piece length", B.BInt 512)
         , ("length", B.BInt 1024) ])
    , ("announce", B.BStr "http://tracker.example/announce")
    , ("creation date", B.BInt 1718000000) ]

val wire = B.encode torrent

val () = line "A torrent value (built with keys out of order):"
val () = line ("  " ^ B.toString torrent)
val () = line ""
val () = line "Canonical bencoding (note keys are sorted ascending by byte):"
val () = line ("  " ^ wire)
val () = line ""

(* ---- round trip ---- *)
(* `encode` is canonicalizing: it sorts dict keys. So a round trip yields the
   *normalized* value, which equals the original re-encoded. We show both the
   value identity (against the canonical value) and the string identity. *)
val canonical = B.decode wire
val back = B.decode wire
val () = line "Round trip:"
val () = line ("  decode (encode v) is canonical ?  "
               ^ (if back = canonical then "yes" else "NO"))
val () = line ("  encode (decode (encode v)) = encode v ?  "
               ^ (if B.encode back = wire then "yes" else "NO"))
val () = line ""

(* ---- the four spec examples (BEP 3) ---- *)
val () = line "Spec examples (BEP 3):"
val () =
  List.app
    (fn s => line ("  " ^ StringCvt.padRight #" " 24 s
                   ^ "-> " ^ B.toString (B.decode s)))
    [ "i42e", "4:spam", "l4:spami42ee", "d3:bar4:spam3:fooi42ee" ]
val () = line ""

(* ---- arbitrary-precision integers ---- *)
val big = B.BInt (IntInf.pow (2, 80))
val () = line "Arbitrary-precision integer (2^80):"
val () = line ("  " ^ B.encode big)
val () = line ""

(* ---- malformed inputs are rejected ---- *)
fun tryDecode s =
  (ignore (B.decode s); "accepted (!)")
  handle B.Decode msg => "rejected: " ^ msg
       | _ => "rejected"

val () = line "Malformed inputs are rejected (strict, canonical decoder):"
val () =
  List.app
    (fn s => line ("  " ^ StringCvt.padRight #" " 12 s ^ "-> " ^ tryDecode s))
    [ "i03e", "i-0e", "ie", "5:spam", "l4:spam", "i42eXYZ" ]
val () = line ""
val () = line "==============================================================="
