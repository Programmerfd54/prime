"""Gunicorn lifecycle hooks for the PRIME API."""


def worker_abort(worker):
    worker.log.warning("worker aborted", extra={"pid": worker.pid})
