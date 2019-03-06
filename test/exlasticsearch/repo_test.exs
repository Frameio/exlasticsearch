defmodule ExlasticSearch.RepoTest do
  use ExUnit.Case, async: true
  alias ExlasticSearch.{
    Repo,
    TestModel,
    Aggregation,
    Query
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

  describe "#aggregate/2" do
    test "It can perform terms aggreagtions" do
      models = for i <- 1..3,
        do: %TestModel{id: Ecto.UUID.generate(), name: "name #{i}", age: i}

      {:ok, _} = Enum.map(models, & {:index, &1}) |> Repo.bulk()

      aggregation = Aggregation.new() |> Aggregation.terms(:age, field: :age, size: 2)

      {:ok, %{body: %{
        "aggregations" => %{
          "age" => %{
            "buckets" => buckets
          }
        }
      }}} =
        TestModel.search_query()
        |> Query.must(Query.match(:name, "name"))
        |> Repo.aggregate(aggregation)

      assert length(buckets) == 2
      assert Enum.all?(buckets, & &1["key"] in [1, 2])
    end

    test "It can perform top_hits aggregations, even when nested" do
      models = for i <- 1..3 do
        %TestModel{
          id: Ecto.UUID.generate(),
          name: "name #{i}",
          age: i,
          group: (if rem(i, 2) == 0, do: "even", else: "odd")
        }
      end

      {:ok, _} = Enum.map(models, & {:index, &1}) |> Repo.bulk()

      nested = Aggregation.new() |> Aggregation.top_hits(:hits, %{})
      aggregation =
        Aggregation.new()
        |> Aggregation.terms(:group, field: :group)
        |> Aggregation.nest(:group, nested)

      {:ok, %{body: %{
        "aggregations" => %{
          "group" => %{
            "buckets" => buckets
          }
        }
      }}} =
        TestModel.search_query()
        |> Query.must(Query.match(:name, "name"))
        |> Repo.aggregate(aggregation)

      assert length(buckets) == 2
      assert Enum.all?(buckets, & !Enum.empty?(get_hits(&1)))
    end
  end

  defp exists?(model) do
    case Repo.get(model) do
      {:ok, %{found: true}} -> true
      _ -> false
    end
  end

  defp get_hits(%{"hits" => %{"hits" => %{"hits" => hits}}}), do: hits
end
