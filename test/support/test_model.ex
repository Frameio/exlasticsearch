defmodule ExlasticSearch.TestModel do
  use Ecto.Schema
  use ExlasticSearch.Model

  schema "test_models" do
    field :name, :string
    field :age, :integer, default: 0
  end

  indexes :test_model do
    settings %{}
    mapping :name
    mapping :age

    mapping :user, properties: %{ext_name: %{type: :text}}
  end
end