defmodule ExlasticSearch.Query do
  @moduledoc """
  Elasticsearch query building functions.

  Basic usage for queryable Queryable is something like:

      Queryable.search_query()
      |> must(match(field, value))
      |> should(match_phrase(field, value, opts))
      |> filter(term(filter_field, value))
      |> realize()

  An ES query has 3 main clauses, must, should and filter. Must and should are near equivalents
  except that must clauses will reject records that fail to match.  Filters require matches but do
  not contribute to scoring, while must/should both do.  Nesting queries within queries is also supported

  Currently the module only supports the boolean style of compound query, but we could add support
  for the others as need be.

  See https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html for documentation
  on specific query types.
  """

  alias __MODULE__

  defstruct type: :bool,
            queryable: nil,
            must: [],
            should: [],
            filter: [],
            must_not: [],
            options: %{},
            sort: [],
            index_type: :read

  @type t :: %__MODULE__{}

  @type field :: String.t() | atom

  @query_keys [:must, :should, :filter, :must_not]

  @doc """
  Builds a match phrase query clause
  """
  @spec match_phrase(field, String.t(), Keyword.t()) :: map
  def match_phrase(field, query, opts \\ []) do
    %{match_phrase: %{field => Enum.into(opts, %{query: query})}}
  end

  @doc """
  Builds a match query clause
  """
  @spec match(field, String.t()) :: map
  def match(field, query), do: %{match: %{field => query}}

  @spec match(field, String.t(), Keyword.t()) :: map
  def match(field, query, opts), do: %{match: %{field => Enum.into(opts, %{query: query})}}

  @doc """
  Multimatch query clause
  """
  @spec multi_match([field], String.t(), Keyword.t()) :: map
  def multi_match(fields, query, opts \\ []) do
    %{multi_match: Enum.into(opts, %{query: query, fields: fields, type: :best_fields})}
  end

  @doc """
  Term query clause
  """
  @spec term(field, term) :: map
  def term(field, term), do: %{term: %{field => term}}

  @doc """
  ids query clause
  """
  @spec ids(list) :: map
  def ids(ids), do: %{ids: %{values: ids}}

  @doc """
  Query string query type, that applies ES standard query rewriting
  """
  @spec query_string(String.t(), Keyword.t()) :: map
  def query_string(query, opts \\ []), do: %{query_string: Enum.into(opts, %{query: query})}

  @doc """
  terms query clause
  """
  @spec terms(field, [term]) :: map
  def terms(field, terms), do: %{terms: %{field => terms}}

  @doc """
  range query clause
  """
  @spec range(field, map) :: map
  def range(field, range), do: %{range: %{field => range}}

  @doc """
  Appends a new filter scope to the running query
  """
  @spec filter(t, map) :: t
  def filter(%Query{filter: filters} = query, filter), do: %{query | filter: [filter | filters]}

  @doc """
  Appends a new must scope to the running query
  """
  @spec must(t, map) :: t
  def must(%Query{must: musts} = query, must), do: %{query | must: [must | musts]}

  @doc """
  Appends a new should scope to the running query
  """
  @spec should(t, map) :: t
  def should(%Query{should: shoulds} = query, should), do: %{query | should: [should | shoulds]}

  @doc """
  Appends a new must_not scope to the running query
  """
  @spec must_not(t, map) :: t
  def must_not(%Query{must_not: must_nots} = query, must_not) do
    %{query | must_not: [must_not | must_nots]}
  end

  @doc """
  Adds a sort clause to the ES query
  """
  @spec sort(t, field, String.t() | atom) :: t
  def sort(%Query{sort: sorts} = query, field, direction \\ "asc") do
    %{query | sort: [{field, direction} | sorts]}
  end

  @doc """
  Converts a query to a function score query and adds the given `script` for scoring
  """
  @spec script_score(t, String.t(), Keyword.t()) :: t
  def script_score(%Query{options: options} = query, script, opts \\ []) do
    script = Enum.into(opts, %{source: script})
    %{query | type: :function_score, options: Map.put(options, :script, script)}
  end

  @spec function_score(t, [term], Keyword.t()) :: t
  def function_score(%Query{options: options} = query, functions, opts \\ []) do
    functions = Enum.into(opts, %{functions: functions})
    %{query | type: :function_score, options: Map.merge(options, functions)}
  end

  @spec field_value_factor(t, term, Keyword.t()) :: t
  def field_value_factor(%Query{options: options} = query, fvf, opts \\ []) do
    fvf = Enum.into(opts, %{field_value_factor: fvf})
    %{query | type: :function_score, options: Map.merge(options, fvf)}
  end

  @spec nested(t, term) :: t
  def nested(%Query{options: options} = query, path) do
    %{query | type: :nested, options: Map.put(options, :path, path)}
  end

  @doc """
  Converts a `Query` struct into an ES compliant bool or function score compound query
  """
  @spec realize(t) :: map
  def realize(%Query{type: :nested} = query) do
    add_sort(%{query: query_clause(query)}, query)
  end

  def realize(%Query{type: :function_score, options: %{script: script} = opts} = query) do
    query =
      %{query | type: :bool, options: Map.delete(opts, :script)}
      |> realize()
      |> Map.put(:script_score, %{script: script})

    %{query: %{function_score: query}}
  end

  def realize(%Query{type: :bool} = query) do
    add_sort(%{query: query_clause(query)}, query)
  end

  @doc """
  Add options to the current bool compound query (for instance the minimum number of accepted matches)
  """
  @spec options(t, map | Keyword.t()) :: t
  def options(%Query{} = query, opts), do: %{query | options: Map.new(opts)}

  defp include_if_present(query) do
    Enum.reduce(@query_keys, %{}, fn type, acc ->
      case Map.get(query, type) do
        [q] -> Map.put(acc, type, query_clause(q))
        [_ | _] = q -> Map.put(acc, type, query_clause(q))
        _ -> acc
      end
    end)
  end

  defp query_clause(%Query{type: :function_score} = query), do: %{function_score: transform_query(query)}

  defp query_clause(%Query{type: :nested} = query), do: %{nested: transform_query(query)}

  defp query_clause(%Query{type: :constant_score, options: options} = query),
    do: %{constant_score: Map.merge(include_if_present(query), options)}

  defp query_clause(%Query{options: options} = query), do: %{bool: Map.merge(include_if_present(query), options)}

  defp query_clause(clauses) when is_list(clauses), do: Enum.map(clauses, &query_clause/1)

  defp query_clause(clause), do: clause

  defp add_sort(query, %Query{sort: []}), do: query
  defp add_sort(query, %Query{sort: sort}), do: Map.put(query, :sort, realize_sort(sort))

  defp transform_query(%Query{type: :nested, options: %{path: path} = opts} = query) do
    %{query | type: :bool, options: Map.delete(opts, :path)}
    |> realize()
    |> Map.put(:path, path)
  end

  defp transform_query(%Query{type: :function_score, options: %{script: script} = opts} = query) do
    %{query | type: :bool, options: Map.delete(opts, :script)}
    |> realize()
    |> Map.put(:script_score, %{script: script})
  end

  defp transform_query(%Query{type: :function_score, options: opts} = query) do
    %{query | type: :bool, options: Map.drop(opts, [:functions, :field_value_factor])}
    |> realize()
    |> Map.merge(Map.take(opts, [:functions, :field_value_factor]))
  end

  defp realize_sort(sort) do
    sort
    |> Enum.reverse()
    |> Enum.map(fn {field, direction} -> %{field => direction} end)
  end
end
