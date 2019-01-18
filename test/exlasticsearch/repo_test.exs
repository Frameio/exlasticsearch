defmodule ExlasticSearch.RepoTest do
  use ExUnit.Case, async: true
  alias ExlasticSearch.{
    Repo,
    TestModel,

  }
  alias ExlasticSearch.MultiVersionTestModel, as: MVTestModel

  setup_all do
    Repo.create_index(TestModel)
    Repo.create_mapping(TestModel)

    Repo.create_index(MVTestModel)
    Repo.create_mapping(MVTestModel)

    Repo.create_index(MVTestModel, :read)
    Repo.create_mapping(MVTestModel, :read)
    :ok
  end

  describe "#index" do
    test "It will index an element in es" do
      model = %ExlasticSearch.TestModel{id: Ecto.UUID.generate()}
      {:ok, _} = Repo.index(model)

      assert exists?(model)
    end
  end

  describe "#bulk" do
    test "It will bulk index/delete from es" do
      model = %ExlasticSearch.TestModel{id: Ecto.UUID.generate()}
      {:ok, _} = Repo.bulk([{:index, model}])

      assert exists?(model)
    end
  end

  describe "#rotate" do
    test "It can deprecate an old index version" do
      model = %MVTestModel{id: Ecto.UUID.generate()}
      {:ok, _} = Repo.index(model)

      Repo.rotate(MVTestModel)

      assert exists?(model)
    end
  end

  defp exists?(model) do
    case Repo.get(model) do
      {:ok, %{found: true}} -> true
      _ -> false
    end
  end
end
