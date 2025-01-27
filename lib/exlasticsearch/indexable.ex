defprotocol ExlasticSearch.Indexable do
  @moduledoc """
  Protocol for converting Ecto structs to ES-compatible maps.

  `ExlasticSearch.Repo` uses this internally to effect any conversion prior to communicating with Elasticsearch itself.
  """

  @doc "ES record id."
  @spec id(struct) :: binary
  def id(_)

  @doc "Properties map to be inserted into ES."
  @spec document(struct, atom) :: map
  def document(_, _)

  @doc "Properties map to be inserted into ES."
  @spec document(struct) :: map
  def document(_)

  @doc "Any preloads needed to call `document/2`."
  @spec preload(struct, atom) :: struct
  def preload(_, _)

  @doc "Any preloads needed to call `document/2`."
  @spec preload(struct) :: struct
  def preload(_)
end
