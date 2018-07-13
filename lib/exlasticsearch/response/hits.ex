defmodule ExlasticSearch.Response.Hits do
  use ExlasticSearch.Response

  schema do
    field :max_score
    field :total

    has_many :hits, ExlasticSearch.Response.Record
  end
end
