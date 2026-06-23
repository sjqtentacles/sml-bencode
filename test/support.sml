(* support.sml -- shared helpers for the sml-bencode tests.

   Bencoding is all about exact bytes, so every assertion goes through string
   or structural equality (no floating point anywhere). These helpers add
   `bvalue`-aware checks on top of the generic `Harness`: structural equality
   of decoded values, and a round-trip check that `decode (encode v) = v`.

   `bvalue` is an equality type (it is built only from `IntInf.int`, `string`,
   lists, and pairs), so `=` works directly under both MLton and Poly/ML. *)

structure Support =
struct
  structure B = Bencode

  (* Render a `bvalue` for failure messages -- this is the canonical encoding,
     which is byte-identical across compilers. *)
  fun show v = B.encode v

  fun checkValue name (expected, actual) =
    if expected = actual
    then Harness.check name true
    else (Harness.check name false;
          print ("       expected " ^ show expected
                 ^ " but got " ^ show actual ^ "\n"))

  (* `decode (encode v)` must return `v` unchanged. *)
  fun checkRoundTrip name v =
    checkValue name (v, B.decode (B.encode v))
end
