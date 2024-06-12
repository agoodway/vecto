# Vecto

Full-Text Search, Vector Search and Hybrid Search with Postgres and Ecto

Loosely based on:
- https://github.com/pgvector/pgvector-python/blob/master/examples/hybrid_search_rrf.py
- https://github.com/Azure-Samples/rag-postgres-openai-python/blob/e30ea96ca11ca6578ca38d3428594bd98d704900/src/fastapi_app/postgres_searcher.py#L2
- https://supabase.com/docs/guides/ai/hybrid-search
- https://github.com/toranb/rag-n-drop/blob/main/lib/demo/section.ex#L30

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vecto, "~> 0.1.0"}
  ]
end
```

## Setup

1. Create a tsvector column in your table (postgres "generated" column recommended based on one or combo of text columns)
2. Create a GIN index on the tsvector column
3. Create a HNSW index on the vector column
4. Generate embeddings for your documents and store them in the vector column (e.g. using BERT via Bumblebee or OpenAI's API)
4. Generate embeddings for your search query and pass to query_embedding

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/vecto>.

