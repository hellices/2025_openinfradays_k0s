# syntax=docker/dockerfile:1

FROM python:3.12-slim as base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_NO_CACHE_DIR=on

WORKDIR /app

# Install uv and Python deps first for caching
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"
COPY requirements.txt /app/requirements.txt
RUN uv pip install --system -r requirements.txt

# Copy source
COPY app /app/app
COPY README-GHCR.md /README.md

# OCI labels (overridden/refined by metadata-action at build time)
LABEL org.opencontainers.image.title="2025_openinfradays_k0s sampleapp (FluxCD demo)" \
    org.opencontainers.image.description="FastAPI CRUD sample for FluxCD practice (in-memory)" \
    org.opencontainers.image.url="https://github.com/hellices/2025_openinfradays_k0s" \
    org.opencontainers.image.source="https://github.com/hellices/2025_openinfradays_k0s" \
    org.opencontainers.image.documentation="https://github.com/hellices/2025_openinfradays_k0s/blob/main/sampleapp/README-GHCR.md"

EXPOSE 8080

# Default to uvicorn server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
