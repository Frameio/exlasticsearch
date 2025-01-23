# ExlasticSearch

An elasticsearch DSL for mapping Ecto models to elasticsearch mappings, along with elixir
friendly query wrappers, response formatting and the like.

## Installation

```elixir
def deps do
  [
    {:exlasticsearch, "~> 1.3.3"}
  ]
end
```

Docs are available on [hex](https://hexdocs.pm/exlasticsearch/0.2.2)

## Usage

You can pair an `ExlasticSearch.Model` with an existing schema like:

```elixir
defmodule MySchema do
  # ...
  use ExlasticSearch.Model

  indexes :my_index do
    settings Application.get_env(:some, :settings)

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
protocol can be implemented to do that for you.  A default implementation can also be generated as part of using
the `ExlasticSearch.Model` macro.

## Configuration

This library requires `elastix` (an elixir elasticsearch http client).  So refer to it for any http related configuration. In addition, there are the following configuration options:

```elixir
config :exlasticsearch, :type_inference, ExlasticSearch.TypeInference

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200"
```
