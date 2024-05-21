import Config

config :exlasticsearch, :type_inference, ExlasticSearch.TypeInference

import_config "#{config_env()}.exs"
