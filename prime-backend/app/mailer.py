"""Transactional email delivery over SMTP."""
from __future__ import annotations

import asyncio
import logging
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

from .config import Settings, get_settings

logger = logging.getLogger("prime.mailer")


def public_list_unsubscribe_url(url: str | None) -> str | None:
    """Skip List-Unsubscribe when the URL is not publicly reachable (hurts deliverability)."""
    if not url:
        return None
    lowered = url.lower()
    if "localhost" in lowered or "127.0.0.1" in lowered:
        return None
    return url


def _sender_address(settings: Settings) -> str:
    return (settings.mail_from or settings.smtp_username).strip()


def smtp_configured() -> bool:
    settings = get_settings()
    return bool(settings.smtp_host.strip() and _sender_address(settings))


def _build_message(
    *,
    to: str,
    subject: str,
    text_body: str,
    html_body: str | None,
    list_unsubscribe_url: str | None = None,
) -> EmailMessage:
    settings = get_settings()
    message = EmailMessage()
    message["From"] = formataddr((settings.mail_from_name, _sender_address(settings)))
    message["To"] = to
    message["Subject"] = subject
    reply_to = (settings.mail_reply_to or _sender_address(settings)).strip()
    if reply_to:
        message["Reply-To"] = reply_to
    if list_unsubscribe_url:
        message["List-Unsubscribe"] = f"<{list_unsubscribe_url}>"
        message["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    message.set_content(text_body)
    if html_body:
        message.add_alternative(html_body, subtype="html")
    return message


def _send_sync(message: EmailMessage) -> None:
    settings = get_settings()
    host = settings.smtp_host.strip()
    timeout = settings.smtp_timeout_seconds
    if settings.smtp_use_ssl:
        client: smtplib.SMTP = smtplib.SMTP_SSL(host, settings.smtp_port, timeout=timeout)
    else:
        client = smtplib.SMTP(host, settings.smtp_port, timeout=timeout)
    with client:
        client.ehlo()
        if settings.smtp_use_starttls and not settings.smtp_use_ssl:
            client.starttls()
            client.ehlo()
        if settings.smtp_username:
            client.login(settings.smtp_username, settings.smtp_password)
        client.send_message(message)


async def send_email(
    *,
    to: str,
    subject: str,
    text_body: str,
    html_body: str | None = None,
    list_unsubscribe_url: str | None = None,
) -> bool:
    """Send one email. Returns True only when SMTP accepted the message."""
    if not smtp_configured():
        logger.warning("smtp_not_configured", extra={"mail_subject": subject})
        return False
    message = _build_message(
        to=to,
        subject=subject,
        text_body=text_body,
        html_body=html_body,
        list_unsubscribe_url=list_unsubscribe_url,
    )
    try:
        await asyncio.to_thread(_send_sync, message)
    except Exception:
        logger.exception("email_send_failed", extra={"mail_subject": subject})
        return False
    logger.info("email_sent", extra={"mail_subject": subject})
    return True
