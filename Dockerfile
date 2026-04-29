# Stage 1: Builder
FROM python:3.12-slim AS builder

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime — minimal, non-root
FROM python:3.12-slim

RUN groupadd -r appgroup && \
    useradd -r -g appgroup -s /bin/false appuser

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=builder /usr/local/bin /usr/local/bin

COPY app/ .

RUN chown -R appuser:appgroup /app

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

EXPOSE 5000

CMD ["python3", "app.py"]
