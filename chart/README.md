# Poster Helm chart

Deploys the Poster Go API in the `posterapi` namespace. The optional Nginx
test frontend is disabled by default (`nginx.enabled: false`).

## Public route

The Ingress serves `https://api.lpspriv.com/poster`. Traefik removes the
`/poster` prefix and forwards requests to the API Service on port `8080`.
Traefik Basic Auth protects API and image requests using the `poster-api-auth`
Secret in `posterapi`; its `users` key contains `htpasswd`-formatted password
hashes.

The chart allows CORS from `https://lpspriv.com` and
`https://www.lpspriv.com` for browser requests from the website.

## Flux-managed resources

Flux creates the `posterapi` namespace and the TLS Secret
`api-lpspriv-com-tls`. The Certificate must cover `api.lpspriv.com` and use the
production Hetzner DNS-01 ClusterIssuer. The public DNS record for
`api.lpspriv.com` must point to Traefik.

The chart does not create the namespace, Certificate, registry pull Secret, or
API authentication Secret. Ansible generates the `regcred` SealedSecret for
the private registry. Create `poster-api-auth` and the API credential Secret
before exposing the route. The API credential Secret needs `OPENAI_API_KEY`
and `SERPAPI_API_KEY`.

## API

The API listens on port `8080` inside the cluster:

- `POST /api/v1/posts` accepts JSON `{"topic":"..."}` and returns the
  generated post and image path.
- `GET /POSTS/{filename}` returns a generated image.
- `GET /healthz` is the Kubernetes health endpoint.

The Ingress adds `/poster` to these paths externally. For example, submit to
`https://api.lpspriv.com/poster/api/v1/posts`.
