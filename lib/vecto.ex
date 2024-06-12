defmodule Vecto do
  @moduledoc """
  Full-Text Search, Vector Search and Hybrid Search with Postgres and Ecto

  Loosely based on:
  - https://github.com/pgvector/pgvector-python/blob/master/examples/hybrid_search_rrf.py
  - https://github.com/Azure-Samples/rag-postgres-openai-python/blob/e30ea96ca11ca6578ca38d3428594bd98d704900/src/fastapi_app/postgres_searcher.py#L2
  - https://supabase.com/docs/guides/ai/hybrid-search
  - https://github.com/toranb/rag-n-drop/blob/main/lib/demo/section.ex#L30

  Setup:
  1. Create a tsvector column in your table (postgres "generated" column recommended based on one or combo of text columns)
  2. Create a GIN index on the tsvector column
  3. Create a HNSW index on the vector column
  4. Generate embeddings for your documents and store them in the vector column (e.g. using BERT via Bumblebee or OpenAI's API)
  4. Generate embeddings for your search query and pass to query_embedding

  TODO: Implement additional vector distance functions (e.g. cosine similarity, euclidean distance) and tsquery options
  """
  import Ecto.Query
  import Pgvector.Ecto.Query

  @doc """
    Keyword Search

    Uses Postgres full-text search (tsvector) to find documents that match the query string keywords, ranked by relevance.
  """
  def keyword_search(schema, query_field, query_string, limit_by \\ 100, select_columns \\ [])
      when is_atom(query_field) and is_binary(query_string) do
    select_columns = build_select_columns(schema, select_columns)

    schema
    |> join(:inner, [s], q in fragment("websearch_to_tsquery('english', ?)", ^query_string),
      on: fragment("? @@ ?", field(s, ^query_field), q)
    )
    |> order_by([s, q], fragment("ts_rank_cd(?, ?) DESC", field(s, ^query_field), q))
    |> limit(^limit_by)
    |> select([s, q], %{
      id: s.id,
      rank: fragment("RANK() OVER (ORDER BY ts_rank_cd(?, ?) DESC)", field(s, ^query_field), q)
    })
    |> select_merge([t], map(t, ^select_columns))
  end

  @doc """
    Semantic Search

    Uses Postgres vector search (pg_vector) to find documents that are semantically similar to the query embedding, ranked by similarity.
  """
  def semantic_search(schema, query_field, query_embedding, limit_by \\ 100, select_columns \\ [])
      when is_atom(query_field) and is_list(query_embedding) do
    select_columns = build_select_columns(schema, select_columns)

    schema
    |> order_by([s], cosine_distance(field(s, ^query_field), ^query_embedding))
    |> limit(^limit_by)
    |> select([s], %{
      id: s.id,
      rank:
        fragment(
          "RANK() OVER (ORDER BY ?)",
          cosine_distance(field(s, ^query_field), ^query_embedding)
        )
    })
    |> select_merge([t], map(t, ^select_columns))
  end

  @doc """
    Postgres Hybrid Search

    Uses Reciprocal Rank Fusion (RRF) approach to combine full-text search and vector search.

    Assumes your primary key is "id", vector column is "embedding" and tsvector column is "content",
    but is flexible enough to work with any table / column name
  """
  def hybrid_search(schema, query_embedding, query_string, opts \\ []) do
    opts = Keyword.merge(hybrid_search_default_opts(), opts)
    max_limit = opts[:limit] * 2
    select_columns = build_select_columns(schema, opts[:select_columns])

    semantic_search_cte =
      semantic_search(schema, opts[:vector_column], query_embedding, max_limit, select_columns)

    keyword_search_cte =
      keyword_search(schema, opts[:tsvector_column], query_string, max_limit, select_columns)

    base_query =
      from(s in schema)
      |> with_cte("semantic_search", as: ^semantic_search_cte)
      |> join(:full, [s], vs in "semantic_search", on: vs.id == s.id)
      |> with_cte("keyword_search", as: ^keyword_search_cte)
      |> join(:full, [s, vs], ss in "keyword_search", on: ss.id == s.id)
      |> select([s, vs, ss], %{
        score:
          fragment(
            "(COALESCE(1.0 / (? + ?), 0.0) * ?) + (COALESCE(1.0 / (? + ?), 0.0) * ?)",
            ^opts[:rrf_k],
            vs.rank,
            ^opts[:vector_weight],
            ss.rank,
            ^opts[:rrf_k],
            ^opts[:tsvector_weight]
          ),
        id: coalesce(vs.id, ss.id)
      })
      |> select_merge([t, _t], map(t, ^select_columns))

    base_query
    |> subquery()
    |> order_by([bq], desc: bq.score)
    |> limit(^opts[:limit])
    |> select([bq], %{score: bq.score, id: bq.id})
    |> select_merge([t, _t], map(t, ^select_columns))
  end

  defp hybrid_search_default_opts do
    [
      rrf_k: 50,
      vector_column: :embedding,
      vector_weight: 1.0,
      tsvector_column: :content,
      tsvector_weight: 1.0,
      select_columns: [],
      limit: 100
    ]
  end

  defp build_select_columns(schema, []), do: schema.__schema__(:fields)
  defp build_select_columns(_schema, columns), do: columns
end
