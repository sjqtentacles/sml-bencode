(* test_malformed.sml -- every malformed input must be rejected.

   `decode` parses exactly one bencoded value spanning the WHOLE input. Anything
   else -- trailing bytes, leading zeros, negative zero, bad lengths,
   unterminated containers, empty input -- raises `Bencode.Decode`. These tests
   only care THAT an exception is raised (via `Harness.checkRaises`), matching
   the documented contract in `bencode.sig`. *)

structure MalformedTests =
struct
  open Support
  structure B = Bencode

  fun rejects name s = Harness.checkRaises name (fn () => B.decode s)

  fun run () =
    let
      val () = Harness.section "reject empty / junk"
      val () = rejects "empty input" ""
      val () = rejects "bare letter" "x"
      val () = rejects "trailing bytes after value" "i42eXYZ"
      val () = rejects "trailing bytes after string" "4:spamextra"

      val () = Harness.section "reject malformed integers"
      val () = rejects "leading zero i03e" "i03e"
      val () = rejects "leading zeros i007e" "i007e"
      val () = rejects "negative zero i-0e" "i-0e"
      val () = rejects "negative leading zero i-03e" "i-03e"
      val () = rejects "empty integer ie" "ie"
      val () = rejects "lone minus i-e" "i-e"
      val () = rejects "unterminated integer i42" "i42"
      val () = rejects "non-digit integer i4x2e" "i4x2e"

      val () = Harness.section "reject malformed byte strings"
      val () = rejects "length exceeds input 5:spam" "5:spam"
      val () = rejects "missing colon 4spam" "4spam"
      val () = rejects "negative length -1:" "-1:x"
      val () = rejects "leading-zero length 04:spam" "04:spam"
      val () = rejects "bare length 4" "4"
      val () = rejects "length but no body 3:" "3:"

      val () = Harness.section "reject unterminated containers"
      val () = rejects "unterminated list l4:spam" "l4:spam"
      val () = rejects "unterminated empty list l" "l"
      val () = rejects "unterminated dict d3:foo3:bar" "d3:foo3:bar"
      val () = rejects "unterminated empty dict d" "d"

      val () = Harness.section "reject malformed dicts"
      (* a dict key must be a byte string, not an integer *)
      val () = rejects "dict key not a string di1ei2ee" "di1ei2ee"
      (* odd number of dict elements: key with no value *)
      val () = rejects "dict missing value d3:fooe" "d3:fooe"
    in
      ()
    end
end
