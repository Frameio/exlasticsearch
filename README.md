# ExlasticSearch

[![Module Version](https://img.shields.io/hexpm/v/exlasticsearch.svg)](https://hex.pm/packages/exlasticsearch)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/exlasticsearch/)
[![Total Download](https://img.shields.io/hexpm/dt/exlasticsearch.svg)](https://hex.pm/packages/exlasticsearch)
[![License](https://img.shields.io/hexpm/l/exlasticsearch.svg)](https://github.com/Frameio/exlasticsearch/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/Frameio/exlasticsearch.svg)](https://github.com/Frameio/exlasticsearch/commits/master)

An [Elasticsearch](https://www.elastic.co/elasticsearch/) DSLs for mapping Ecto
models to Elasticsearch mappings, along with Elixir friendly query wrappers,
response formatting and the like.

## Installation

```elixir
def deps do
  [
    {:exlasticsearch, "~> 2.2.4"}
  ]
end
```

Docs are available on [hex](https://hexdocs.pm/exlasticsearch/)

## Usage

You can pair an `ExlasticSearch.Model` with an existing schema like:

```elixir
defmodule MySchema do
  # ...
  use ExlasticSearch.Model

  indexes :my_index do
    settings Application.compile_env(:some, :settings)

    mapping :field
    mapping :other_field, type: :keyword # ecto derived defaults can be overridden
  end
end
```

You can then construct queries like so:

```elixir
MySchema.search_query()
|> must(match(field, value))
|> should(match_phrase(field, value, opts))
|> filter(term(filter_field, value))
```

A repo model like Ecto is provided, so a with ability to do most restful operations on records, in
addition to calling search APIs with the query structs above.

If additional data needs to be fetched or formatted prior to insertion into elastic, the `ExlasticSearch.Indexable`
protocol can be implemented to do that for you. A default implementation can also be generated as part of using
the `ExlasticSearch.Model` macro.

## Configuration

This library requires [Elastix](https://hex.pm/packages/elastix), an Elixir Elasticsearch HTTP client. So refer to it for any HTTP related configuration. In addition, there are the following configuration options:

```elixir
config :exlasticsearch, :type_inference, ExlasticSearch.TypeInference

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200"
```

## Testing

Run integration tests with local ElasticSearch clusters.
Ensure Docker resources include at least 8 GB of memory.

```sh
docker-compose up -d
mix test
```

## Copyright and License

Copyright (c) 2025 Adobe/Frame.io

This software is released under the [MIT License](./LICENSE.md).
