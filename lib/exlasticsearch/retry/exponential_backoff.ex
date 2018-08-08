defmodule ExlasticSearch.Retry.ExponentialBackoff do
  @moduledoc """
  Retry Strategy implementation utilizing exponential backoffs
  """
  @behaviour ExlasticSearch.RetryStrategy

  def retry(fun, opts) do
    initial = Keyword.get(opts, :initial, 1)
    max     = Keyword.get(opts, :max, 3)
    jitter  = Keyword.get(opts, :jitter, 4)

    do_retry(fun, max, initial, jitter, 0)
  end

  defp do_retry(fun, max, _, _, max), do: fun.()
  defp do_retry(fun, max, initial, jitter, retry) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, _} ->
        sleep(initial, retry, jitter)
        |> :timer.sleep()

        do_retry(fun, max, initial, jitter, retry + 1)
    end
  end

  defp sleep(initial, retry, jitter) do
    jitter = :rand.uniform(jitter)
    exp = :math.pow(2, retry) |> round()
    jitter + (initial * exp)
  end
end