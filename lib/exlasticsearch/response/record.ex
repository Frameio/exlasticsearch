defmodule ExlasticSearch.Response.Record do
  use ExlasticSearch.Response

  schema do
    field :_id
    field :_source
    field :found
  end

  def to_model(%{_source: source} = record, model), do: %{record | _source: model.es_decode(source)}
end
