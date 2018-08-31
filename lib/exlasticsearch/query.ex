defmodule ExlasticSearch.Query do
  @moduledoc """
  Elasticsearch query building functions.  Basic usage for queryable Queryable is something like:

  ```
  Queryable.search_query()
  |> must(math(field, value))
  |> should(match_phrash(field, value, opts))
  |> filter(term(filter_field, value))
  |> realize()
  ```

  An ES query has 3 main clauses, must, should and filter.  Must and should are near equivalents
  except that must clauses will reject records that fail to match.  Filters require matches but do
  not contribute to scoring, while must/should both do.  Nesting queries within queries is also supported

  Currently the module only supports the boolean style of compound query, but we could add support
  for the others as need be.

  See https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html for documentation
  on specific query types.
  """
  defstruct [
    type: :bool,
    queryable: nil,
    must: [],
    should: [],
    filter: [],
    must_not: [],
    options: %{},
    sort: []
  ]

  @type t :: %__MODULE__{}

  @query_keys [:must, :should, :filter, :must_not]

  @doc """
  Builds a match phrase query clause
  """
  @spec match_phrase(atom, binary, list) :: map
  def match_phrase(field, query, opts \\ []),
    do: %{match_phrase: %{field => Enum.into(opts, %{query: query})}}

  @doc """
  Builds a match query clause
  """
  @spec match(atom, binary) :: map
  def match(field, query), do: %{match: %{field => query}}
  def match(field, query, opts), do: %{match: %{field => Enum.into(opts, %{query: query})}}

  @doc """
  Multimatch query clause
  """
  @spec multi_match(atom, binary) :: map
  def multi_match(fields, query, opts \\ []),
    do: %{multi_match: Enum.into(opts, %{query: query, fields: fields, type: :best_fields})}

  @doc """
  Term query clause
  """
  @spec term(atom, binary) :: map
  def term(field, term), do: %{term: %{field => term}}

  @doc """
  ids query clause
  """
  @spec ids(list) :: map
  def ids(ids), do: %{ids: %{values: ids}}

  @doc """
  Query string query type, that applies ES standard query rewriting
  """
  @spec query_string(atom, binary) :: map
  def query_string(query, opts \\ []),
    do: %{query_string: Enum.into(opts, %{query: query})}

  @doc """
  terms query clause
  """
  @spec terms(atom, binary) :: map
  def terms(field, terms), do: %{terms: %{field => terms}}

  @doc """
  range query clause
  """
  @spec range(atom, map) :: map
  def range(field, range), do: %{range: %{field => range}}

  @doc """
  Appends a new filter scope to the running query
  """
  @spec filter(t, map) :: t
  def filter(%__MODULE__{filter: filters} = query, filter), do: %{query | filter: [filter | filters]}

  @doc """
  Appends a new must scope to the runnning query
  """
  @spec must(t, map) :: t
  def must(%__MODULE__{must: musts} = query, must), do: %{query | must: [must | musts]}

  @doc """
  Appends a new should scope to the running query
  """
  @spec should(t, map) :: t
  def should(%__MODULE__{should: shoulds} = query, should), do: %{query | should: [should | shoulds]}

  @doc """
  Appends a new must_not scope to the running query
  """
  @spec must_not(t, map) :: t
  def must_not(%__MODULE__{must_not: must_nots} = query, must_not), do: %{query | must_not: [must_not | must_nots]}

  @doc """
  Adds a sort clause to the ES query
  """
  @spec sort(t, binary | atom, binary) :: t
  def sort(%__MODULE__{sort: sorts} = query, field, direction \\ "asc"),
    do: %{query | sort: [{field, direction} | sorts]}

  @doc """
  Converts a `Query` struct into an ES compliant bool compound query
  """
  @spec realize(t) :: map
  def realize(%__MODULE__{type: :function_score, options: %{script: script}} = query) do
    %{
      query: %{
        function_score: %{
          query: query_clause(%{query | type: :bool}),
          script_score: %{
            script: script
          }
        }
      }
    }
  end
  def realize(%__MODULE__{type: :bool} = query),
    do: %{query: query_clause(query)} |> add_sort(query)

  @doc """
  Add options to the current bool compound query (for instance the minimum number of accepted matches)
  """
  @spec options(t, map) :: t
  def options(%__MODULE__{} = query, opts), do: %{query | options: Map.new(opts)}

  defp include_if_present(query) do
    @query_keys |> Enum.reduce(%{}, fn type, acc ->
      case Map.get(query, type) do
        [q] -> acc |> Map.put(type, query_clause(q))
        [_ | _] = q -> acc |> Map.put(type, query_clause(q))
        _ -> acc
      end
    end)
  end

  defp query_clause(%__MODULE__{} = query),
    do: %{bool: include_if_present(query) |> Map.merge(query.options)}
  defp query_clause(clauses) when is_list(clauses), do: Enum.map(clauses, &query_clause/1)
  defp query_clause(clause), do: clause

  defp add_sort(query, %__MODULE__{sort: []}), do: query
  defp add_sort(query, %__MODULE__{sort: sort}), do: Map.put(query, :sort, realize_sort(sort))

  defp realize_sort(sort), do: Enum.reverse(sort) |> Enum.map(fn {field, direction} -> %{field => direction} end)
end
