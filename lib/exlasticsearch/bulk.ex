defmodule ExlasticSearch.BulkOperation do
  @moduledoc """
  Handles bulk request generation
  """

  alias ExlasticSearch.Indexable

  @doc """
  Generates a request for inserts, updates and deletes
  that can be sent as a bulk request using Elastix
  """
  def bulk_operation({:delete, _struct, _index} = instruction),
    do: bulk_operation_delete(instruction)

  def bulk_operation({:delete, struct}),
    do: bulk_operation_delete({:delete, struct, :index})

  def bulk_operation({:update, _struct, _id, _data, _index} = instruction),
    do: bulk_operation_update(instruction)

  def bulk_operation({:update, struct, id, data}),
    do: bulk_operation_update({:update, struct, id, data, :index})

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

  defp bulk_operation_update({:update, struct, id, data, index}) do
    [
      %{update: %{_id: id, _index: struct.__es_index__(index), _type: struct.__doc_type__()}},
      data
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
