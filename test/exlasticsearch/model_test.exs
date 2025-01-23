defmodule ExlasticSearch.ModelTest do
  use ExUnit.Case, async: true

  alias ExlasticSearch.TestModel

  describe "ES Schema functions" do
    test "__doc_type__" do
      assert TestModel.__doc_type__() == :test_model
    end

    test "__es_index__" do
      assert TestModel.__es_index__() == "test_models2"
    end

    test "__es_mappings__" do
      %{properties: mappings, dynamic: val} = TestModel.__es_mappings__()

      assert val == :strict
      assert mappings.name.type == :text
      assert mappings.age.type == :long
      assert mappings.user.properties.ext_name.type == :text
    end

    test "__mapping_options__" do
      %{dynamic: val} = TestModel.__mapping_options__()

      assert val == :strict
    end

    test "es_decode with nested objects" do
      %TestModel.SearchResult{} =
        result =
        TestModel.es_decode(%{
          "name" => "some_name",
          "age" => 2,
          "user" => %{
            "ext_name" => "other_name"
          }
        })

      assert result.name == "some_name"
      assert result.age == 2
      assert result.user.ext_name == "other_name"
    end

    test "es_decode with nested arrays" do
      %TestModel.SearchResult{} =
        result =
        TestModel.es_decode(%{
          "name" => "some_name",
          "age" => 2,
          "user" => [
            %{"ext_name" => "other_name"},
            %{"ext_name" => "second_name"}
          ]
        })

      assert result.name == "some_name"
      assert result.age == 2
      assert length(result.user) == 2
      assert Enum.at(result.user, 0) == %{ext_name: "other_name"}
      assert Enum.at(result.user, 1) == %{ext_name: "second_name"}
    end

    test "search_query" do
      %ExlasticSearch.Query{queryable: q} = TestModel.search_query()

      assert q == TestModel
    end
  end
end
