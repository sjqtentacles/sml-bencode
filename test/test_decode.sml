(* test_decode.sml -- decoding bencoded values from the BitTorrent spec.

   The canonical spec examples (BEP 3):
     i42e                          -> integer 42
     4:spam                        -> the byte string "spam"
     l4:spami42ee                  -> list [ "spam", 42 ]
     d3:bar4:spam3:fooi42ee        -> dict { bar = "spam", foo = 42 }

   These pin the four bencoding token kinds (integers, byte strings, lists,
   dictionaries) plus a handful of boundary cases (empty string, empty
   containers, negative and large integers). *)

structure DecodeTests =
struct
  open Support
  structure B = Bencode

  fun run () =
    let
      val () = Harness.section "decode integers"
      val () = checkValue "i42e = 42" (B.BInt 42, B.decode "i42e")
      val () = checkValue "i0e = 0" (B.BInt 0, B.decode "i0e")
      val () = checkValue "i-42e = ~42" (B.BInt ~42, B.decode "i-42e")
      (* arbitrary precision: well beyond a 64-bit integer *)
      val () = checkValue "i (2^70) e"
                 (B.BInt (IntInf.pow (2, 70)),
                  B.decode ("i" ^ IntInf.toString (IntInf.pow (2, 70)) ^ "e"))

      val () = Harness.section "decode byte strings"
      val () = checkValue "4:spam = spam" (B.BStr "spam", B.decode "4:spam")
      val () = checkValue "0: = empty" (B.BStr "", B.decode "0:")
      (* the length prefix is a byte count; colons inside are literal bytes *)
      val () = checkValue "7:a:b:c:d"
                 (B.BStr "a:b:c:d", B.decode "7:a:b:c:d")

      val () = Harness.section "decode lists"
      val () = checkValue "le = empty list" (B.BList [], B.decode "le")
      val () = checkValue "l4:spami42ee"
                 (B.BList [B.BStr "spam", B.BInt 42], B.decode "l4:spami42ee")
      (* nested list: l l 1:a e i1e e *)
      val () = checkValue "nested list"
                 (B.BList [B.BList [B.BStr "a"], B.BInt 1],
                  B.decode "ll1:aei1ee")

      val () = Harness.section "decode dicts"
      val () = checkValue "de = empty dict" (B.BDict [], B.decode "de")
      val () = checkValue "d3:bar4:spam3:fooi42ee"
                 (B.BDict [("bar", B.BStr "spam"), ("foo", B.BInt 42)],
                  B.decode "d3:bar4:spam3:fooi42ee")
      (* a torrent-shaped nested structure *)
      val () = checkValue "nested dict"
                 (B.BDict [("a", B.BInt 1),
                           ("b", B.BList [B.BStr "x", B.BInt 2])],
                  B.decode "d1:ai1e1:bl1:xi2eee")
    in
      ()
    end
end
