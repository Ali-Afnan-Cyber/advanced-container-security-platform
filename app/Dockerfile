# Stage 1: Builder — install dependencies
FROM python:3.12.11-slim AS builder
# ^ python:3.12-slim: actively maintained, patched, minimal Debian
 
WORKDIR /app
 
# Copy requirements first (Docker layer cache optimisation)
COPY app/requirements.txt .
 
# Install into a prefix so we can copy cleanly
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt
 
# Stage 2: Runtime — minimal final image
FROM python:3.12.11-slim
 
# Security: Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -s /bin/false appuser
 
WORKDIR /app
 
# Copy only the installed packages from builder
COPY --from=builder /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=builder /usr/local/bin /usr/local/bin
 
# Copy application source
COPY app/ .
 
# Security: Set correct ownership
RUN chown -R appuser:appgroup /app
 
# Security: Switch to non-root user
USER appuser
 
# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"
 
EXPOSE 5000
 
CMD ["python3", "app.py"]
