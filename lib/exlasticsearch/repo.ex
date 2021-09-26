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
  alias ExlasticSearch.{Indexable, Query, Aggregation, Response}
  alias ExlasticSearch.BulkOperation
  alias Elastix.{Index, Mapping, Document, Bulk, Search, HTTP}
  require Logger

  @chunk_size 2000
  @type response :: {:ok, %HTTPoison.Response{}} | {:error, any}
  @log_level Application.get_env(:exlasticsearch, __MODULE__, [])
             |> Keyword.get(:log_level, :debug)

  @doc """
  Creates an index as defined in `model`
  """
  @spec create_index(atom) :: response
  def create_index(model, index \\ :index) do
    es_url(index)
    |> Index.create(model.__es_index__(index), model.__es_settings__())
  end

  @doc """
  Updates the index for `model`
  """
  def update_index(model, index \\ :index) do
    url = es_url(index) <> "/#{model.__es_index__(index)}/_settings"
    HTTP.put(url, Poison.encode!(model.__es_settings__()))
  end

  @doc """
  Close an index for `model`
  """
  def close_index(model, index \\ :index) do
    url = es_url(index) <> "/#{model.__es_index__(index)}/_close"
    HTTP.post(url, "")
  end

  @doc """
  open an index for `model`
  """
  def open_index(model, index \\ :index) do
    url = es_url(index) <> "/#{model.__es_index__(index)}/_open"
    HTTP.post(url, "")
  end

  @doc """
  Updates an index's mappings to the current definition in `model`
  """
  @spec create_mapping(atom) :: response
  def create_mapping(model, index \\ :index, opts \\ []) do
    es_url(index)
    |> Mapping.put(model.__es_index__(index), model.__doc_type__(), model.__es_mappings__(), opts)
  end

  @doc """
  Removes the index defined in `model`
  """
  @spec delete_index(atom) :: response
  def delete_index(model, index \\ :index) do
    es_url(index)
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
  def create_alias(model, [{from, target}], index \\ :index) do
    url = "#{es_url(index)}/_aliases"
    from_index = model.__es_index__(from)
    target_index = model.__es_index__(target)

    json =
      Poison.encode!(%{
        actions: [
          %{
            add: %{
              index: from_index,
              alias: target_index
            }
          }
        ]
      })

    HTTP.post(url, json)
  end

  @doc """
  Deletes the read index and aliases the write index to it
  """
  @spec rotate(atom, atom, atom) :: response
  def rotate(model, read \\ :read, index \\ :index) do
    with false <- model.__es_index__(read) == model.__es_index__(index),
         _result <- delete_index(model, read),
         do: create_alias(model, index: read)
  end

  @doc """
  Retries the aliases for a given index
  """
  @spec get_alias(atom, atom) :: response
  def get_alias(model, index) when is_atom(index) do
    index_name = model.__es_index__(index)
    url = "#{es_url(index)}/#{index_name}/_alias/*"

    HTTP.get(url)
  end

  @doc """
  Checks if the index for `model` exists
  """
  @spec exists?(atom) :: boolean
  def exists?(model, index \\ :read) do
    es_url(index)
    |> Index.exists?(model.__es_index__(index))
    |> case do
      {:ok, result} -> result
      _ -> false
    end
  end

  @doc """
  Refreshes `model`'s index
  """
  def refresh(model, index \\ :read) do
    es_url(index)
    |> Index.refresh(model.__es_index__(index))
  end

  @doc """
  Adds a struct into it's associated index.  The struct will be passed through the `ExlasticSearch.Indexable`
  protocol prior to insertion
  """
  @spec index(struct) :: response
  @decorate retry()
  def index(%{__struct__: model} = struct, index \\ :index) do
    id = Indexable.id(struct)
    document = build_document(struct, index)

    es_url(index)
    |> Document.index(model.__es_index__(index), model.__doc_type__(), id, document)
    |> log_response()
    |> mark_failure()
  end

  @doc """
  Updates the document of the passed in id for the index associated to the model
  """
  @decorate retry()
  def update(model, id, data, index \\ :index) do
    es_url(index)
    |> Document.update(model.__es_index__(index), model.__doc_type__(), id, data)
    |> log_response()
    |> mark_failure()
  end

  @doc """
  Generates an Elasticsearch bulk request. `operations` should be of the form:

  Note: the last element in each Tuple is optional and will default to :index
  ```
  [
    {:index, struct, index},
    {:delete, other_struct, index},
    {:update, third_struct, id, map, index}
  ]
  ```

  The function will handle formatting the bulk request properly and passing each
  struct to the `ExlasticSearch.Indexable` protocol
  """
  def bulk(operations, index \\ :index, query_params \\ [], opts \\ []) do
    bulk_request =
      operations
      |> Enum.map(&BulkOperation.bulk_operation/1)
      |> Enum.concat()

    es_url(index)
    |> Bulk.post(bulk_request, opts, query_params)
    |> log_response()
    |> mark_failure()
  end

  @doc """
  Updates all document based on the query using the provided script.
  """
  def update_by_query(model, query, script, index \\ :index) do
    es_url(index)
    |> Document.update_by_query(model.__es_index__(index), query, script)
    |> log_response()
    |> mark_failure()
  end

  @doc """
  Gets an ES document by _id
  """
  @spec get(struct) :: response
  def get(%{__struct__: model} = struct, index_type \\ :read) do
    es_url(index_type)
    |> Document.get(model.__es_index__(index_type), model.__doc_type__(), Indexable.id(struct))
    |> log_response()
    |> decode(Response.Record, model)
  end

  @doc """
  Creates a call to `search/3` by realizing `query` (using `Exlasticsearch.Query.realize/1`) and any provided search opts
  """
  @spec search(Query.t(), list) :: response
  def search(%Query{queryable: model} = query, params),
    do: search(model, Query.realize(query), params, query.index_type || :read)

  @doc """
  Searches the index and type associated with `model` according to query `search`
  """
  @spec search(atom, map, list) :: response
  def search(model, search, params, index_type \\ :read) do
    index = model_to_index(model, index_type)
    doc_types = model_to_doc_types(model)

    es_url(index_type)
    |> Search.search(index, doc_types, search, params)
    |> log_response()
    |> decode(Response.Search, model, index_type)
  end

  defp model_to_index(models, index_type) when is_list(models) do
    models
    |> Enum.map(& &1.__es_index__(index_type))
    |> Enum.join(",")
  end
  defp model_to_index(model, index_type), do: model.__es_index__(index_type)

  defp model_to_doc_types(models) when is_list(models) do
    models
    |> Enum.map(& &1.__doc_type__())
  end
  defp model_to_doc_types(model), do: [model.__doc_type__()]

  @doc """
  Performs an aggregation against a query, and returns only the aggregation results.
  """
  def aggregate(%Query{queryable: model} = query, %Aggregation{} = aggregation) do
    search =
      Query.realize(query)
      |> Map.merge(Aggregation.realize(aggregation))

    index_type = query.index_type || :read

    es_url(index_type)
    |> Search.search(model.__es_index__(index_type), [model.__doc_type__()], search, size: 0)
    # TODO: figure out how to decode these, it's not trivial to type them
    |> log_response()
  end

  @doc """
  Removes `struct` from the index of its model
  """
  @spec delete(struct) :: response
  @decorate retry()
  def delete(%{__struct__: model} = struct, index \\ :index) do
    es_url(index)
    |> Document.delete(model.__es_index__(index), model.__doc_type__(), Indexable.id(struct))
    |> log_response()
    |> mark_failure()
  end

  def index_stream(stream, index \\ :index, parallelism \\ 10, demand \\ 10) do
    stream
    |> Stream.chunk_every(@chunk_size)
    |> Flow.from_enumerable(stages: parallelism, max_demand: demand)
    |> Flow.map(&insert_chunk(&1, index))
  end

  defp insert_chunk(chunk, index) do
    chunk
    |> Enum.map(&{:index, &1, index})
    |> bulk(index)

    length(chunk)
  end

  defp log_response(response) do
    Logger.log(@log_level, fn -> "Elasticsearch  response: #{inspect(response)}" end)
    response
  end

  defp build_document(struct, index),
    do: struct |> Indexable.preload(index) |> Indexable.document(index)

  defp es_url(index) do

    case Application.get_env(:exlasticsearch, __MODULE__)[index] do
      nil ->
        Application.get_env(:exlasticsearch, __MODULE__)[:url]
      url ->
        url
    end
  end

  defp decode(result, response, model, index_type \\ :read)
  defp decode({:ok, %HTTPoison.Response{body: body}}, response, model, index_type) do
    case response.parse(body, model, index_type) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  defp decode(response, _, _, _), do: response

  defp mark_failure(
         {:ok, %HTTPoison.Response{body: %{"_shards" => %{"successful" => 0}}} = result}
       ),
       do: {:error, result}

  defp mark_failure({:ok, %HTTPoison.Response{body: %{"errors" => true}} = result}),
    do: {:error, result}

  defp mark_failure(result), do: result
end
