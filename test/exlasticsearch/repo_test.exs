defmodule ExlasticSearch.RepoTest do
  use ExUnit.Case, async: true
  alias ExlasticSearch.{
    Repo,
    TestModel
  }

  setup_all do
    Repo.create_index(TestModel)
    Repo.create_mapping(TestModel)
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

  defp exists?(model) do
    case Repo.get(model) do
      {:ok, %{found: true}} -> true
      _ -> false
    end
  end
end