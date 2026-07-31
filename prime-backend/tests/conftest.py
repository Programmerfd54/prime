"""Shared pytest hooks for moderator-gated integration tests."""

from __future__ import annotations

import pytest

_MODERATOR_TEST_MODULES = {
    "test_authorization_matrix",
    "test_moderator_mfa",
    "test_moderation_appeals",
}


@pytest.fixture(autouse=True)
def _enable_moderator_features_in_moderator_tests(
    request: pytest.FixtureRequest,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    module_name = request.node.module.__name__.rsplit(".", 1)[-1]
    if module_name not in _MODERATOR_TEST_MODULES:
        return
    from app.config import get_settings

    monkeypatch.setattr(get_settings(), "moderator_features_enabled", True)
