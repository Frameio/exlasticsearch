defmodule ExlasticSearch.TypeInference do
  @moduledoc """
  Default type inference implementation.

  If you desire to override it, simply do:

      defmodule MyTypeInference do
        use ExlasticSearch.TypeInference.Base

        def infer(CustomType), do: :text # or whatever you chose
        def infer(type), do: super(type)
      end

  Then configure it with `config :exlasticsearch, :type_inference, MyTypeInference`
  """
  use ExlasticSearch.TypeInference.Base

  defmodule API do
    @moduledoc """
    Behaviour for inferring module types.

    A default implementation is available in `ExlasticSearch.TypeInference.Base`
    """
    @callback infer(atom) :: atom
  end
end
