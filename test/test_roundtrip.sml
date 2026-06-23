(* test_roundtrip.sml -- decode . encode and encode . decode identities.

   `decode (encode v) = v` for any value built with canonically ordered dict
   keys (the encoder sorts keys, so a round trip from an already-sorted value is
   the identity). We also check `encode (decode s) = s` for canonical input
   strings, which together pin both directions on nested, torrent-shaped data. *)

structure RoundTripTests =
struct
  open Support
  structure B = Bencode

  (* A deeply nested value with keys already in canonical (ascending) order. *)
  val nested =
    B.BDict
      [ ("announce", B.BStr "http://tracker.example/announce")
      , ("info",
         B.BDict
           [ ("length", B.BInt 1024)
           , ("name", B.BStr "file.bin")
           , ("piece length", B.BInt 512)
           , ("pieces", B.BList [B.BStr "aaaa", B.BStr "bbbb"]) ])
      , ("list", B.BList [B.BInt ~1, B.BInt 0, B.BInt 1,
                          B.BInt (IntInf.pow (2, 64))]) ]

  fun run () =
    let
      val () = Harness.section "round-trip decode . encode = id"
      val () = checkRoundTrip "int" (B.BInt 42)
      val () = checkRoundTrip "neg int" (B.BInt ~99)
      val () = checkRoundTrip "big int" (B.BInt (IntInf.pow (10, 40)))
      val () = checkRoundTrip "string" (B.BStr "spam")
      val () = checkRoundTrip "empty string" (B.BStr "")
      val () = checkRoundTrip "list" (B.BList [B.BStr "spam", B.BInt 42])
      val () = checkRoundTrip "empty list" (B.BList [])
      val () = checkRoundTrip "empty dict" (B.BDict [])
      val () = checkRoundTrip "nested torrent" nested

      val () = Harness.section "round-trip encode . decode = id (strings)"
      val s1 = "d8:announce31:http://tracker.example/announce4:infod6:lengthi1024e4:name8:file.bin12:piece lengthi512e6:piecesl4:aaaa4:bbbbeee"
      val () = Harness.checkString "canonical string survives"
                 (s1, B.encode (B.decode s1))
      val () = Harness.checkString "spec dict string survives"
                 ("d3:bar4:spam3:fooi42ee",
                  B.encode (B.decode "d3:bar4:spam3:fooi42ee"))
    in
      ()
    end
end
