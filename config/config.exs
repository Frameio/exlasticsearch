import Config

config :exlasticsearch, :type_inference, ExlasticSearch.TypeInference

config :exlasticsearch, :monitoring, ExlasticSearch.Monitoring.Mock

config :exlasticsearch, ExlasticSearch.Repo,
  url: "http://localhost:9200"
