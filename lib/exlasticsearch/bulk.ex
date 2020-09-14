defmodule ExlasticSearch.BulkOperation do
  @moduledoc """
  Handles bulk request generation
  """

  alias ExlasticSearch.Indexable

  @doc """
  Generates a request for inserts, updates, nested property update and deletes
  that can be sent as a bulk request using Elastix
  """
  def bulk_operation({:delete, _struct, _index} = instruction),
    do: bulk_operation_delete(instruction)

  def bulk_operation({:delete, struct}),
    do: bulk_operation_delete({:delete, struct, :index})

  def bulk_operation({:update, _struct, _id, _updates, _index} = instruction),
    do: bulk_operation_update(instruction)

  def bulk_operation({:update, struct, id, updates}),
    do: bulk_operation_update({:update, struct, id, updates, :index})

  def bulk_operation({:nested, _struct, _id, _source, _data, _index} = instruction),
    do: bulk_operation_nested(instruction)

  def bulk_operation({:nested, struct, id, source, data}),
    do: bulk_operation_nested({:nested, struct, id, source, data, :index})

  def bulk_operation({_op_type, _struct, _index} = instruction),
    do: bulk_operation_default(instruction)

  def bulk_operation({op_type, struct}),
    do: bulk_operation_default({op_type, struct, :index})

  defp bulk_operation_default({op_type, %{__struct__: model} = struct, index}) do
    [
      %{
        op_type => %{
          _id: Indexable.id(struct),
          _index: model.__es_index__(index),
          _type: model.__doc_type__()
        }
      },
      build_document(struct, index)
    ]
  end

  defp bulk_operation_nested({:nested, struct, id, source, data, index}) do
    data = data |> Map.drop([:document_id])

    [
      %{
        update: %{
          _id: id,
          _index: struct.__es_index__(index),
          _type: struct.__doc_type__()
        }
      },
      %{script: %{source: source, params: %{data: data}}}
    ]
  end

  defp bulk_operation_update({:update, struct, id, updates, index}) do
    [
      %{update: %{_id: id, _index: struct.__es_index__(index), _type: struct.__doc_type__()}},
      %{doc: updates}
    ]
  end

  defp bulk_operation_delete({:delete, %{__struct__: model} = struct, index}) do
    [
      %{
        delete: %{
          _id: Indexable.id(struct),
          _index: model.__es_index__(index),
          _type: model.__doc_type__()
        }
      }
    ]
  end

  defp build_document(struct, index),
    do: struct |> Indexable.preload(index) |> Indexable.document(index)
end
