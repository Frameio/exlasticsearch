defmodule ExlasticSearch.Response do
  @moduledoc """
  Base module for ES response parsing.  Works off a few macros, `schema/1`, `field/1`, `has_many/2`, `has_one/2`

  The usage is more or less:

  ```
  use ExlasticSearch.Response

  schema do
    field :total

    has_many :hits, HitsModule
  end
  ```

  This will define:
  * a struct for carrying the response
  * `parse/2` - converts a json decoded map from ES to the given response struct, and converting any models appropriately
  * `to_model/2` - performs model conversion if possible (defaults to no-op) 
  """
  defmacro __using__(_) do
    quote do
      import ExlasticSearch.Response

      def parse(record, model) do
        __schema__(:parse_spec)
        |> convert_keys(record)
        |> parse_associations(__schema__(:associations), model)
        |> to_model(model)
        |> new()
      end

      def to_model(struct, model), do: struct

      def new(map), do: struct(__MODULE__, map)

      defoverridable [to_model: 2]
    end
  end

  @doc """
  Utility for recursively parsing response associations
  """
  def parse_associations(response, associations, model) do
    associations
    |> Enum.map(fn {type, field, parser} ->
      {field, parse_assoc(type, response[field], &parser.parse(&1, model))}
    end)
    |> Enum.into(response)
  end

  @doc """
  Safe conversion of string keyed ES response maps to structifiable atom keyed maps
  """
  def convert_keys(conversion_table, map) when is_map(map) do
    conversion_table
    |> Enum.map(fn {k, ka} ->
      {ka, map[k]}
    end)
    |> Map.new()
  end
  def convert_keys(_, _), do: %{}

  defp parse_assoc(:many, value, func) when is_list(value),
    do: Enum.map(value, func)
  defp parse_assoc(:one, value, func) when is_map(value),
    do: func.(value)
  defp parse_assoc(_, _, _), do: nil


  @doc """
  Opens up the schema definition macro.  Once closed, the following will be defined:

  * `__schema__(:parse_spec)` - A table for converting string keyed maps to atom keyed
  * `__schema__(:attributes)` - basic field attributes
  * `__schema__(:associations)` - a table of associations for the response, along with the responsible parser
  """
  defmacro schema(block) do
    quote do
      Module.register_attribute(__MODULE__, :attributes, accumulate: true)
      Module.register_attribute(__MODULE__, :associations, accumulate: true)

      unquote(block)

      @all_attributes Enum.map(@associations, &elem(&1, 1))
                      |> Enum.concat(@attributes)
                      |> Enum.uniq()
      defstruct @all_attributes

      @parse_spec @all_attributes |> Enum.map(& {Atom.to_string(&1), &1})

      def __schema__(:parse_spec), do: @parse_spec

      def __schema__(:attributes), do: @attributes
      def __schema__(:associations), do: @associations
    end
  end

  @doc """
  Adds a simple field attribute
  """
  defmacro field(field) do
    quote do
      Module.put_attribute(__MODULE__, :attributes, unquote(field))
    end
  end

  @doc """
  Adds a has_many relation or the parser, which assumes a list value

  Accepts:
  * field - the name of the relation
  * parser - module of the responsible parser for parsing it
  """
  defmacro has_many(field, parser) do
    quote do
      Module.put_attribute(__MODULE__, :associations, {:many, unquote(field), unquote(parser)})
    end
  end

  @doc """
  Adds a has_one relation or the parser

  Accepts:
  * field - the name of the relation
  * parser - module of the responsible parser for parsing it
  """
  defmacro has_one(field, parser) do
    quote do
      Module.put_attribute(__MODULE__, :associations, {:one, unquote(field), unquote(parser)})
    end
  end
end
