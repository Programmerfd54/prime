FROM python:3.13-slim

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

RUN mkdir -p /app/logs /app/uploads/private-media \
    && chown -R prime:prime /app

USER prime

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
