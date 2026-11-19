# Poster Helm chart

This chart deploys the Poster Go API and Nginx web frontend, and creates a
Kubernetes Secret for `OPENAI_API_KEY` and `SERPAPI_API_KEY`. It expects both
images to be built and published; the chart does not build images.

## Install

Build and publish both images, then install the chart with their image
references and API keys:

```sh
docker buildx build --platform linux/amd64 -t registry.example.com/poster-api:0.1.0 --push poster
docker buildx build --platform linux/amd64 -f nginx/Dockerfile -t registry.example.com/nginx:0.1.0 --push .

helm upgrade --install poster ./chart \
  --set image.repository=registry.example.com \
  --set image.tag=0.1.0 \
  --set nginx.image.repository=registry.example.com \
  --set nginx.image.tag=0.1.0 \
  --set-string secret.openaiApiKey='YOUR_OPENAI_API_KEY' \
  --set-string secret.serpApiKey='YOUR_SERPAPI_API_KEY'
```

## Build and publish the Poster API image

Commit the Poster source changes, then set `REGISTRY_PASSWORD` from your CI
secret store and run `poster/ci.sh` from the repository root. The script builds
and pushes `registry.lpspriv.com:5000/poster-api` tagged with the full Git
commit SHA.

To deploy that image with Flux, set `image.repository` to
`registry.lpspriv.com:5000` and `image.tag` to the same commit SHA in the
Poster `HelmRelease` values in the Flux GitOps repository. The script publishes
the API image only; build and publish the Nginx image separately if it changes.

For production, avoid passing credentials on the command line. Create a Secret
separately and set `secret.existingSecret` to its name. The Secret must contain
keys named `OPENAI_API_KEY` and `SERPAPI_API_KEY`.

The Nginx Service is the frontend entry point (ClusterIP by default); configure
`nginx.service.type` as `LoadBalancer` or `NodePort` when appropriate. Nginx
proxies `/api/` to the internal Go API Service. The chart also creates a private
Traefik route at `https://api2.lpspriv.com/poster/`; Traefik strips `/poster`
before forwarding to the Go API service and allows only RFC1918 client
addresses. Its TLS Secret is issued by cert-manager. Image pull secrets,
resource requests and limits, pod labels and annotations, node selectors,
affinity, and tolerations can be configured in `values.yaml`.

The route requires the `letsencrypt-hetzner` ClusterIssuer, installed from the
`flux_gitops` repository, and a Hetzner DNS API token Secret named `hetzner` in
the `cert-manager` namespace. Keep the token out of Git; create it in the
cluster before expecting the certificate to become Ready:

```sh
kubectl create secret generic hetzner \
  --namespace cert-manager \
  --from-literal=token="$HETZNER_DNS_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Configure internal DNS so `api2.lpspriv.com` resolves to the cluster node's
private address. Do not publish a public DNS record for this hostname. Also
restrict inbound access to Traefik's HTTPS NodePort (30443) to private networks
in the Hetzner firewall; the Traefik middleware provides an additional
RFC1918 source-address check.

## API

The API listens internally on port 8080. The frontend is served by Nginx on
port 80, which also proxies API requests. Submit a JSON object with a `topic`
string to `POST /api/v1/posts`:

```sh
curl -X POST http://localhost:8080/api/v1/posts \
  -H 'Content-Type: application/json' \
  -d '{"topic":"When should a team use Kubernetes in production?"}'
```

The topic is whitespace-normalized, must contain 1 to 500 Unicode characters,
and may not contain control characters. The API returns the normalized topic,
generated post, and image path as JSON. `GET /healthz` is used by Kubernetes
probes.

Generated files are written to the container's local `POSTS` directory and are
persisted across pod restarts by a 5 Gi PersistentVolumeClaim mounted at
`/app/POSTS`. Set `persistence.size`, `persistence.accessModes`, or
`persistence.storageClassName` in `values.yaml` to match the cluster's storage
provisioner.

```
  flux reconcile kustomization flux-system -n flux-system --with-source
```
