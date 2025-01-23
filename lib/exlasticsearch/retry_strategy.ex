defmodule ExlasticSearch.RetryStrategy do
  @moduledoc """
  Behavior for retrying a 0-arity function according to some strategy
  """
  @type response :: {:ok, any} | {:error, any}
  @type callable :: (-> {:ok, any} | {:error, any})
  @callback retry(fnc :: callable, opts :: list) :: response
end
