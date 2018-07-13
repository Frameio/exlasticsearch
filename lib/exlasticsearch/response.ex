defmodule ExlasticSearch.Response do

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

  def parse_associations(response, associations, model) do
    associations
    |> Enum.map(fn {type, field, parser} ->
      {field, parse_assoc(type, response[field], &parser.parse(&1, model))}
    end)
    |> Enum.into(response)
  end

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

  defmacro field(field) do
    quote do
      Module.put_attribute(__MODULE__, :attributes, unquote(field))
    end
  end

  defmacro has_many(field, parser) do
    quote do
      Module.put_attribute(__MODULE__, :associations, {:many, unquote(field), unquote(parser)})
    end
  end

  defmacro has_one(field, parser) do
    quote do
      Module.put_attribute(__MODULE__, :associations, {:one, unquote(field), unquote(parser)})
    end
  end
end
