defmodule ExlasticSearch.Response.Record do
  @moduledoc """
  Elasticsearch record response structure.  `:_source` can contain a parsed
  model result if properly specified
  """
  use ExlasticSearch.Response

  schema do
    field(:_id)
    field(:_source)
    field(:found)
    field(:_index)
  end

  def to_model(%{_source: source, _index: index} = record, model, index_type) do
    source_model = source_model(model, index, index_type)

    %{record | _source: source_model.es_decode(source)}
  end

  defp source_model(models, index, index_type) when is_list(models) do
    models
    |> Enum.find(&(&1.__es_index__(index_type) == index))
  end

  defp source_model(model, _, _), do: model
end
