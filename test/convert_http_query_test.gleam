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

pub fn encode_complex_object_test() {
  convert.ObjectValue([
    #("name", convert.StringValue("John")),
    #("age", convert.IntValue(30)),
    #(
      "address",
      convert.ObjectValue([
        #("city", convert.StringValue("New York")),
        #("zip", convert.IntValue(10_001)),
      ]),
    ),
    #(
      "children",
      convert.ListValue([
        convert.StringValue("Alice"),
        convert.StringValue("Bob"),
      ]),
    ),
  ])
  |> query.encode_value
  |> should.equal([
    #("name", "John"),
    #("age", "30"),
    #("address.city", "New York"),
    #("address.zip", "10001"),
    #("children.0", "Alice"),
    #("children.1", "Bob"),
  ])
}

type TestUser {
  TestUser(name: String, age: Int, children: List(String))
}

pub fn encode_test() {
  let converter =
    convert.object({
      use name <- convert.field(
        "name",
        fn(v: TestUser) { Ok(v.name) },
        convert.string(),
      )
      use age <- convert.field(
        "age",
        fn(v: TestUser) { Ok(v.age) },
        convert.int(),
      )
      use children <- convert.field(
        "children",
        fn(v: TestUser) { Ok(v.children) },
        convert.list(convert.string()),
      )

      convert.success(TestUser(name:, age:, children:))
    })

  TestUser("John", 30, ["Alice", "Bob"])
  |> query.encode(converter)
  |> should.equal([
    #("name", "John"),
    #("age", "30"),
    #("children.0", "Alice"),
    #("children.1", "Bob"),
  ])
}

pub fn decode_string_test() {
  [#("string", "hello")]
  |> query.decode_value(convert.String)
  |> should.be_ok
  |> should.equal(convert.StringValue("hello"))
}

pub fn decode_int_test() {
  [#("int", "5")]
  |> query.decode_value(convert.Int)
  |> should.be_ok
  |> should.equal(convert.IntValue(5))
}

pub fn decode_float_test() {
  [#("float", "5.5")]
  |> query.decode_value(convert.Float)
  |> should.be_ok
  |> should.equal(convert.FloatValue(5.5))
}

pub fn decode_bit_array_test() {
  [#("bit_array", "SGVsbG8gd29ybGQ=")]
  |> query.decode_value(convert.BitArray)
  |> should.be_ok
  |> should.equal(convert.BitArrayValue(<<"Hello world":utf8>>))
}

pub fn decode_bool_test() {
  [#("bool", "True")]
  |> query.decode_value(convert.Bool)
  |> should.be_ok
  |> should.equal(convert.BoolValue(True))
}

pub fn decode_null_test() {
  [#("foo", "bar")]
  |> query.decode_value(convert.Null)
  |> should.be_ok
  |> should.equal(convert.NullValue)
}

pub fn decode_list_test() {
  [#("list.0", "1"), #("list.1", "2")]
  |> query.decode_value(convert.List(convert.Int))
  |> should.be_ok
  |> should.equal(convert.ListValue([convert.IntValue(1), convert.IntValue(2)]))
}

pub fn decode_dict_test() {
  [#("dict.key1", "5"), #("dict.key2", "6")]
  |> query.decode_value(convert.Dict(convert.String, convert.Int))
  |> should.be_ok
  |> should.equal(
    convert.DictValue(
      dict.from_list([
        #(convert.StringValue("key1"), convert.IntValue(5)),
        #(convert.StringValue("key2"), convert.IntValue(6)),
      ]),
    ),
  )
}

pub fn decode_result_ok_test() {
  [#("result.ok", "5")]
  |> query.decode_value(convert.Result(convert.Int, convert.String))
  |> should.be_ok
  |> should.equal(convert.ResultValue(Ok(convert.IntValue(5))))
}

pub fn decode_result_error_test() {
  [#("result.error", "Something wrong happened")]
  |> query.decode_value(convert.Result(convert.Int, convert.String))
  |> should.be_ok
  |> should.equal(
    convert.ResultValue(Error(convert.StringValue("Something wrong happened"))),
  )
}

pub fn decode_optional_some_test() {
  [#("optional", "5")]
  |> query.decode_value(convert.Optional(convert.Int))
  |> should.be_ok
  |> should.equal(convert.OptionalValue(option.Some(convert.IntValue(5))))
}

pub fn decode_optional_none_test() {
  []
  |> query.decode_value(convert.Optional(convert.Int))
  |> should.be_ok
  |> should.equal(convert.OptionalValue(option.None))
}

pub fn decode_error_if_no_key_test() {
  []
  |> query.decode_value(convert.Int)
  |> should.be_error
  |> should.equal([dynamic.DecodeError("Key not found", "", ["int"])])
}

pub fn decode_error_if_wrong_type_test() {
  [#("int", "hello")]
  |> query.decode_value(convert.Int)
  |> should.be_error
  |> should.equal([
    dynamic.DecodeError("An integer string representation", "hello", ["int"]),
  ])
}

pub fn decode_dynamic_returns_query_as_dynamic_test() {
  [#("int", "5")]
  |> query.decode_value(convert.Dynamic)
  |> should.be_ok
  |> should.equal(convert.DynamicValue(dynamic.from([#("int", "5")])))
}

pub fn decode_object_test() {
  [#("name", "John"), #("age", "30")]
  |> query.decode_value(
    convert.Object([#("name", convert.String), #("age", convert.Int)]),
  )
  |> should.be_ok
  |> should.equal(
    convert.ObjectValue([
      #("name", convert.StringValue("John")),
      #("age", convert.IntValue(30)),
    ]),
  )
}

pub fn decode_complex_object_test() {
  [
    #("name", "John"),
    #("age", "30"),
    #("address.city", "New York"),
    #("address.zip", "10001"),
    #("children.0", "Alice"),
    #("children.1", "Bob"),
  ]
  |> query.decode_value(
    convert.Object([
      #("name", convert.String),
      #("age", convert.Int),
      #(
        "address",
        convert.Object([#("city", convert.String), #("zip", convert.Int)]),
      ),
      #("children", convert.List(convert.String)),
    ]),
  )
  |> should.be_ok
  |> should.equal(
    convert.ObjectValue([
      #("name", convert.StringValue("John")),
      #("age", convert.IntValue(30)),
      #(
        "address",
        convert.ObjectValue([
          #("city", convert.StringValue("New York")),
          #("zip", convert.IntValue(10_001)),
        ]),
      ),
      #(
        "children",
        convert.ListValue([
          convert.StringValue("Alice"),
          convert.StringValue("Bob"),
        ]),
      ),
    ]),
  )
}

pub fn decode_test() {
  let converter =
    convert.object({
      use name <- convert.field(
        "name",
        fn(v: TestUser) { Ok(v.name) },
        convert.string(),
      )
      use age <- convert.field(
        "age",
        fn(v: TestUser) { Ok(v.age) },
        convert.int(),
      )
      use children <- convert.field(
        "children",
        fn(v: TestUser) { Ok(v.children) },
        convert.list(convert.string()),
      )
      convert.success(TestUser(name:, age:, children:))
    })

  [
    #("name", "John"),
    #("age", "30"),
    #("children.0", "Alice"),
    #("children.1", "Bob"),
  ]
  |> query.decode(converter)
  |> should.be_ok
  |> should.equal(TestUser("John", 30, ["Alice", "Bob"]))
}
