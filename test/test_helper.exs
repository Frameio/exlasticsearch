# Elastix supports multiple codecs, we want to set it to the default for ExlasticSearch
Application.put_env(:elastix, :json_codec, ExlasticSearch.Repo.json_library())
ExUnit.start(capture_log: [level: :info])
