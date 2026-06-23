(* test_encode.sml -- canonical encoding.

   Encoding is canonical, which for bencoding means exactly one rule with teeth:
   dictionary keys are emitted sorted ascending by raw byte order, regardless of
   the order the pairs were supplied in. Integers carry no leading zeros and no
   negative zero (those are produced by `IntInf.toString` for free, so the tests
   simply pin the spec strings). *)

structure EncodeTests =
struct
  open Support
  structure B = Bencode

  fun run () =
    let
      val () = Harness.section "encode integers"
      val () = Harness.checkString "encode 42" ("i42e", B.encode (B.BInt 42))
      val () = Harness.checkString "encode 0" ("i0e", B.encode (B.BInt 0))
      val () = Harness.checkString "encode ~42" ("i-42e", B.encode (B.BInt ~42))
      val () = Harness.checkString "encode 2^70"
                 ("i" ^ IntInf.toString (IntInf.pow (2, 70)) ^ "e",
                  B.encode (B.BInt (IntInf.pow (2, 70))))

      val () = Harness.section "encode byte strings"
      val () = Harness.checkString "encode spam"
                 ("4:spam", B.encode (B.BStr "spam"))
      val () = Harness.checkString "encode empty" ("0:", B.encode (B.BStr ""))

      val () = Harness.section "encode lists"
      val () = Harness.checkString "encode []" ("le", B.encode (B.BList []))
      val () = Harness.checkString "encode [spam,42]"
                 ("l4:spami42ee",
                  B.encode (B.BList [B.BStr "spam", B.BInt 42]))

      val () = Harness.section "encode dicts (canonical key order)"
      (* keys supplied in spec order stay put *)
      val () = Harness.checkString "encode sorted keys"
                 ("d3:bar4:spam3:fooi42ee",
                  B.encode (B.BDict [("bar", B.BStr "spam"),
                                     ("foo", B.BInt 42)]))
      (* keys supplied OUT of order are reordered to ascending byte order *)
      val () = Harness.checkString "encode reorders keys"
                 ("d3:bar4:spam3:fooi42ee",
                  B.encode (B.BDict [("foo", B.BInt 42),
                                     ("bar", B.BStr "spam")]))
      (* byte order, not length: "b" (0x62) sorts after "ab" (0x61 ...) *)
      val () = Harness.checkString "encode byte-order keys"
                 ("d1:ai1e2:abi2e1:bi3ee",
                  B.encode (B.BDict [("b", B.BInt 3),
                                     ("ab", B.BInt 2),
                                     ("a", B.BInt 1)]))
      val () = Harness.checkString "encode empty dict"
                 ("de", B.encode (B.BDict []))
    in
      ()
    end
end
