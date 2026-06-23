(* bencode.sml

   Implementation of `BENCODE`. Everything is Basis-library `string`/`substring`
   and `IntInf` arithmetic threaded through pure helpers, so results are
   deterministic and identical under MLton and Poly/ML.

   Decoding is a recursive-descent parser over a `substring` cursor: each parser
   consumes a prefix of its input and returns the parsed value together with the
   remaining tail. The public `decode` runs the value parser and then insists
   the tail is empty (no trailing bytes). Every malformed case raises `Decode`.

   Encoding walks the value, emitting tokens into a string. The only non-trivial
   step is sorting dictionary keys into ascending raw byte order via
   `String.compare` before emitting the pairs. *)

structure Bencode :> BENCODE =
struct
  datatype bvalue =
      BInt  of IntInf.int
    | BStr  of string
    | BList of bvalue list
    | BDict of (string * bvalue) list

  exception Decode of string

  (* A stable merge sort, written here so the library depends only on the
     Basis (no `ListMergeSort`, which is not portable across MLton/Poly/ML).
     `leq` is a non-strict order; ties keep their original relative order. *)
  fun sortBy leq xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) =
            if leq (x, y)
            then x :: merge (xs, y :: ys)
            else y :: merge (x :: xs, ys)
      fun split [] = ([], [])
        | split [x] = ([x], [])
        | split (x :: y :: rest) =
            let val (a, b) = split rest in (x :: a, y :: b) end
      fun sort [] = []
        | sort [x] = [x]
        | sort xs =
            let val (a, b) = split xs
            in merge (sort a, sort b) end
    in sort xs end

  (* ---- encoding ---- *)

  (* `IntInf.toString` renders negatives with SML's `~`; bencoding (and every
     other wire format) uses an ASCII `-`, so swap the sign character. *)
  fun intStr n =
    let val s = IntInf.toString n
    in if String.isPrefix "~" s
       then "-" ^ String.extract (s, 1, NONE)
       else s
    end

  (* Emit into a list of string fragments (reversed), concatenated at the end;
     this keeps encoding linear without repeated O(n) `^`. *)
  fun enc (BInt n, acc) = "e" :: intStr n :: "i" :: acc
    | enc (BStr s, acc) = s :: ":" :: Int.toString (size s) :: acc
    | enc (BList xs, acc) =
        let val acc = "l" :: acc
            val acc = List.foldl enc acc xs
        in "e" :: acc end
    | enc (BDict pairs, acc) =
        let
          (* canonical: sort by raw byte order of the key string *)
          val sorted =
            sortBy
              (fn ((k1, _), (k2, _)) => String.compare (k1, k2) <> GREATER)
              pairs
          val acc = "d" :: acc
          val acc =
            List.foldl
              (fn ((k, v), acc) =>
                 enc (v, k :: ":" :: Int.toString (size k) :: acc))
              acc sorted
        in "e" :: acc end

  fun encode v = String.concat (List.rev (enc (v, [])))

  (* ---- debugging rendering ---- *)

  fun toString (BInt n) = intStr n
    | toString (BStr s) = "\"" ^ s ^ "\""
    | toString (BList xs) =
        "[" ^ String.concatWith ", " (List.map toString xs) ^ "]"
    | toString (BDict pairs) =
        "{" ^ String.concatWith ", "
                (List.map (fn (k, v) => "\"" ^ k ^ "\": " ^ toString v) pairs)
            ^ "}"

  (* ---- decoding ---- *)

  (* The cursor is a `substring`. Helpers return (result, rest). *)

  fun peek ss =
    if Substring.isEmpty ss then NONE else SOME (Substring.sub (ss, 0))

  (* Read a run of ASCII digits; returns (digitString, rest). *)
  fun takeDigits ss =
    Substring.splitl (fn c => Char.isDigit c) ss

  (* Parse the digits of a non-negative length or magnitude, rejecting leading
     zeros. Returns (IntInf.int, rest). The empty digit run is rejected by the
     callers (they check for it), but we also guard here. *)
  fun parseNat ss =
    let
      val (digits, rest) = takeDigits ss
      val s = Substring.string digits
    in
      if s = "" then raise Decode "expected digits"
      else if size s > 1 andalso String.sub (s, 0) = #"0"
      then raise Decode "leading zero"
      else case IntInf.fromString s of
             SOME n => (n, rest)
           | NONE => raise Decode "bad number"
    end

  (* i<n>e : optional leading '-', then canonical digits, then 'e'.
     Rejects i-0e, i03e, i-03e, ie, i-e. *)
  fun parseInt ss =
    let
      (* ss starts just after the 'i' *)
      val (neg, ss1) =
        case peek ss of
          SOME #"-" => (true, Substring.triml 1 ss)
        | _ => (false, ss)
      val (mag, ss2) = parseNat ss1
      val () = if neg andalso mag = 0 then raise Decode "negative zero" else ()
      val n = if neg then ~mag else mag
    in
      case peek ss2 of
        SOME #"e" => (BInt n, Substring.triml 1 ss2)
      | _ => raise Decode "unterminated integer"
    end

  (* <len>:<bytes> : canonical non-negative length, ':', then exactly len bytes.
     `parseNat` rejects a leading-zero length; a missing/short body is rejected
     here. Returns the raw key string and rest for dict-key reuse. *)
  fun parseStrRaw ss =
    let
      val (len64, ss1) = parseNat ss
      val () = case peek ss1 of
                 SOME #":" => ()
               | _ => raise Decode "missing ':' in byte string"
      val body = Substring.triml 1 ss1
      val len = IntInf.toInt len64
                handle Overflow => raise Decode "length too large"
    in
      if Substring.size body < len
      then raise Decode "byte string runs past end of input"
      else
        let
          val str = Substring.string (Substring.slice (body, 0, SOME len))
          val rest = Substring.triml len body
        in (str, rest) end
    end

  (* Parse one value; dispatch on the leading byte. *)
  fun parseValue ss =
    case peek ss of
      NONE => raise Decode "unexpected end of input"
    | SOME #"i" => parseInt (Substring.triml 1 ss)
    | SOME #"l" => parseList (Substring.triml 1 ss, [])
    | SOME #"d" => parseDict (Substring.triml 1 ss, [])
    | SOME c =>
        if Char.isDigit c
        then let val (s, rest) = parseStrRaw ss in (BStr s, rest) end
        else raise Decode ("unexpected byte '" ^ String.str c ^ "'")

  and parseList (ss, acc) =
    case peek ss of
      NONE => raise Decode "unterminated list"
    | SOME #"e" => (BList (List.rev acc), Substring.triml 1 ss)
    | _ =>
        let val (v, rest) = parseValue ss
        in parseList (rest, v :: acc) end

  and parseDict (ss, acc) =
    case peek ss of
      NONE => raise Decode "unterminated dict"
    | SOME #"e" => (BDict (List.rev acc), Substring.triml 1 ss)
    | SOME c =>
        if Char.isDigit c
        then
          let
            val (key, ss1) = parseStrRaw ss
            val () = case peek ss1 of
                       NONE => raise Decode "dict key without value"
                     | SOME #"e" => raise Decode "dict key without value"
                     | _ => ()
            val (v, ss2) = parseValue ss1
          in parseDict (ss2, (key, v) :: acc) end
        else raise Decode "dict key must be a byte string"

  fun decode s =
    let
      val (v, rest) = parseValue (Substring.full s)
    in
      if Substring.isEmpty rest
      then v
      else raise Decode "trailing bytes after value"
    end
end
