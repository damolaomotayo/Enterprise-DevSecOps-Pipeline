FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Patch OS packages so the image scan starts clean.
# hadolint ignore=DL3005
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

# Numeric non-root user (Kubernetes runAsNonRoot needs a numeric ID).
RUN useradd --system --uid 10001 --no-create-home appuser
USER 10001

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]
CMD ["gunicorn", "--bind", ":8080", "--workers", "2", "--worker-tmp-dir", "/dev/shm", "app:app"]
