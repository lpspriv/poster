# Poster API

Go HTTP API for researching a topic, writing a post, and generating an image.

## Run locally

Set `OPENAI_API_KEY` and `SERPAPI_API_KEY` in the environment or a local `.env`
file, then run:

```sh
go run .
```

The API listens on port `8080` by default. Set `PORT` to change it.

## Endpoints

- `POST /api/v1/posts` accepts `{"topic":"..."}`. Topics must contain 1–500
  characters. The response includes the post and generated image path.
- `GET /POSTS/{filename}` returns a generated PNG image.
- `GET /healthz` returns `{"status":"ok"}`.

Generate a post locally:

```sh
curl -X POST http://localhost:8080/api/v1/posts \
  -H 'Content-Type: application/json' \
  -d '{"topic":"When should a team use Kubernetes in production?"}'
```

The Helm chart and public route are documented in [`chart/README.md`](../chart/README.md).
