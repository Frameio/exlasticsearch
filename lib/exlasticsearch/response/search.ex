defmodule ExlasticSearch.Response.Search do
  @moduledoc """
  Elasticsearch Search response structure
  """
  use ExlasticSearch.Response

  alias ExlasticSearch.Response.Hits

  schema do
    field(:total)

    has_one(:hits, Hits)
  end
end
