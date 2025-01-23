defmodule ExlasticSearch.Model do
  @moduledoc """
  Base macro for generating elasticsearch modules.  Is intended to be used in conjunction with a
  Ecto model (although that is not strictly necessary).

  It includes three primary macros:

  * `indexes/2`
  * `settings/1`
  * `mapping/2`

  The usage is something like this

      indexes :my_type do
        settings Application.get_env(:some, :settings)

        mapping :column
        mapping :other_column, type: :keyword
      end

  This will set up settings and mappings for index my_types with type my_type (specify the singularized
  type in the macro, so pluralization works naturally).

  The following functions will also be created:

  * `__es_mappings__/0` - map of all fully specified mappings for the given type
  * `__mappings__/0` - columns with mappings for the given type
  * `__es_index__/0` - the elasticsearch index for this model
  * `__es_index__/1` - the elasticsearch index for reads/writes when performing zero-downtime updates
  (pass either `:read` or `:index` respectively)
  * `__doc_type__/0` - the default document type for searches in __es_index__()
  * `__es_settings__/0` - the settings for the index of this model
  """
  @type_inference Application.compile_env(
                    :exlasticsearch,
                    :type_inference,
                    ExlasticSearch.TypeInference
                  )

  defmacro __using__(_) do
    quote do
      import Ecto.Query, only: [from: 2]
      import ExlasticSearch.Model

      @es_query %ExlasticSearch.Query{
        queryable: __MODULE__,
        index_type:
          Keyword.get(
            Application.compile_env(:exlasticsearch, __MODULE__, []),
            :index_type,
            :read
          )
      }
      @mapping_options %{}

      def es_type(column), do: :type |> __schema__(column) |> ecto_to_es()

      def search_query, do: @es_query

      def indexing_query(query \\ __MODULE__) do
        Ecto.Query.from(r in query, order_by: [asc: :id])
      end

      defoverridable indexing_query: 0, indexing_query: 1
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
      @read_version :ignore
      @index_version :ignore

      def __doc_type__, do: unquote(type)

      unquote(block)

      def __es_index__(type \\ :read)
      def __es_index__(:read), do: index_version(unquote(type), @read_version)
      def __es_index__(:index), do: index_version(unquote(type), @index_version)
      def __es_index__(:delete), do: __es_index__(:read)
      def __es_index__(custom_index), do: "#{unquote(type)}_#{custom_index}"

      def __es_mappings__ do
        Map.put(
          @mapping_options,
          :properties,
          Map.new(@es_mappings, fn {key, value} -> {key, Enum.into(value, %{type: es_type(key)})} end)
        )
      end

      @es_mapped_cols Enum.map(@es_mappings, &elem(&1, 0))
      @es_decode_template @es_mappings
                          |> Enum.map(fn {k, v} -> {k, Map.new(v)} end)
                          |> Enum.map(&ExlasticSearch.Model.mapping_template/1)

      def __mappings__, do: @es_mapped_cols

      def __mapping_options__, do: @mapping_options

      def __es_decode_template__, do: @es_decode_template

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
          @moduledoc false
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
      def __es_settings__, do: %{settings: unquote(settings)}
    end
  end

  defmacro options(options) do
    quote do
      @mapping_options unquote(options)
    end
  end

  defmacro versions({index, read}) do
    quote do
      @read_version unquote(read)
      @index_version unquote(index)
    end
  end

  defmacro versions(index) do
    quote do
      @read_version unquote(index)
      @index_version unquote(index)
    end
  end

  def __mapping__(mod, name, properties) do
    Module.put_attribute(mod, :es_mappings, {name, properties})
  end

  @doc """
  Converts a search result to `model`'s search result type
  """
  def es_decode(source, model) do
    do_decode(model.__es_decode_template__(), source)
  end

  def index_version(type), do: "#{type}s"
  def index_version(type, :ignore), do: index_version(type)
  def index_version(type, version), do: "#{type}s#{version}"

  def mapping_template({name, %{properties: properties}}),
    do: {Atom.to_string(name), name, Enum.map(properties, &mapping_template/1)}

  def mapping_template({name, _}), do: {Atom.to_string(name), name, :preserve}

  def ecto_to_es(type) do
    @type_inference.infer(type)
  end

  defp do_decode(template, source) when is_map(source) do
    Map.new(template, fn
      {key, atom_key, :preserve} -> {atom_key, Map.get(source, key)}
      {key, atom_key, template} -> {atom_key, do_decode(template, Map.get(source, key))}
    end)
  end

  defp do_decode(template, source) when is_list(source) do
    Enum.map(source, &do_decode(template, &1))
  end

  defp do_decode(_, _), do: nil
end
