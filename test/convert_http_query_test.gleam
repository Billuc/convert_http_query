import convert
import convert/http/query
import gleam/dict
import gleam/dynamic
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn encode_int_test() {
  query.encode_value(convert.IntValue(5))
  |> should.equal([#("int", "5")])
}

pub fn encode_string_test() {
  query.encode_value(convert.StringValue("hello"))
  |> should.equal([#("string", "hello")])
}

pub fn encode_list_test() {
  query.encode_value(
    convert.ListValue([convert.IntValue(1), convert.IntValue(2)]),
  )
  |> should.equal([#("list.0", "1"), #("list.1", "2")])
}

pub fn encode_float_test() {
  query.encode_value(convert.FloatValue(5.5))
  |> should.equal([#("float", "5.5")])
}

pub fn encode_bool_test() {
  query.encode_value(convert.BoolValue(True))
  |> should.equal([#("bool", "True")])
}

pub fn encode_null_test() {
  query.encode_value(convert.NullValue)
  |> should.equal([])
}

pub fn encode_bit_array_test() {
  query.encode_value(convert.BitArrayValue(<<"Hello world":utf8>>))
  |> should.equal([#("bit_array", "SGVsbG8gd29ybGQ=")])
}

pub fn encode_result_ok_test() {
  query.encode_value(convert.ResultValue(Ok(convert.IntValue(5))))
  |> should.equal([#("result.ok", "5")])
}

pub fn encode_error_test() {
  query.encode_value(convert.ResultValue(Error(convert.StringValue("error"))))
  |> should.equal([#("result.error", "error")])
}

pub fn encode_optional_some_test() {
  query.encode_value(convert.OptionalValue(option.Some(convert.IntValue(5))))
  |> should.equal([#("optional", "5")])
}

pub fn encode_optional_none_test() {
  query.encode_value(convert.OptionalValue(option.None))
  |> should.equal([])
}

pub fn encode_dict_test() {
  query.encode_value(
    convert.DictValue(
      dict.from_list([
        #(convert.StringValue("key1"), convert.IntValue(5)),
        #(convert.StringValue("key2"), convert.IntValue(6)),
      ]),
    ),
  )
  |> should.equal([#("dict.key1", "5"), #("dict.key2", "6")])
}

pub fn encode_dynamic_unsupported_test() {
  query.encode_value(convert.DynamicValue(dynamic.from(5)))
  |> should.equal([])
}

pub fn encode_object_test() {
  query.encode_value(
    convert.ObjectValue([
      #("name", convert.StringValue("John")),
      #("age", convert.IntValue(30)),
    ]),
  )
  |> should.equal([#("name", "John"), #("age", "30")])
}
