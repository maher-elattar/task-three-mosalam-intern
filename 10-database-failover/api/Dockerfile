# Small sample API image.
# The API is intentionally simple; the DevOps behavior is in Docker Compose,
# Traefik, Redis, MySQL, logging, monitoring, and backup wiring.
FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies are pinned for repeatable builds.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8000

# One worker keeps request metrics deterministic for this lab.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "8", "--access-logfile", "-", "--error-logfile", "-", "app:app"]

