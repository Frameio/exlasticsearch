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
  alias ExlasticSearch.{Indexable, Query, Response}
  alias Elastix.{Index, Mapping, Document, Bulk, Search, HTTP}
  require Logger

  @chunk_size 2000
  @type response :: {:ok, %HTTPoison.Response{}} | {:error, any}

  @doc """
  Creates an index as defined in `model`
  """
  @spec create_index(atom) :: response
  def create_index(model),
    do: es_url() |> Index.create(model.__es_index__(), model.__es_settings__())

  @doc """
  Updates the index for `model`
  """
  def update_index(model) do
    url = es_url() <> "/#{model.__es_index__()}/_settings"
    HTTP.put(url, Poison.encode!(model.__es_settings__()))
  end

  @doc """
  Close an index for `model`
  """
  def close_index(model) do
    url = es_url() <> "/#{model.__es_index__()}/_close"
    HTTP.post(url, "")
  end

  @doc """
  open an index for `model`
  """
  def open_index(model) do
    url = es_url() <> "/#{model.__es_index__()}/_open"
    HTTP.post(url, "")
  end

  @doc """
  Updates an index's mappings to the current definition in `model`
  """
  @spec create_mapping(atom) :: response
  def create_mapping(model),
    do: es_url() |> Mapping.put(model.__es_index__(), model.__doc_type__(), model.__es_mappings__())

  @doc """
  Removes the index defined in `model`
  """
  @spec delete_index(atom) :: response
  def delete_index(model),
    do: es_url() |> Index.delete(model.__es_index__())

  @doc """
  Checks if the index for `model` exists
  """
  @spec exists?(atom) :: boolean
  def exists?(model) do
    es_url()
    |> Index.exists?(model.__es_index__())
    |> case do
      {:ok, result} -> result
      _ -> false
    end
  end

  @doc """
  Refreshes `model`'s index
  """
  def refresh(model) do
    es_url() |> Index.refresh(model.__es_index__())
  end

  @doc """
  Adds a struct into it's associated index.  The struct will be passed through the `ExlasticSearch.Indexable`
  protocol prior to insertion
  """
  @spec index(struct) :: response
  def index(%{__struct__: model} = struct) do
    id = Indexable.id(struct)
    document = Indexable.document(struct)
    es_url() |> Document.index(model.__es_index__(), model.__doc_type__(), id, document)
  end

  @doc """
  Gets an ES document by id
  """
  @spec get(struct) :: response
  def get(%{__struct__: model} = struct) do
    es_url()
    |> Document.get(model.__es_index__(), model.__doc_type__(), Indexable.id(struct))
    |> decode(Response.Record, model)
  end

  @doc """
  Creates a call to `search/3` by realizing `query` (using `Exlasticsearch.Query.realize/1`) and any provided search opts
  """
  @spec search(Query.t, list) :: response
  def search(%Query{queryable: model} = query, params), do: search(model, Query.realize(query), params)

  @doc """
  Searches the index and type associated with `model` according to query `search`
  """
  @spec search(atom, map, list) :: response
  def search(model, search, params) do
    es_url()
    |> Search.search(model.__es_index__(), [model.__doc_type__()], search, params)
    |> decode(Response.Search, model)
  end


  @doc """
  Removes `struct` from the index of its model
  """
  @spec delete(struct) :: response
  def delete(%{__struct__: model} = struct),
    do: es_url() |> Document.delete(model.__es_index__(), model.__doc_type__(), Indexable.id(struct))


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
    ExlasticSearch.Monitoring.increment("elasticsearch.batch_operations", length(operations))
    bulk_request = operations 
                   |> Enum.map(&bulk_operation/1) 
                   |> Enum.concat()
                   
    result       = es_url() 
                   |> Bulk.post(bulk_request, [], opts)

    Logger.debug fn -> "ES Bulk response #{inspect(result)}" end
    result
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

  defp bulk_operation({:delete, %{__struct__: model} = struct}),
    do: [%{delete: %{_id: Indexable.id(struct), _index: model.__es_index__(), _type: model.__doc_type__()}}]
  defp bulk_operation({op_type, %{__struct__: model} = struct}) do
    [
      %{op_type => %{_id: Indexable.id(struct), _index: model.__es_index__(), _type: model.__doc_type__()}},
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
end
