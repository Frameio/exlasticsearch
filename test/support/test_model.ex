defmodule ExlasticSearch.TestModel do
  @moduledoc false
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

defmodule ExlasticSearch.TestModel2 do
  @moduledoc false
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "test_models2" do
    field(:name, :string)
  end

  indexes :test_model2 do
    versions(2)
    settings(%{})
    options(%{dynamic: :strict})
    mapping(:name)
  end
end

defmodule ExlasticSearch.MultiVersionTestModel do
  @moduledoc false
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

defmodule ExlasticSearch.TypelessTestModel do
  @moduledoc false
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "typeless_test_models" do
    field(:name, :string)
    field(:age, :integer, default: 0)
    field(:group, :string)
    field(:teams, {:array, :map})
  end

  indexes :typeless_test_model, doc_type: nil do
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

defmodule ExlasticSearch.TypelessTestModel2 do
  @moduledoc false
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "typeless_test_models2" do
    field(:name, :string)
  end

  indexes :typeless_test_model2, doc_type: nil do
    versions(2)
    settings(%{})
    options(%{dynamic: :strict})
    mapping(:name)
  end
end

defmodule ExlasticSearch.TypelessMultiVersionTestModel do
  @moduledoc false
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "typeless_mv_models" do
    field(:name, :string)
    field(:age, :integer, default: 0)
    field(:teams, {:array, :map})
  end

  indexes :typeless_multiversion_model, doc_type: nil do
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
  for: [
    ExlasticSearch.TestModel,
    ExlasticSearch.TestModel2,
    ExlasticSearch.MultiVersionTestModel,
    ExlasticSearch.TypelessTestModel,
    ExlasticSearch.TypelessTestModel2,
    ExlasticSearch.TypelessMultiVersionTestModel
  ] do
  def id(%{id: id}), do: id

  def document(struct) do
    struct
    |> Map.from_struct()
    |> Map.take(@for.__mappings__())
  end

  def document(struct, _) do
    struct
    |> Map.from_struct()
    |> Map.take(@for.__mappings__())
  end

  def preload(struct), do: struct

  def preload(struct, _), do: struct
end
