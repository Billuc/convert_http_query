# convert_http_query

[![Package Version](https://img.shields.io/hexpm/v/convert_http_query)](https://hex.pm/packages/convert_http_query)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/convert_http_query/)

**Encode and decode HTTP queries from/to Gleam types**

Easily convert your Gleam types to HTTP queries. This is particularly useful to have typed queries automatically encoded in your frontend and decoded in your backend.

## Installation

```sh
gleam add convert_http_query@1
```

## Usage

```gleam
import convert
import convert/http/query

pub type User {
  User(name: String, age: Int, children: List(String))
}

pub fn user_converter() {
  convert.object({
    use name <- convert.field("name", fn (v: User) { Ok(v.name) }, convert.string())
    use age <- convert.field("age", fn (v: User) { Ok(v.age) }, convert.int())
    use children <- convert.field("children", fn (v: User) { Ok(v.children) }, convert.list(convert.string()))

    convert.success(User(name:, age:, children:))
  })
}

pub fn main() {
  User("John", 42, ["Alice", "Bob"])
  |> query.encode(user_converter())
  // => [
  //  #("name", "John"),
  //  #("age", "42"),
  //  #("children.0", "Alice"),
  //  #("children.1", "Bob"),
  // ]

  [
    #("name", "Thomas"),
    #("age", "27"),
  ]
  |> query.decode(user_converter())
  // => User("Thomas", 27, [])
}
```

Further documentation can be found at <https://hexdocs.pm/convert_http_query>.

## Features

- Encode and decode HTTP queries from and to Gleam types
- Support for all Gleam primitive types
- Support for lists, results, optionals, dicts
- Allow decoding to objects and enums

## Limitations

Not all dict keys are supported. Currently, only primitive types such as Bool, Int, Float, String and BitArray.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
