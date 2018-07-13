defimpl Scrivener.Paginater, for: ExlasticSearch.Query do
  alias ExlasticSearch.Response.{
    Search,
    Hits
  }
  
  def paginate(query, %Scrivener.Config{page_number: page, page_size: page_size}) do
    response = ExlasticSearch.Repo.search(query, es_pagination(page, page_size))
    hits     = extract_hits(response)
    total    = total_hits(response)

    %Scrivener.Page{
      page_number: page,
      page_size: page_size,
      entries: hits,
      total_entries: total,
      total_pages: Float.ceil(total / page_size) |> round()
    }
  end

  defp extract_hits({:ok, %Search{hits: %Hits{hits: hits}}}), do: hits
  defp extract_hits(_), do: []

  defp total_hits({:ok, %Search{hits: %Hits{total: total}}}), do: total
  defp total_hits(_), do: 0

  defp es_pagination(page, size), 
    do: [from: (page - 1) * size, size: size]
end