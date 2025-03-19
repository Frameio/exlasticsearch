import Config

config :elastix, json_codec: Jason

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200",
  es8: "http://localhost:9201"

config :exlasticsearch, ExlasticSearch.TypelessTestModel, index_type: :es8
config :exlasticsearch, :monitoring, ExlasticSearch.Monitoring.Mock

config :exlasticsearch, :type_mappings, [
  {DB.CustomType, :integer}
]

config :exlasticsearch, json_library: Jason
