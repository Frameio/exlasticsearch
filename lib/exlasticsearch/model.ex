defmodule ExlasticSearch.Model do
  @moduledoc """
  Base macro for generating elasticsearch modules.  Is intended to be used in conjunction with a
  Ecto model (although that is not strictly necessary).
  
  It includes three primary macros:

  * `indexes/2`
  * `settings/1`
  * `mapping/2`

  The usage is something like this

  ```
  indexes :my_type do
    settings Application.get_env(:some, :settings)

    mapping :column
    mapping :other_column, type: :keyword
  end
  ```

  This will set up settings and mappings for index my_types with type my_type (specify the singularized
  type in the macro, so pluralization works naturally).

  The following functions will also be created:

  * `__es_mappings__/0` - map of all fully specified mappings for the given type
  * `__mappings__/0` - columns with mappings for the given type
  * `__es_index__/0` - the elasticsearch index for this model
  * `__doc_type__/0` - the default document type for searches in __es_index__()
  * `__es_settings__/0` - the settings for the index of this model
  """
  @type_inference Application.get_env(:exlasticsearch, :type_inference)

  defmacro __using__(_) do
    quote do
      import ExlasticSearch.Model
      import Ecto.Query, only: [from: 2]

      @es_query %ExlasticSearch.Query{queryable: __MODULE__}

      def es_type(column), do: __schema__(:type, column) |> ecto_to_es()

      def search_query(), do: @es_query

      def indexing_query(query \\ __MODULE__) do
        Ecto.Query.from(r in query, order_by: [asc: :id])
      end

      defoverridable [indexing_query: 0, indexing_query: 1]
    end
  end

  @doc """
  Opens up index definition for the current model.  Will name the index and generate metadata
  attributes for the index based on subsequent calls to `settings/1` and `mappings/2`.

  Accepts
  * `type` - the indexes type (and index name will be `type <> "s"`)
  * `block` - the definition of the index
  """
  defmacro indexes(type, block) do
    quote do
      Module.register_attribute(__MODULE__, :es_mappings, accumulate: true)

      def __doc_type__(), do: unquote(type)

      def __es_index__(), do: "#{unquote(type)}s"

      unquote(block)

      def __es_mappings__(), do: %{
        properties: @es_mappings
                    |> Enum.map(fn {key, value} ->
                      {key, value |> Enum.into(%{type: es_type(key)})}
                    end)
                    |> Enum.into(%{})
      }

      @es_mapped_cols @es_mappings |> Enum.map(&elem(&1, 0))
      @es_decode_template @es_mappings
                          |> Enum.map(fn {k, v} -> {k, Map.new(v)} end)
                          |> Enum.map(&ExlasticSearch.Model.mapping_template/1)

      def __mappings__(), do: @es_mapped_cols

      def __es_decode_template__(), do: @es_decode_template

      def es_decode(map) when is_map(map), do: struct(__MODULE__.SearchResult, es_decode(map, __MODULE__))
      def es_decode(_), do: nil

      @after_compile ExlasticSearch.Model
    end
  end

  defmacro __after_compile__(_, _) do
    quote do
      use ExlasticSearch.Model.SearchResult
    end
  end

  defmodule SearchResult do
    @moduledoc """
    Wrapper for a models search result.  Used for response parsing
    """
    defmacro __using__(_) do
      columns = __CALLER__.module.__mappings__()
      quote do
        defmodule SearchResult do
          defstruct unquote(columns)
        end
      end
    end
  end

  @doc """
  Adds a new mapping to the ES schema.  The type of the mapping will be inferred automatically, unless explictly set
  in props.

  Accepts:
    * `name` - the name of the mapping
    * `props` - is a map/kw list of ES mapping configuration (e.g. `search_analyzer: "my_search_analyzer", type: "text"`)
  """
  defmacro mapping(name, props \\ []) do
    quote do
      ExlasticSearch.Model.__mapping__(__MODULE__, unquote(name), unquote(props))
    end
  end

  @doc """
  A map of index settings.  Structure is the same as specified by ES.
  """
  defmacro settings(settings) do
    quote do
      def __es_settings__(), do: %{settings: unquote(settings)}
    end
  end

  def __mapping__(mod, name, properties) do
    Module.put_attribute(mod, :es_mappings, {name, properties})
  end

  @doc """
  Converts a search result to `model`'s search result type
  """
  def es_decode(source, model) do
    model.__es_decode_template__()
    |> do_decode(source)
  end

  defp do_decode(template, source) when is_map(source) do
    template
    |> Enum.map(fn
      {key, atom_key, :preserve} -> {atom_key, Map.get(source, key)}
      {key, atom_key, template} -> {atom_key, do_decode(template, Map.get(source, key))}
    end)
    |> Enum.into(%{})
  end
  defp do_decode(_, _), do: nil

  def mapping_template({name, %{properties: properties}}), do: {Atom.to_string(name), name, Enum.map(properties, &mapping_template/1)}
  def mapping_template({name, _}), do: {Atom.to_string(name), name, :preserve}

  def ecto_to_es(type), do: @type_inference.infer(type)
end
