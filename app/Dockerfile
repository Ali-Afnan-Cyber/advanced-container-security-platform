# ==========================
# Stage 1 - Builder
# ==========================
FROM cgr.dev/chainguard/python:latest-dev AS builder

WORKDIR /app

# Create virtual environment
RUN python -m venv /venv

ENV PATH="/venv/bin:$PATH"

# Copy dependency list first
COPY app/requirements.txt .

# Install dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ .

# ==========================
# Stage 2 - Runtime
# ==========================
FROM cgr.dev/chainguard/python:latest

WORKDIR /app

ENV PATH="/venv/bin:$PATH"

# Copy virtual environment
COPY --from=builder /venv /venv

# Copy application
COPY --from=builder /app /app

# Chainguard images already run as a non-root user.
# No need for useradd, groupadd or chown.

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
