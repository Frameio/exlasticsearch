defmodule ExlasticSearch.TypeInference.Base do
  defmacro __using__(_) do
    quote do
      @behaviour ExlasticSearch.TypeInference.API
      
      def infer(:binary_id), do: :keyword
      def infer(:integer), do: :long
      def infer(:float), do: :double
      def infer(:string), do: :text
      def infer(:binary), do: :text
      def infer(dt) when dt in [Ecto.DateTime, Timex.Ecto.DateTime, :utc_datetime], do: :date
      def infer(type), do: type

      defoverridable [infer: 1]
    end
  end
end