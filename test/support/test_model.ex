defmodule ExlasticSearch.TestModel do
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "test_models" do
    field(:name, :string)
    field(:age, :integer, default: 0)
    field(:group, :string)
    field(:teams, {:array, :map})
  end

  indexes :test_model do
    versions(2)
    settings(%{})
    options(%{dynamic: :strict})
    mapping(:name)
    mapping(:age)
    mapping(:group, type: :keyword)

    mapping(:user, properties: %{ext_name: %{type: :text}})

    mapping(:teams,
      type: :nested,
      properties: %{
        name: %{type: :keyword},
        rating: %{type: :integer}
      }
    )
  end
end

defmodule ExlasticSearch.MultiVersionTestModel do
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "mv_models" do
    field(:name, :string)
    field(:age, :integer, default: 0)
    field(:teams, {:array, :map})
  end

  indexes :multiversion_model do
    versions({:ignore, 2})
    settings(%{})
    options(%{dynamic: :strict})
    mapping(:name)
    mapping(:age)

    mapping(:user, properties: %{ext_name: %{type: :text}})

    mapping(:teams,
      type: :nested,
      properties: %{
        name: %{type: :keyword},
        rating: %{type: :integer}
      }
    )
  end
end

defimpl ExlasticSearch.Indexable,
  for: [ExlasticSearch.TestModel, ExlasticSearch.MultiVersionTestModel] do
  def id(%{id: id}), do: id

  def document(struct, _) do
    struct
    |> Map.from_struct()
    |> Map.take(@for.__mappings__())
  end

  def preload(struct, _), do: struct
end
