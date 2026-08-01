import io

import pytest
from fastapi import UploadFile
from PIL import Image
from starlette.datastructures import Headers

from app.models import Group, GroupMember, User, utcnow
from app.routers import reports as reports_router
from tests.test_email_verification import make_session


def _jpeg() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (32, 32), color=(90, 30, 180)).save(output, format="JPEG")
    return output.getvalue()


@pytest.mark.asyncio
async def test_report_upload_records_report_scope(monkeypatch: pytest.MonkeyPatch) -> None:
    engine, session = await make_session()
    try:
        user = User(
            email="report-media@example.com",
            password_hash="hash",
            name="Report Media",
            nickname="report_media",
            profile_completed=True,
            email_verified_at=utcnow(),
        )
        group = Group(name="Media team", skill_id="focus", status="active")
        session.add_all([user, group])
        await session.flush()
        session.add(
            GroupMember(
                group_id=group.id,
                user_id=user.id,
                active=True,
                accepted_rules=True,
                confirmed_participation=True,
            )
        )
        await session.commit()

        captured: dict[str, str | None] = {}

        async def fake_ensure_matrix_user(current_user, _session):
            return current_user

        async def fake_upload_media(
            current_user,
            _session,
            filename,
            content_type,
            content,
            scope_type="owner",
            scope_id=None,
        ):
            assert current_user.id == user.id
            assert filename == "report.jpg"
            assert content_type == "image/jpeg"
            assert content
            captured["scope_type"] = scope_type
            captured["scope_id"] = scope_id
            return "s3://test/report.jpg"

        monkeypatch.setattr(
            reports_router,
            "ensure_matrix_user",
            fake_ensure_matrix_user,
        )
        monkeypatch.setattr(reports_router, "upload_media", fake_upload_media)

        upload = UploadFile(
            filename="report.jpg",
            file=io.BytesIO(_jpeg()),
            headers=Headers({"content-type": "image/jpeg"}),
        )
        result = await reports_router.report_upload_media(
            file=upload,
            group_id=group.id,
            request=None,
            user=user,
            session=session,
        )

        assert captured == {"scope_type": "report", "scope_id": group.id}
        assert result["storage_url"] == "s3://test/report.jpg"
    finally:
        await session.close()
        await engine.dispose()
