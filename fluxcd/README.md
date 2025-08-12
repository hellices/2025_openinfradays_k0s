# FluxCD bootstrap for k0s

Apply bootstrap after installing Flux CLI and CRDs on the cluster:

```bash
# Install flux on the cluster (once)
flux install

# Create namespace for flux-system if missing
kubectl create ns flux-system --dry-run=client -o yaml | kubectl apply -f -

# Apply the bootstrap objects
kubectl apply -f fluxcd/bootstrap/flux-bootstrap.yaml

# Verify sources and kustomizations
kubectl -n flux-system get ocirepositories,kustomizations
```

Notes
- OCIRepository points to ghcr.io/hellices/2025_openinfradays_k0s-manifests:latest
- Kustomization reconciles path ./app from the extracted OCI artifact
- Workflow will republish the OCI artifact on every push, and Flux will reconcile when the OCI digest changes.
