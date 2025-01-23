defmodule ExlasticSearch.Retry.Decorator do
  @moduledoc """
  Decorator for applying retry strategies to a function.  Configure with

  ```
  config :exlasticsearch, :retry, strategy: MyStrategy, additional_opts
  ```
  """
  use Decorator.Define, retry: 0

  def retry(body, _ctx) do
    config = Application.get_env(:exlasticsearch, :retry, [])
    {strategy, config} = Keyword.pop(config, :strategy, ExlasticSearch.Retry.ExponentialBackoff)

    quote do
      unquote(strategy).retry(fn -> unquote(body) end, unquote(config))
    end
  end
end
