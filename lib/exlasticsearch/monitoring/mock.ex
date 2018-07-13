defmodule ExlasticSearch.Monitoring.Mock do
  @moduledoc """
  Noop implementation of monitoring.  To bring your own, do  `config :exlasticsearch, :monitoring, MonitoringModule`
  """
  def increment(_, _), do: nil
end