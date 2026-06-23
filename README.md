# sml-bencode

[![CI](https://github.com/sjqtentacles/sml-bencode/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-bencode/actions/workflows/ci.yml)

A BitTorrent [bencoding](https://www.bittorrent.org/beps/bep_0003.html) (BEP 3)
encoder/decoder in pure Standard ML — the four value kinds (integers, byte
strings, lists, dictionaries) with a strict, canonical `encode` and a strict
`decode`. No FFI, no IO, no clock, no randomness, no threads, and no external
dependencies: just the Basis library, so it is **deterministic** and
byte-identical under both [MLton](http://mlton.org/) and
[Poly/ML](https://www.polyml.org/). Bencoded integers are arbitrary precision,
so they use `IntInf.int`.

## Status

- 60 assertions, green on MLton and Poly/ML.
- Basis-library only; standalone (no vendored dependencies), deterministic
  across compilers.
- Strict, canonical codec: `encode` normalizes (sorts dict keys); `decode`
  rejects every malformed or non-canonical input.

## Install

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```
smlpkg add github.com/sjqtentacles/sml-bencode
smlpkg sync
```

Include the MLB from your own:

```
local
  $(SML_LIB)/basis/basis.mlb
  lib/github.com/sjqtentacles/sml-bencode/src/bencode.mlb (via smlpkg)
in
  ...
end
```

This brings `structure Bencode` into scope.

## Quick start

```sml
(* the value type *)
val v = Bencode.BDict [ ("foo", Bencode.BInt 42)
                      , ("bar", Bencode.BStr "spam") ]

(* canonical encoding -- dict keys are sorted ascending by raw byte order *)
val s = Bencode.encode v          (* "d3:bar4:spam3:fooi42ee" *)

(* strict decoding of exactly one value spanning the whole input *)
val back = Bencode.decode s       (* BDict [("bar", BStr "spam"), ("foo", BInt 42)] *)

(* round trip on canonical data: decode (encode v) = v *)
val ok = (Bencode.decode (Bencode.encode v) = v)   (* true *)

(* arbitrary-precision integers *)
val big = Bencode.encode (Bencode.BInt (IntInf.pow (2, 80)))
(* "i1208925819614629174706176e" *)

(* malformed / non-canonical input raises Bencode.Decode *)
val _ = Bencode.decode "i03e"     (* raises Decode "leading zero"   *)
val _ = Bencode.decode "i-0e"     (* raises Decode "negative zero"  *)
val _ = Bencode.decode "i42eXYZ"  (* raises Decode "trailing bytes..." *)
```

## API (`signature BENCODE`)

```sml
datatype bvalue =
    BInt  of IntInf.int                 (* i<n>e            *)
  | BStr  of string                      (* <len>:<bytes>   *)
  | BList of bvalue list                 (* l...e           *)
  | BDict of (string * bvalue) list      (* d...e           *)

(* raised by `decode` on malformed or non-canonical input *)
exception Decode of string

(* parse exactly one value spanning the whole input; raise `Decode` otherwise *)
val decode   : string -> bvalue
(* canonical encoding: sorted dict keys, no leading zeros, no negative zero *)
val encode   : bvalue -> string
(* a Lisp-ish rendering for debugging (NOT the wire format) *)
val toString : bvalue -> string
```

The structure is ascribed opaquely (`Bencode :> BENCODE`); the `bvalue`
datatype and its constructors are exposed so callers can build and
pattern-match values. `bvalue` is built only from equality types, so callers
may compare values with `=`.

### Bencoding rules & conventions

- **Integers** `i<n>e`: a decimal integer, e.g. `i42e`, `i-7e`, `i0e`.
- **Byte strings** `<len>:<bytes>`: a non-negative decimal length, a colon,
  then exactly `len` raw bytes, e.g. `4:spam`, `0:`. The length is a byte
  count, so colons inside the body are literal data.
- **Lists** `l<elements>e`: zero or more values, e.g. `l4:spami42ee`.
- **Dictionaries** `d<pairs>e`: zero or more (key, value) pairs where each key
  is a byte string, emitted with keys sorted ascending by raw byte order.
- **Canonical encoding.** `encode` is normalizing: it sorts dictionary keys by
  raw byte order (by the bytes of the key, not by length), and integers are
  emitted with no leading zeros and no negative zero (`i0e` is the only zero).
- **Strict decoding.** `decode s` parses exactly one value that must span the
  whole of `s`. It raises `Decode` on: empty input; trailing bytes after the
  value; integers with leading zeros (`i03e`), a negative zero (`i-0e`), a lone
  sign (`i-e`), no digits (`ie`), non-digit characters, or no terminator; byte
  strings with a leading-zero length (`04:…`), a negative length, a missing
  colon, or a length that runs past the end of the input; unterminated lists or
  dictionaries; and dictionaries whose keys are not byte strings or that have a
  key with no value.
- **Inverse on canonical data.** `decode (encode v) = v` for every `v`, and
  `encode (decode s) = s` for every canonical string `s`.

## Build & test

```
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run examples/demo.sml
make clean
```

Both compilers run the same strict-TDD suite (60 assertions), seeded with the
canonical BEP 3 vectors and boundary cases:

- the four spec examples (`i42e`, `4:spam`, `l4:spami42ee`,
  `d3:bar4:spam3:fooi42ee`) plus empty/nested containers and arbitrary-precision
  integers (`2^70`, `10^40`);
- canonical dictionary key ordering (the encoder reorders out-of-order keys, and
  sorts by raw byte order, not length);
- `decode . encode` and `encode . decode` round trips on nested,
  torrent-shaped data;
- malformed-input rejection — leading zeros, negative zero, bad/negative/
  leading-zero lengths, missing colons, unterminated containers, trailing
  bytes, and dict keys that are not byte strings.

## Example

`make example` builds a torrent-shaped value (with dictionary keys deliberately
out of order), prints its canonical encoding, proves the round trip, decodes the
four BEP 3 spec examples, shows an arbitrary-precision integer, and demonstrates
a handful of rejected malformed inputs (output is byte-identical under MLton and
Poly/ML):

```
=== sml-bencode demo ==========================================

A torrent value (built with keys out of order):
  {"info": {"pieces": ["aaaa", "bbbb"], "name": "file.bin", "piece length": 512, "length": 1024}, "announce": "http://tracker.example/announce", "creation date": 1718000000}

Canonical bencoding (note keys are sorted ascending by byte):
  d8:announce31:http://tracker.example/announce13:creation datei1718000000e4:infod6:lengthi1024e4:name8:file.bin12:piece lengthi512e6:piecesl4:aaaa4:bbbbeee

Round trip:
  decode (encode v) is canonical ?  yes
  encode (decode (encode v)) = encode v ?  yes

Spec examples (BEP 3):
  i42e                    -> 42
  4:spam                  -> "spam"
  l4:spami42ee            -> ["spam", 42]
  d3:bar4:spam3:fooi42ee  -> {"bar": "spam", "foo": 42}

Arbitrary-precision integer (2^80):
  i1208925819614629174706176e

Malformed inputs are rejected (strict, canonical decoder):
  i03e        -> rejected: leading zero
  i-0e        -> rejected: negative zero
  ie          -> rejected: expected digits
  5:spam      -> rejected: byte string runs past end of input
  l4:spam     -> rejected: unterminated list
  i42eXYZ     -> rejected: trailing bytes after value

===============================================================
```

### Poly/ML note

CI builds Poly/ML 5.9.1 from source rather than using the Ubuntu package
(Poly/ML 5.7.1), matching the toolchain used across the sibling SML libraries.
See `.github/workflows/ci.yml`.

## License

MIT — see [LICENSE](LICENSE).
