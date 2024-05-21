defmodule ExlasticSearch.Retry.Decorator do
  @moduledoc """
  Decorator for applying retry strategies to a function.  Configure with

  ```
  config :exlasticsearch, :retry, strategy: MyStrategy, additional_opts
  ```
  """
  use Decorator.Define, retry: 0
  @config Application.compile_env(:exlasticsearch, :retry, [])

  def retry(body, _ctx) do
    {strategy, config} = Keyword.pop(@config, :strategy, ExlasticSearch.Retry.ExponentialBackoff)
    quote do
      unquote(strategy).retry(fn -> unquote(body) end, unquote(config))
    end
  end
end
