# ExlasticSearch

An elasticsearch dsls for mapping ecto models to elasticsearch mappings, along with elixir
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

You can pair an ExlasticSearch.Model with an existing schema like:

```elixir
defmodule MySchema do
  ...
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
|> must(math(field, value))
|> should(match_phrash(field, value, opts))
|> filter(term(filter_field, value))
```

A repo model like ecto is provided, so a with ability to do most restful operations on records, in
addition to calling search apis with the query structs above.

If additional data needs to be fetched or formatted prior to insertion into elastic, the `ExlasticSearch.Indexable`
protocol can be implemented to do that for you.  A default implementation can also be generated as part of using
the `ExlasticSearch.Model` macro.

## Configuration

This library requires `elastix` (an elixir elasticsearch http client).  So refer to it for any http related configuration.  In addition, there are the following config options:

```elixir
config :exlasticsearch, :type_inference, ExlasticSearch.TypeInference

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200"
```
