defmodule ExlasticSearch.RepoTest do
  use ExUnit.Case, async: true

  alias ExlasticSearch.{
    Repo,
    TestModel,
    TestModel2,
    TypelessTestModel,
    Aggregation,
    Query
  }

  alias ExlasticSearch.MultiVersionTestModel, as: MVTestModel
  alias ExlasticSearch.Query
  alias ExlasticSearch.Repo
  alias ExlasticSearch.TestModel
  alias ExlasticSearch.TestModel2

  setup_all do
    Repo.delete_index(TestModel)
    Repo.create_index(TestModel)
    Repo.create_mapping(TestModel)

    Repo.delete_index(TestModel2)
    Repo.create_index(TestModel2)
    Repo.create_mapping(TestModel2)

    Repo.delete_index(MVTestModel)
    Repo.create_index(MVTestModel)
    Repo.create_mapping(MVTestModel)

    Repo.delete_index(MVTestModel, :read)
    Repo.create_index(MVTestModel, :read)
    Repo.create_mapping(MVTestModel, :read)

    Repo.delete_index(TypelessTestModel)
    Repo.create_index(TypelessTestModel)
    Repo.create_mapping(TypelessTestModel)

    :ok
  end

  describe "#index" do
    test "It will index an element in es" do
      model = %ExlasticSearch.TestModel{id: Ecto.UUID.generate()}
      {:ok, _} = Repo.index(model)

      assert exists?(model)
    end
  end

  describe "#update" do
    test "It will update an element in es" do
      id = Ecto.UUID.generate()
      model = %ExlasticSearch.TestModel{id: id, name: "test"}
      Repo.index(model)

      {:ok, _} = Repo.update(ExlasticSearch.TestModel, id, %{doc: %{name: "test edited"}})

      {:ok, %{_source: data}} = Repo.get(model)
      assert data.name == "test edited"
    end
  end

  describe "#bulk" do
    test "It will bulk index/delete from es" do
      model = %ExlasticSearch.TestModel{id: Ecto.UUID.generate()}
      {:ok, _} = Repo.bulk([{:index, model}])

      assert exists?(model)
    end

    test "It will bulk update from es" do
      model1 = %ExlasticSearch.TestModel{id: Ecto.UUID.generate(), name: "test 1"}
      model2 = %ExlasticSearch.TestModel{id: Ecto.UUID.generate(), name: "test 2"}

      Repo.index(model1)
      Repo.index(model2)

      {:ok, _} =
        Repo.bulk([
          {:update, ExlasticSearch.TestModel, model1.id, %{doc: %{name: "test 1 edited"}}},
          {:update, ExlasticSearch.TestModel, model2.id, %{doc: %{name: "test 2 edited"}}}
        ])

      {:ok, %{_source: data1}} = Repo.get(model1)
      {:ok, %{_source: data2}} = Repo.get(model2)

      assert data1.name == "test 1 edited"
      assert data2.name == "test 2 edited"
    end

    test "It will bulk update nested from es" do
      model1 = %ExlasticSearch.TestModel{
        id: Ecto.UUID.generate(),
        teams: [%{name: "arsenal", rating: 100}]
      }

      model2 = %ExlasticSearch.TestModel{
        id: Ecto.UUID.generate(),
        teams: [%{name: "tottenham", rating: 0}]
      }

      Repo.index(model1)
      Repo.index(model2)

      source =
        "ctx._source.teams.find(cf -> cf.name == params.data.name).rating = params.data.rating"

      data1 = %{script: %{source: source, params: %{data: %{name: "arsenal", rating: 1000}}}}
      data2 = %{script: %{source: source, params: %{data: %{name: "tottenham", rating: -1}}}}

      {:ok, _} =
        Repo.bulk([
          {:update, ExlasticSearch.TestModel, model1.id, data1},
          {:update, ExlasticSearch.TestModel, model2.id, data2}
        ])

      {:ok, %{_source: %{teams: [team1]}}} = Repo.get(model1)
      {:ok, %{_source: %{teams: [team2]}}} = Repo.get(model2)

      assert team1.name == "arsenal"
      assert team1.rating == 1000

      assert team2.name == "tottenham"
      assert team2.rating == -1
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
      models =
        for i <- 1..3,
            do: %TestModel{id: Ecto.UUID.generate(), name: "name #{i}", age: i}

      {:ok, _} = models |> Enum.map(&{:index, &1}) |> Repo.bulk()

      Repo.refresh(TestModel)

      aggregation = Aggregation.terms(Aggregation.new(), :age, field: :age, size: 2)

      {:ok,
       %{
         body: %{
           "aggregations" => %{
             "age" => %{
               "buckets" => buckets
             }
           }
         }
       }} =
        TestModel.search_query()
        |> Query.must(Query.match(:name, "name"))
        |> Repo.aggregate(aggregation)

      assert length(buckets) == 2
      assert Enum.all?(buckets, &(&1["key"] in [1, 2]))
    end

    @tag :skip
    test "It can perform top_hits aggregations, even when nested" do
      models =
        for i <- 1..3 do
          %TestModel{
            id: Ecto.UUID.generate(),
            name: "name #{i}",
            age: i,
            group: if(rem(i, 2) == 0, do: "even", else: "odd")
          }
        end

      {:ok, _} = models |> Enum.map(&{:index, &1}) |> Repo.bulk()

      Repo.refresh(TestModel)

      nested = Aggregation.top_hits(Aggregation.new(), :hits, %{})

      aggregation =
        Aggregation.new()
        |> Aggregation.terms(:group, field: String.to_atom("group.keyword"))
        |> Aggregation.nest(:group, nested)

      {:ok,
       %{
         body: %{
           "aggregations" => %{
             "group" => %{
               "buckets" => buckets
             }
           }
         }
       }} =
        TestModel.search_query()
        |> Query.must(Query.match(:name, "name"))
        |> Repo.aggregate(aggregation)

      assert length(buckets) == 2
      assert Enum.all?(buckets, &(!Enum.empty?(get_hits(&1))))
    end

    @tag :skip
    test "It can perform composite aggregations" do
      models =
        for i <- 1..3 do
          %TestModel{
            id: Ecto.UUID.generate(),
            name: "name #{i}",
            age: i,
            group: if(rem(i, 2) == 0, do: "even", else: "odd")
          }
        end

      {:ok, _} = models |> Enum.map(&{:index, &1}) |> Repo.bulk()

      Repo.refresh(TestModel)

      sources = [
        Aggregation.composite_source(:group, :terms, field: String.to_atom("group.keyword"), order: :desc),
        Aggregation.composite_source(:age, :terms, field: :age, order: :asc)
      ]

      aggregation = Aggregation.composite(Aggregation.new(), :group, sources)

      {:ok,
       %{
         body: %{
           "aggregations" => %{
             "group" => %{
               "buckets" => buckets
             }
           }
         }
       }} =
        TestModel.search_query()
        |> Query.must(Query.match(:name, "name"))
        |> Repo.aggregate(aggregation)

      for i <- 1..3 do
        assert Enum.any?(buckets, fn
                 %{"key" => %{"age" => ^i, "group" => group}} ->
                   group == if rem(i, 2) == 0, do: "even", else: "odd"

                 _ ->
                   false
               end)
      end
    end
  end

  describe "#search/2" do
    test "It will search in a single index" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()
      id3 = Ecto.UUID.generate()

      rand_name = String.replace(Ecto.UUID.generate(), "-", "")

      model1 = %TestModel{id: id1, name: rand_name}
      model2 = %TestModel{id: id2, name: rand_name}
      model3 = %TestModel{id: id3, name: "something else"}

      Repo.index(model1)
      Repo.index(model2)
      Repo.index(model3)

      Repo.refresh(TestModel)

      query = %ExlasticSearch.Query{
        queryable: ExlasticSearch.TestModel,
        filter: [
          %{term: %{name: rand_name}}
        ]
      }

      {:ok, %{hits: %{hits: results}}} = Repo.search(query, [])

      assert length(results) == 2
      assert Enum.find(results, &(&1._id == id1))
      assert Enum.find(results, &(&1._id == id2))
    end

    test "It will search in a multiple indexes" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()
      id3 = Ecto.UUID.generate()
      id4 = Ecto.UUID.generate()

      rand_name = String.replace(Ecto.UUID.generate(), "-", "")

      model1 = %TestModel{id: id1, name: rand_name}
      model2 = %TestModel{id: id2, name: rand_name}
      model3 = %TestModel{id: id3, name: "something else"}

      model4 = %TestModel2{id: id4, name: rand_name}

      Repo.index(model1)
      Repo.index(model2)
      Repo.index(model3)

      Repo.index(model4)

      Repo.refresh(TestModel)
      Repo.refresh(TestModel2)

      query = %ExlasticSearch.Query{
        queryable: [ExlasticSearch.TestModel, ExlasticSearch.TestModel2],
        filter: [
          %{term: %{name: rand_name}}
        ]
      }

      {:ok, %{hits: %{hits: results}}} = Repo.search(query, [])

      assert length(results) == 3
      assert Enum.find(results, &(&1._id == id1))
      assert Enum.find(results, &(&1._id == id2))
      assert Enum.find(results, &(&1._id == id4))
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
