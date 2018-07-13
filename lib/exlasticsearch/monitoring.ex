defmodule ExlasticSearch.Monitoring do
  @moduledoc """
  Module responsible for any statsd monitoring of elasticsearch events.
  """
  @implementation Application.get_env(:exlasticsearch, :monitoring)

  defdelegate increment(key, value), to: @implementation
end