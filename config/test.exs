use Mix.Config

config :exlasticsearch, :type_mappings, [
  {DB.CustomType, :integer}
]