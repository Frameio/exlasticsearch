import Config

config :exlasticsearch, :type_mappings, [
  {DB.CustomType, :integer}
]

config :exlasticsearch, :monitoring, ExlasticSearch.Monitoring.Mock

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200",
  es8: "http://localhost:9201"


config :exlasticsearch, ExlasticSearch.TypelessTestModel,
  index_type: :es8
