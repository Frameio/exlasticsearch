defmodule ExlasticSearch.Repo do
  @moduledoc """
  API executor for elasticsearch.  The generate pattern is to define a `ExlasticSearch.Model`
  on an ecto model, then call any of these functions to manage the model.

  To configure the url the repo points to, do:

  ```
  config :exlasticsearch, ExlasticSearch.Repo,
    url: "https://elasticsearch.url.io:9200"
  """
  use Scrivener
  use ExlasticSearch.Retry.Decorator
  alias ExlasticSearch.{Indexable, Query, Response}
  alias Elastix.{Index, Mapping, Document, Bulk, Search, HTTP}
  require Logger

  @chunk_size 2000
  @type response :: {:ok, %HTTPoison.Response{}} | {:error, any}
  @log_level Application.get_env(:exlasticsearch, __MODULE__, []) |> Keyword.get(:log_leve, :debug)

  @doc """
  Creates an index as defined in `model`
  """
  @spec create_index(atom) :: response
  def create_index(model, index \\ :index) do
    es_url()
    |> Index.create(model.__es_index__(index), model.__es_settings__())
  end

  @doc """
  Updates the index for `model`
  """
  def update_index(model) do
    url = es_url() <> "/#{model.__es_index__(:index)}/_settings"
    HTTP.put(url, Poison.encode!(model.__es_settings__()))
  end

  @doc """
  Close an index for `model`
  """
  def close_index(model) do
    url = es_url() <> "/#{model.__es_index__(:index)}/_close"
    HTTP.post(url, "")
  end

  @doc """
  open an index for `model`
  """
  def open_index(model) do
    url = es_url() <> "/#{model.__es_index__(:index)}/_open"
    HTTP.post(url, "")
  end

  @doc """
  Updates an index's mappings to the current definition in `model`
  """
  @spec create_mapping(atom) :: response
  def create_mapping(model, index \\ :index) do
    es_url()
    |> Mapping.put(model.__es_index__(index), model.__doc_type__(), model.__es_mappings__())
  end

  @doc """
  Removes the index defined in `model`
  """
  @spec delete_index(atom) :: response
  def delete_index(model, index \\ :index) do
    es_url()
    |> Index.delete(model.__es_index__(index))
  end

  @doc """
  Aliases one index version to another, for instance:

  ```
  alias(MyModel, read: :index)
  ```

  will create an alias of the read version of the model's index
  against it's indexing version
  """
  @spec create_alias(atom, [{atom, atom}]) :: response
  def create_alias(model, [{from, target}]) do
    url = "#{es_url()}/_aliases"
    from_index   = model.__es_index__(from)
    target_index = model.__es_index__(target)
    json = Poison.encode!(%{
      actions: [
        %{
          add: %{
            index: from_index,
            alias: target_index
          },
        }
      ]
    })

    HTTP.post(url, json)
  end

  @doc """
  Deletes the read index and aliases the write index to it
  """
  @spec rotate(atom) :: response
  def rotate(model) do
    with false <- model.__es_index__(:read) == model.__es_index__(:index),
         {:ok, %HTTPoison.Response{body: %{"acknowledged" => true}}} <- delete_index(model, :read),
      do: create_alias(model, index: :read)
  end

  @doc """
  Retries the aliases for a given index
  """
  @spec get_alias(atom, atom) :: response
  def get_alias(model, index) when is_atom(index) do
    index_name = model.__es_index__(index)
    url = "#{es_url()}/#{index_name}/_alias/*"

    HTTP.get(url)
  end

  @doc """
  Checks if the index for `model` exists
  """
  @spec exists?(atom) :: boolean
  def exists?(model, index \\ :read) do
    es_url()
    |> Index.exists?(model.__es_index__(index))
    |> case do
      {:ok, result} -> result
      _ -> false
    end
  end

  @doc """
  Refreshes `model`'s index
  """
  def refresh(model) do
    es_url()
    |> Index.refresh(model.__es_index__())
  end

  @doc """
  Adds a struct into it's associated index.  The struct will be passed through the `ExlasticSearch.Indexable`
  protocol prior to insertion
  """
  @spec index(struct) :: response
  @decorate retry()
  def index(%{__struct__: model} = struct) do
    id = Indexable.id(struct)
    document = Indexable.document(struct)

    es_url()
    |> Document.index(model.__es_index__(:index), model.__doc_type__(), id, document)
    |> log_response()
    |> mark_failure()
  end

  @doc """
  Gets an ES document by _id
  """
  @spec get(struct) :: response
  def get(%{__struct__: model} = struct, index_type \\ :read) do
    es_url()
    |> Document.get(model.__es_index__(index_type), model.__doc_type__(), Indexable.id(struct))
    |> log_response()
    |> decode(Response.Record, model)
  end

  @doc """
  Creates a call to `search/3` by realizing `query` (using `Exlasticsearch.Query.realize/1`) and any provided search opts
  """
  @spec search(Query.t, list) :: response
  def search(%Query{queryable: model} = query, params),
    do: search(model, Query.realize(query), params, query.index_type || :read)

  @doc """
  Searches the index and type associated with `model` according to query `search`
  """
  @spec search(atom, map, list) :: response
  def search(model, search, params, index_type \\ :read) do
    es_url()
    |> Search.search(model.__es_index__(index_type), [model.__doc_type__()], search, params)
    |> log_response()
    |> decode(Response.Search, model)
  end


  @doc """
  Removes `struct` from the index of its model
  """
  @spec delete(struct) :: response
  @decorate retry()
  def delete(%{__struct__: model} = struct) do
    es_url()
    |> Document.delete(model.__es_index__(:index), model.__doc_type__(), Indexable.id(struct))
    |> log_response()
    |> mark_failure()
  end


  @doc """
  Generates an Elasticsearch bulk request. `operations` should be of the form:

  ```
  [
    {:index, struct},
    {:delete, other_struct},
    {:update, third_struct}
  ]
  ```

  The function will handle formatting the bulk request properly and passing each
  struct to the `ExlasticSearch.Indexable` protocol
  """
  def bulk(operations, opts \\ []) do
    bulk_request = operations
                   |> Enum.map(&bulk_operation/1)
                   |> Enum.concat()

    es_url()
    |> Bulk.post(bulk_request, [], opts)
    |> log_response()
    |> mark_failure()
  end

  def index_stream(stream, parallelism \\ 10, demand \\ 10) do
    stream
    |> Stream.chunk_every(@chunk_size)
    |> Flow.from_enumerable(stages: parallelism, max_demand: demand)
    |> Flow.map(&insert_chunk/1)
  end

  defp insert_chunk(chunk) do
    chunk
    |> Enum.map(& {:index, &1})
    |> bulk()

    length(chunk)
  end

  defp log_response(response) do
    Logger.log(@log_level, fn -> "Elasticsearch  response: #{inspect(response)}" end)
    response
  end

  defp bulk_operation({:delete, %{__struct__: model} = struct}),
    do: [%{delete: %{_id: Indexable.id(struct), _index: model.__es_index__(:index), _type: model.__doc_type__()}}]
  defp bulk_operation({op_type, %{__struct__: model} = struct}) do
    [
      %{op_type => %{_id: Indexable.id(struct), _index: model.__es_index__(:index), _type: model.__doc_type__()}},
      Indexable.document(struct)
    ]
  end

  defp es_url(), do: Application.get_env(:exlasticsearch, __MODULE__)[:url]

  defp decode({:ok, %HTTPoison.Response{body: body}}, response, model) do
    case response.parse(body, model) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end
  defp decode(response, _, _), do: response

  defp mark_failure({:ok, %HTTPoison.Response{body: %{"_shards" => %{"successful" => 0}}} = result}), do: {:error, result}
  defp mark_failure({:ok, %HTTPoison.Response{body: %{"errors" => true}} = result}), do: {:error, result}
  defp mark_failure(result), do: result
end
