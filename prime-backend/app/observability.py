"""Bounded, dependency-free runtime metrics for the modular monolith."""

from __future__ import annotations

from collections import defaultdict, deque
from threading import Lock

_MAX_ROUTE_SAMPLES = 2048
_lock = Lock()
_latencies: dict[str, deque[float]] = defaultdict(
    lambda: deque(maxlen=_MAX_ROUTE_SAMPLES)
)
_totals: dict[str, int] = defaultdict(int)
_errors: dict[str, int] = defaultdict(int)
_active_requests = 0


def request_started() -> None:
    global _active_requests
    with _lock:
        _active_requests += 1


def request_finished(
    *,
    method: str,
    route: str,
    status_code: int,
    elapsed_ms: float,
) -> None:
    global _active_requests
    key = f"{method.upper()} {route}"
    with _lock:
        _active_requests = max(0, _active_requests - 1)
        _totals[key] += 1
        if status_code >= 500:
            _errors[key] += 1
        _latencies[key].append(elapsed_ms)


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(
        len(ordered) - 1,
        max(0, round((len(ordered) - 1) * percentile)),
    )
    return round(ordered[index], 2)


def request_metrics_snapshot() -> dict:
    with _lock:
        route_names = sorted(_totals)
        active_requests = _active_requests
        routes = []
        for route_name in route_names:
            samples = list(_latencies[route_name])
            total = _totals[route_name]
            errors = _errors[route_name]
            routes.append(
                {
                    "route": route_name,
                    "total": total,
                    "errors_5xx": errors,
                    "error_rate": round(errors / total, 4) if total else 0.0,
                    "sample_size": len(samples),
                    "latency_ms": {
                        "p50": _percentile(samples, 0.50),
                        "p95": _percentile(samples, 0.95),
                        "p99": _percentile(samples, 0.99),
                        "max": round(max(samples), 2) if samples else 0.0,
                    },
                }
            )
    return {
        "active_requests": active_requests,
        "routes": routes,
        "sample_limit_per_route": _MAX_ROUTE_SAMPLES,
    }


def reset_request_metrics_for_test() -> None:
    global _active_requests
    with _lock:
        _active_requests = 0
        _latencies.clear()
        _totals.clear()
        _errors.clear()

