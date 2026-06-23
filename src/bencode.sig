(* bencode.sig

   A pure BitTorrent bencoding (BEP 3) encoder/decoder. Bencoding is the
   serialization format used by .torrent files and the peer/tracker protocols.
   There are exactly four value kinds:

     - integers      i<n>e               e.g.  i42e,  i-7e,  i0e
     - byte strings   <len>:<bytes>       e.g.  4:spam,  0:
     - lists          l<elements>e        e.g.  l4:spami42ee
     - dictionaries   d<pairs>e           keys are byte strings, in sorted order

   The whole module is pure: no FFI, no IO, no clock, no randomness, no threads.
   It depends only on the Basis library, so its behaviour is byte-identical
   under MLton and Poly/ML. Bencoded integers are arbitrary precision, so they
   are represented with `IntInf.int`.

   The value type:

     datatype bvalue =
         BInt  of IntInf.int                 (* i<n>e            *)
       | BStr  of string                      (* <len>:<bytes>   *)
       | BList of bvalue list                 (* l...e           *)
       | BDict of (string * bvalue) list      (* d...e           *)

   `bvalue` is built only from equality types (`IntInf.int`, `string`, lists,
   pairs), so it is itself an equality type: callers may compare values with
   `=`. The structure is ascribed opaquely, but the datatype and its
   constructors are exposed so callers can build and pattern-match values.

   Canonical form. The encoder always emits the canonical encoding:

     - integers have no leading zeros and no negative zero (`i0e` is the only
       zero; `IntInf.toString` already guarantees this);
     - dictionary keys are sorted into ascending raw byte order (by the bytes
       of the key string), independent of the order the pairs were supplied in;
       so `encode` is a normalizing operation.

   Decoding. `decode s` parses exactly ONE bencoded value that spans the whole
   of `s`. It is strict and rejects every malformed or non-canonical input by
   raising `Decode`:

     - empty input or input with trailing bytes after the value;
     - integers with leading zeros (`i03e`), a negative zero (`i-0e`), a lone
       sign (`i-e`), no digits (`ie`), non-digit characters, or no terminator;
     - byte strings whose declared length has a leading zero (`04:...`), is
       negative, is missing its colon, or runs past the end of the input;
     - unterminated lists or dictionaries;
     - dictionaries whose keys are not byte strings or that have a key with no
       value.

   `decode` and `encode` are inverses on canonical data: `decode (encode v) = v`
   for every `v`, and `encode (decode s) = s` for every canonical string `s`. *)

signature BENCODE =
sig
  datatype bvalue =
      BInt  of IntInf.int
    | BStr  of string
    | BList of bvalue list
    | BDict of (string * bvalue) list

  (* Raised by `decode` on any malformed or non-canonical input. The string is
     a short human-readable description of what went wrong. *)
  exception Decode of string

  (* Parse exactly one bencoded value spanning the whole input. Raises `Decode`
     on malformed input (see the module comment for the full list). *)
  val decode : string -> bvalue

  (* Canonical encoding: dict keys sorted ascending by raw byte order, integers
     without leading zeros and without a negative zero. Total -- never raises. *)
  val encode : bvalue -> string

  (* A human-readable, Lisp-ish rendering for debugging (NOT the wire format).
     Strings are quoted, lists are `[...]`, dicts are `{k: v, ...}`. *)
  val toString : bvalue -> string
end
