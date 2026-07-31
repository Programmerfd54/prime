FROM python:3.13.14-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system --gid 10001 prime \
    && adduser --system --uid 10001 --ingroup prime prime

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=prime:prime app ./app
COPY --chown=prime:prime migrations ./migrations
COPY --chown=prime:prime gunicorn.conf.py ./gunicorn.conf.py

RUN mkdir -p /app/logs /app/uploads/private-media \
    && chown -R prime:prime /app

USER prime

EXPOSE 8080

CMD ["sh", "-c", "exec gunicorn app.main:app -c gunicorn.conf.py -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8080 --workers ${WEB_CONCURRENCY:-2} --timeout ${GUNICORN_TIMEOUT:-90} --access-logfile - --error-logfile -"]
