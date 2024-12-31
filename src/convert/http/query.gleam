import convert
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

type QueryDecodeError {
  KeyNotFound(key: String)
  DecodeError(errors: List(dynamic.DecodeError))
}

pub fn encode(
  value: a,
  converter: convert.Converter(a),
) -> List(#(String, String)) {
  value |> convert.encode(converter) |> encode_value
}

pub fn encode_value(val: convert.GlitrValue) -> List(#(String, String)) {
  case val {
    convert.BoolValue(v) -> [#("bool", bool.to_string(v))]
    convert.DictValue(v) -> encode_dict(v, ["dict"])
    convert.EnumValue(variant, v) -> encode_enum(variant, v, [])
    convert.FloatValue(v) -> [#("float", float.to_string(v))]
    convert.IntValue(v) -> [#("int", int.to_string(v))]
    convert.ListValue(v) -> encode_list(v, ["list"])
    convert.NullValue -> []
    convert.ObjectValue(v) -> encode_object(v, [])
    convert.OptionalValue(v) -> encode_optional(v, ["optional"])
    convert.ResultValue(v) -> encode_result(v, ["result"])
    convert.StringValue(v) -> [#("string", v)]
    convert.BitArrayValue(v) -> [
      #("bit_array", bit_array.base64_url_encode(v, True)),
    ]
    convert.DynamicValue(_) -> []
    // unsupported
  }
}

fn encode_object(
  val: List(#(String, convert.GlitrValue)),
  path: List(String),
) -> List(#(String, String)) {
  val
  |> list.flat_map(fn(value) {
    encode_sub_value(value.1, list.append(path, [value.0]))
  })
}

fn encode_dict(
  val: dict.Dict(convert.GlitrValue, convert.GlitrValue),
  path: List(String),
) -> List(#(String, String)) {
  let result_partition =
    val
    |> dict.to_list()
    |> list.map(fn(kv) {
      case encode_dict_key(kv.0) {
        "" -> Error(Nil)
        key -> {
          Ok(encode_sub_value(kv.1, list.append(path, [key])))
        }
      }
    })
    |> result.partition()
  result_partition.0 |> list.reverse() |> list.flatten()
}

fn encode_dict_key(key: convert.GlitrValue) -> String {
  case key {
    convert.BoolValue(v) -> bool.to_string(v)
    convert.FloatValue(v) -> float.to_string(v)
    convert.IntValue(v) -> int.to_string(v)
    convert.StringValue(v) -> v
    convert.BitArrayValue(v) -> bit_array.base64_url_encode(v, True)
    _ -> ""
  }
}

fn encode_list(
  val: List(convert.GlitrValue),
  path: List(String),
) -> List(#(String, String)) {
  val
  |> list.index_fold([], fn(acc, value, index) {
    list.flatten([
      encode_sub_value(value, list.append(path, [int.to_string(index)])),
      acc,
    ])
  })
  |> list.reverse()
}

fn encode_result(
  val: Result(convert.GlitrValue, convert.GlitrValue),
  path: List(String),
) -> List(#(String, String)) {
  case val {
    Ok(v) -> encode_sub_value(v, list.append(path, ["ok"]))
    Error(v) -> encode_sub_value(v, list.append(path, ["error"]))
  }
}

fn encode_optional(
  val: option.Option(convert.GlitrValue),
  path: List(String),
) -> List(#(String, String)) {
  case val {
    option.None -> []
    option.Some(v) -> encode_sub_value(v, path)
  }
}

fn encode_enum(
  variant: String,
  v: convert.GlitrValue,
  path: List(String),
) -> List(#(String, String)) {
  encode_sub_value(v, list.append(path, [variant]))
}

fn encode_sub_value(
  val: convert.GlitrValue,
  path: List(String),
) -> List(#(String, String)) {
  let prefix = string.join(path, ".")

  case val {
    convert.BoolValue(v) -> [#(prefix, bool.to_string(v))]
    convert.DictValue(v) -> encode_dict(v, path)
    convert.EnumValue(variant, v) -> encode_enum(variant, v, path)
    convert.FloatValue(v) -> [#(prefix, float.to_string(v))]
    convert.IntValue(v) -> [#(prefix, int.to_string(v))]
    convert.ListValue(v) -> encode_list(v, path)
    convert.NullValue -> []
    convert.ObjectValue(v) -> encode_object(v, path)
    convert.OptionalValue(v) -> encode_optional(v, path)
    convert.ResultValue(v) -> encode_result(v, path)
    convert.StringValue(v) -> [#(prefix, v)]
    convert.BitArrayValue(v) -> [
      #(prefix, bit_array.base64_url_encode(v, True)),
    ]
    convert.DynamicValue(_) -> []
  }
}

pub fn decode(
  query: List(#(String, String)),
  converter: convert.Converter(a),
) -> Result(a, List(dynamic.DecodeError)) {
  decode_value(converter |> convert.type_def)(query)
  |> result.then(convert.decode(converter))
}

pub fn decode_value(
  of: convert.GlitrType,
) -> fn(List(#(String, String))) ->
  Result(convert.GlitrValue, List(dynamic.DecodeError)) {
  let decode_fn = case of {
    convert.BitArray -> decode_bit_array(_, ["bit_array"])
    convert.Bool -> decode_bool(_, ["bool"])
    convert.Dict(k, v) -> decode_dict(_, k, v, ["dict"])
    convert.Dynamic -> fn(query) {
      Ok(convert.DynamicValue(dynamic.from(query)))
    }
    convert.Enum(variants) -> decode_enum(_, variants, [])
    convert.Float -> decode_float(_, ["float"])
    convert.Int -> decode_int(_, ["int"])
    convert.List(els) -> decode_list(_, els, ["list"], 0, [])
    convert.Null -> fn(_) { Ok(convert.NullValue) }
    convert.Object(fields) -> decode_object(_, fields, [])
    convert.Optional(el) -> decode_optional(_, el, ["optional"])
    convert.Result(ok, err) -> decode_result(_, ok, err, ["result"])
    convert.String -> decode_string(_, ["string"])
  }

  fn(query) {
    decode_fn(query) |> result.map_error(query_decode_error_to_decode_errors)
  }
}

fn decode_sub_value(
  of: convert.GlitrType,
  location: List(String),
) -> fn(List(#(String, String))) -> Result(convert.GlitrValue, QueryDecodeError) {
  case of {
    convert.BitArray -> decode_bit_array(_, location)
    convert.Bool -> decode_bool(_, location)
    convert.Dict(k, v) -> decode_dict(_, k, v, location)
    convert.Dynamic -> fn(_) { Ok(convert.DynamicValue(dynamic.from(Nil))) }
    convert.Enum(variants) -> decode_enum(_, variants, location)
    convert.Float -> fn(v) { decode_float(v, location) }
    convert.Int -> fn(v) { decode_int(v, location) }
    convert.List(els) -> decode_list(_, els, location, 0, [])
    convert.Null -> fn(_) { Ok(convert.NullValue) }
    convert.Object(fields) -> decode_object(_, fields, location)
    convert.Optional(_) -> decode_optional(_, of, location)
    convert.Result(ok, err) -> decode_result(_, ok, err, location)
    convert.String -> decode_string(_, location)
  }
}

fn get_value(
  query: List(#(String, String)),
  key: String,
  callback: fn(String) -> Result(convert.GlitrValue, QueryDecodeError),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  list.key_pop(query, key)
  |> result.replace_error(KeyNotFound(key))
  |> result.then(fn(q) { callback(q.0) })
}

fn decode_bit_array(
  query: List(#(String, String)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  use v <- get_value(query, string.join(location, "."))
  bit_array.base64_url_decode(v)
  |> result.map(convert.BitArrayValue)
  |> result.replace_error(
    DecodeError([dynamic.DecodeError("A base64 encoded bit array", v, location)]),
  )
}

fn decode_bool(
  query: List(#(String, String)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  use v <- get_value(query, string.join(location, "."))
  case v {
    "True" -> Ok(convert.BoolValue(True))
    "False" -> Ok(convert.BoolValue(False))
    _ -> Error(DecodeError([dynamic.DecodeError("True or False", v, location)]))
  }
}

fn decode_int(
  query: List(#(String, String)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  use v <- get_value(query, string.join(location, "."))
  int.parse(v)
  |> result.map(convert.IntValue)
  |> result.replace_error(
    DecodeError([
      dynamic.DecodeError("An integer string representation", v, location),
    ]),
  )
}

fn decode_float(
  query: List(#(String, String)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  use v <- get_value(query, string.join(location, "."))
  float.parse(v)
  |> result.map(convert.FloatValue)
  |> result.replace_error(
    DecodeError([
      dynamic.DecodeError("A float string representation", v, location),
    ]),
  )
}

fn decode_string(
  query: List(#(String, String)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  use v <- get_value(query, string.join(location, "."))
  Ok(convert.StringValue(v))
}

fn decode_list(
  query: List(#(String, String)),
  of: convert.GlitrType,
  location: List(String),
  index: Int,
  elements: List(convert.GlitrValue),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  case
    decode_sub_value(of, list.append(location, [int.to_string(index)]))(query)
  {
    Error(KeyNotFound(_)) -> Ok(convert.ListValue(list.reverse(elements)))
    Error(DecodeError(_)) as err -> err
    Ok(v) -> decode_list(query, of, location, index + 1, [v, ..elements])
  }
}

fn decode_result(
  query: List(#(String, String)),
  ok_type: convert.GlitrType,
  error_type: convert.GlitrType,
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  case
    decode_sub_value(ok_type, list.append(location, ["ok"]))(query),
    decode_sub_value(error_type, list.append(location, ["error"]))(query)
  {
    Ok(ok), _ -> Ok(convert.ResultValue(Ok(ok)))
    _, Ok(error) -> Ok(convert.ResultValue(Error(error)))
    Error(DecodeError(error)), _ | _, Error(DecodeError(error)) ->
      Error(DecodeError(error))
    Error(KeyNotFound(_)), Error(KeyNotFound(_)) ->
      Error(KeyNotFound(string.join(location, ".") <> ".ok"))
  }
}

fn decode_optional(
  query: List(#(String, String)),
  of: convert.GlitrType,
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  case decode_sub_value(of, location)(query) {
    Ok(v) -> Ok(convert.OptionalValue(option.Some(v)))
    Error(KeyNotFound(_)) -> Ok(convert.OptionalValue(option.None))
    Error(DecodeError(_)) as err -> err
  }
}

fn decode_dict(
  query: List(#(String, String)),
  key_type: convert.GlitrType,
  value_type: convert.GlitrType,
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  let res =
    list.filter(query, fn(query_el) {
      query_el.0 |> string.starts_with(string.join(location, "."))
    })
    |> list.map(fn(query_el) {
      let key = decode_dict_key(query_el.0, key_type, location)
      let value =
        decode_sub_value(value_type, string.split(query_el.0, "."))(query)

      case key, value {
        Ok(k), Ok(v) -> Ok(#(k, v))
        Error(DecodeError(error)), _ | _, Error(DecodeError(error)) ->
          Error(DecodeError(error))
        Error(KeyNotFound(_)), _ | _, Error(KeyNotFound(_)) ->
          Error(KeyNotFound(query_el.0))
        // Should never happen
      }
    })
    |> result.partition()

  Ok(convert.DictValue(res.0 |> dict.from_list()))
}

fn decode_dict_key(
  key: String,
  key_type: convert.GlitrType,
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  let path = string.join(location, ".")
  use <- bool.guard(
    !string.starts_with(key, path),
    Error(
      DecodeError([
        dynamic.DecodeError("A string starting with the path", key, location),
      ]),
    ),
  )
  let keyvalue = string.drop_start(key, string.length(path) + 1)

  case key_type {
    convert.Bool ->
      case keyvalue {
        "True" -> Ok(convert.BoolValue(True))
        "False" -> Ok(convert.BoolValue(False))
        _ ->
          Error(
            DecodeError([dynamic.DecodeError("True or False", key, location)]),
          )
      }
    convert.Float ->
      float.parse(keyvalue)
      |> result.map(convert.FloatValue)
      |> result.replace_error(
        DecodeError([
          dynamic.DecodeError("A float string representation", key, location),
        ]),
      )
    convert.Int ->
      int.parse(keyvalue)
      |> result.map(convert.IntValue)
      |> result.replace_error(
        DecodeError([
          dynamic.DecodeError("An integer string representation", key, location),
        ]),
      )
    convert.String -> Ok(convert.StringValue(keyvalue))
    convert.BitArray ->
      bit_array.base64_url_decode(keyvalue)
      |> result.map(convert.BitArrayValue)
      |> result.replace_error(
        DecodeError([
          dynamic.DecodeError("A base64 encoded bit array", key, location),
        ]),
      )
    _ ->
      Error(
        DecodeError([dynamic.DecodeError("Unsupported key type", key, location)]),
      )
  }
}

fn decode_object(
  query: List(#(String, String)),
  fields: List(#(String, convert.GlitrType)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  {
    use f <- list.try_map(fields)
    use v <- result.map(decode_sub_value(f.1, list.append(location, [f.0]))(
      query,
    ))
    #(f.0, v)
  }
  |> result.map(convert.ObjectValue)
}

fn decode_enum(
  query: List(#(String, String)),
  variants: List(#(String, convert.GlitrType)),
  location: List(String),
) -> Result(convert.GlitrValue, QueryDecodeError) {
  list.find_map(variants, fn(variant) {
    decode_sub_value(variant.1, list.append(location, [variant.0]))(query)
  })
  |> result.replace_error(
    DecodeError([dynamic.DecodeError("One of the enum variants", "", location)]),
  )
}

fn query_decode_error_to_decode_errors(
  err: QueryDecodeError,
) -> List(dynamic.DecodeError) {
  case err {
    KeyNotFound(key) -> [
      dynamic.DecodeError("Key not found", "", string.split(key, ".")),
    ]
    DecodeError(errors) -> errors
  }
}
