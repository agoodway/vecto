# Vecto

Hybrid Search with Postgres and Ecto

Loosely based on:

- https://github.com/pgvector/pgvector-python/blob/master/examples/hybrid_search_rrf.py
- https://github.com/Azure-Samples/rag-postgres-openai-python/blob/e30ea96ca11ca6578ca38d3428594bd98d704900/src/fastapi_app/postgres_searcher.py#L2
- https://www.assembled.com/blog/better-rag-results-with-reciprocal-rank-fusion-and-hybrid-search
- https://supabase.com/docs/guides/ai/hybrid-search
- https://github.com/toranb/rag-n-drop/blob/main/lib/demo/section.ex#L30

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vecto, "~> 0.1.3"}
  ]
end
```

## Setup

1. Install [pgvector](https://github.com/pgvector/pgvector?tab=readme-ov-file#installation)
2. Create a tsvector column in your table (postgres "generated" column recommended based on one or combo of text columns)
3. Create a GIN index on the tsvector column
4. Create a HNSW Cosine distance [index](https://github.com/pgvector/pgvector?tab=readme-ov-file#hnsw) on the vector column
5. Generate embeddings for your documents and store them in the vector column (e.g. using BERT via [Bumblebee](https://github.com/elixir-nx/bumblebee), OpenAI's API, etc)
6. Generate embeddings for your search query and pass to query_embedding

In your migrations (assuming you're using Ecto migrations):

```elixir
  # set up pgvector
  execute "CREATE EXTENSION IF NOT EXISTS vector"

  # on your table

  ## vector column
  add :embedding, :vector, size: 384 # depends on your embedding model

  ## generated full text column, could be combination of several text columns
  execute("""
    ALTER TABLE post
    ADD COLUMN content tsvector GENERATED ALWAYS AS (to_tsvector('english', content)) STORED
  """)

  execute """
    CREATE INDEX content_tsvector_idx ON post USING GIN (content)
  """

  execute """
    CREATE INDEX embedding_index ON post USING hnsw (embedding vector_cosine_ops);
  """
```

### Indexes

#### HNSW

HNSW index has limitation of 2000 dimensions so in case you use OpenAI's API embeddings you need to reduce the dimensionality of the embeddings. You can do it in API call, for example:

```elixir
OpenAI.embeddings(model: "text-embedding-3-large", input: text, dimensions: 2_000)
```

Another important information is that HNSW index limit results with `hnsw.ef_search` parameter. Default value can be low for some cases, so you can increase it in the query:

In your migrations:

```elixir
# for current transaction (not persistent)
execute """
  SET hnsw.ef_search = 100;
"""
# for session (not persistent)
execute """
  SET LOCAL hnsw.ef_search = 100;
"""
# alter server configuration (you have to have permissions)
execute """
  ALTER SYSTEM SET hnsw.ef_search = 100;
"""
# for database (persistent)
execute """
  ALTER DATABASE your_database_name SET hnsw.ef_search = 100;
"""
```

## Usage

```elixir
Blog
|> Vecto.hybrid_search(Pgvector.new([0.11, 0.03, -0.02, ...]), "what is a cat")
|> where([b], b.user_id == ^23)
|> Repo.all()
```

You can also use the keyword_search and semantic_search functions as stand-alone queries

### TODO

- Tests...
- Implement additional [vector operators](https://github.com/pgvector/pgvector?tab=readme-ov-file#vector-operators) (e.g. euclidean distance, negative inner product, etc)
- Allow for different tsquery options.

Docs can be found at <https://hexdocs.pm/vecto>
