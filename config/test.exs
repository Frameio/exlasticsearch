import Config

config :elastix, json_codec: Jason

config :exlasticsearch, ExlasticSearch.Repo, url: "http://localhost:9200"
config :exlasticsearch, ExlasticSearch.TypelessTestModel, index_type: :es8
config :exlasticsearch, :monitoring, ExlasticSearch.Monitoring.Mock
config :exlasticsearch, json_library: Jason
