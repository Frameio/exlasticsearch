defmodule ExlasticSearch.Aggregation do
  @moduledoc """
  Elasticsearch aggregation building functions
  """

  defstruct [aggregations: [], nested: %{}, options: %{}]

  @type t :: %__MODULE__{}

  @doc "create a new aggregation specification"
  def new(), do: %__MODULE__{}

  @doc """
  Bucket a query by a given term
  """
  def terms(%{aggregations: aggs} = agg, name, options) do
    %{agg | aggregations: [{name, %{terms: Enum.into(options, %{})}} | aggs]}
  end

  @doc """
  Return the top results for a query or aggregation scope
  """
  def top_hits(%{aggregations: aggs} = agg, name, options) do
    %{agg | aggregations: [{name, %{top_hits: Enum.into(options, %{})}} | aggs]}
  end

  @doc """
  Includes a given aggregation within the aggregation with name `name`
  """
  def nest(%{nested: nested} = agg, name, nest) do
    %{agg | nested: Map.put(nested, name, nest)}
  end

  @doc """
  Convert to the es representation of the aggregation
  """
  def realize(%__MODULE__{aggregations: aggs, nested: nested, options: opts}) do
    %{aggs: Enum.into(aggs, %{}, fn {key, agg} -> {key, with_nested(realize(agg), nested, key)} end)
            |> Map.merge(opts)}
  end
  def realize(map) when is_map(map), do: map

  def with_nested(aggregation, nested, key) do
    case nested do
      %{^key => agg} -> Map.merge(realize(agg), aggregation)
      _ -> aggregation
    end
  end
end
