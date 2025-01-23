defmodule ExlasticSearch do
  @moduledoc """
  A collection of elasticsearch DSL's to make development simple.

  The usage is meant to pair with existing ecto schema, like so:

      defmodule MySchema do
        ...
        use ExlasticSearch.Model

        indexes :my_index do
          settings Application.get_env(:some, :settings)

          mapping :field
          mapping :other_field, type: :keyword # ecto derived defaults can be overridden
        end
      end

  You can then construct queries like so:

      MySchema.search_query()
      |> must(match(field, value))
      |> should(match_phrase(field, value, opts))
      |> filter(term(filter_field, value))

  A repo model like ecto is provided, so a with ability to do most restful operations on records, in
  addition to calling search apis with the query structs above.

  If additional data needs to be fetched or formatted prior to insertion into elastic, the `ExlasticSearch.Indexable`
  protocol can be implemented to do that for you. A default implementation can also be generated as part of using
  the `ExlasticSearch.Model` macro.
  """
end
