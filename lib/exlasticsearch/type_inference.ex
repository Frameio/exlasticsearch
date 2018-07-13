defmodule ExlasticSearch.TypeInference do
  defmodule API do
    @moduledoc """
    Behaviour for inferring module types.  A default implementation is available
    in ExlasticSearch.TypeInference.Base
    """
    @callback infer(atom) :: atom
  end

  use ExlasticSearch.TypeInference.Base
end