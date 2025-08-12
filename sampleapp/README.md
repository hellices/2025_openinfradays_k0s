# Sample FastAPI CRUD App + GHCR

This adds a simple FastAPI CRUD API using an in-memory cache and a GitHub Actions workflow to build and push an OCI image to GHCR.

## API
- GET / -> service and version
- GET /healthz -> liveness
- GET /items -> list all items
- POST /items -> create item
- GET /items/{id} -> read item
- PUT /items/{id} -> replace item
- PATCH /items/{id} -> partial update
- DELETE /items/{id} -> delete

Payload example for create/update:
```json
{ "name": "foo", "description": "bar" }
```

## Local run
Use Python 3.12+.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r sampleapp/requirements.txt
uvicorn app.main:app --reload --port 8080 --app-dir sampleapp
```

Open http://localhost:8080/docs

## Build container locally
```bash
docker build -t sampleapp:dev .
docker run -p 8080:8080 sampleapp:dev
```

## GHCR publishing
Workflow `.github/workflows/ghcr.yml` builds on pushes to `main` and publishes to `ghcr.io/<owner>/<repo>` (multi-arch: amd64, arm64).
No extra secrets are needed; it uses the built-in `GITHUB_TOKEN`.

Image tags include branch, tag, sha, and `latest` on default branch.
