FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd -m appuser && chown -R appuser /app
USER appuser
CMD ["gunicorn", "--workers=1", "--threads=2", "--bind=0.0.0.0:5000", "app:app"]
