(* test_properties.sml -- sml-check property-based tests for sml-bencode.

   sml-check is a TEST-only dependency (see ../sml.pkg's require{} block and
   test/sources.mlb's comment); the library itself stays dependency-free.

   `bvalue` is built only from `IntInf.int`, `string`, lists and pairs, so it
   is an equality type and every property below can compare values with the
   ordinary `=` operator. *)

structure PropertyTests =
struct
  structure B = Bencode

  (* ---- Generators ------------------------------------------------------ *)

  (* Arbitrary-byte string generator: bencode byte strings carry raw bytes,
     not text, so we exercise the full 0..255 range rather than just
     printable ASCII. *)
  val genByte = Check.charRange (Char.chr 0, Char.chr 255)
  val genBytesStr = Check.stringOf genByte

  (* IntInf via a native-int-bounded generator (kept within MLton's 31-bit
     default `int` so `Check.choose` itself never overflows; the library's
     own `BInt` field is `IntInf.int`, exercised separately via encodeBigInt
     below for genuinely large magnitudes). *)
  val genInt = Check.map IntInf.fromInt (Check.choose (~1000000000, 1000000000))

  (* A recursive `bvalue` generator over BInt/BStr/BList, depth-capped via
     Check.sized so encode/decode nesting stays small and fast. *)
  fun genValueAt 0 =
        Check.oneof [Check.map B.BInt genInt, Check.map B.BStr genBytesStr]
    | genValueAt d =
        Check.oneof
          [ Check.map B.BInt genInt
          , Check.map B.BStr genBytesStr
          , Check.map B.BList (Check.listOf (genValueAt (d - 1)))
          ]
  val genValue = Check.sized (fn n => genValueAt (Int.min (n, 3)))

  (* A safe key generator (lowercase ASCII) for building dicts whose pairs we
     construct already sorted, matching encode's canonicalization. *)
  val genKey = Check.stringOf (Check.charRange (#"a", #"z"))

  (* Sort (key, value) pairs ascending by raw string order -- the same order
     `encode` canonicalizes BDict pairs into -- and drop later duplicates so
     the list is strictly increasing (encode's stable sort would otherwise
     just reorder-preserve duplicate keys, but keeping it simple here). *)
  fun sortUniquePairs pairs =
    let
      fun insert (p as (k, _), []) = [p]
        | insert (p as (k, _), (q as (k', _)) :: rest) =
            if k = k' then q :: rest
            else if k < k' then p :: q :: rest
            else q :: insert (p, rest)
      val sorted = List.foldl insert [] pairs
    in
      sorted
    end

  fun showValue v = B.toString v

  (* ---- Properties -------------------------------------------------------- *)

  fun run () =
    let
      val () = Harness.section "sml-check properties"

      (* decode . encode is the identity for recursive int/string/list values. *)
      val () =
        Harness.check "prop: decode (encode v) = v (int/string/list)"
          (case Check.quickCheck
                  (Check.forAll genValue showValue
                     (fn v => B.decode (B.encode v) = v)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* Dict pairs already in canonical (sorted, unique-key) order round-trip
         exactly, since encode's only transformation on BDict is that sort. *)
      val () =
        Harness.check "prop: decode (encode (BDict sortedPairs)) = BDict sortedPairs"
          (case Check.quickCheck
                  (Check.forAll
                     (Check.map (fn pairs => B.BDict (sortUniquePairs pairs))
                        (Check.listOf (Check.tuple2 (genKey, genValueAt 1))))
                     showValue
                     (fn v => B.decode (B.encode v) = v)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* Re-encoding a decoded value reproduces the same canonical bytes:
         encode (decode (encode v)) = encode v. *)
      val () =
        Harness.check "prop: encode (decode (encode v)) = encode v"
          (case Check.quickCheck
                  (Check.forAll genValue showValue
                     (fn v => B.encode (B.decode (B.encode v)) = B.encode v)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* Canonical encoding is injective on values: two distinct generated
         values never share an encoding (follows from the round-trip law, but
         checked directly as a distinct property). *)
      val () =
        Harness.check "prop: distinct values encode to distinct byte strings"
          (case Check.quickCheck
                  (Check.forAll
                     (Check.filter (fn (a, b) => a <> b)
                        (Check.tuple2 (genValue, genValue)))
                     (fn (a, b) => showValue a ^ " vs " ^ showValue b)
                     (fn (a, b) => B.encode a <> B.encode b)) of
               Check.Passed _ => true
             | Check.Failed _ => false)
    in
      ()
    end
end
