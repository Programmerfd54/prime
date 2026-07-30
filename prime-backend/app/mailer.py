"""Transactional email delivery over SMTP.

Delivery is best-effort: a mail outage must never break the request that
triggered it, so failures are logged and returned as False instead of raised.
Recipients are never written to the log.
"""
import asyncio
import logging
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

from .config import Settings, get_settings

logger = logging.getLogger("prime.mailer")

BRAND_PURPLE = "#8B5CF6"
BRAND_DEEP = "#6D28D9"


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
) -> EmailMessage:
    settings = get_settings()
    message = EmailMessage()
    message["From"] = formataddr((settings.mail_from_name, _sender_address(settings)))
    message["To"] = to
    message["Subject"] = subject
    reply_to = (settings.mail_reply_to or _sender_address(settings)).strip()
    if reply_to:
        message["Reply-To"] = reply_to
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
    )
    try:
        await asyncio.to_thread(_send_sync, message)
    except Exception:
        logger.exception("email_send_failed", extra={"mail_subject": subject})
        return False
    logger.info("email_sent", extra={"mail_subject": subject})
    return True


def build_verification_email(
    *,
    name: str,
    code: str,
    ttl_minutes: int,
) -> tuple[str, str, str]:
    """Returns (subject, text_body, html_body) for the signup confirmation."""
    greeting = f"{name}, здравствуйте!" if name.strip() else "Здравствуйте!"
    # Keep the subject static — putting the code in the subject triggers spam
    # filters and leaks it into lock-screen previews.
    subject = "Подтверждение регистрации в ПРАЙМ"
    text_body = (
        f"{greeting}\n\n"
        "Вы завершаете регистрацию в ПРАЙМ. Введите этот код в приложении, "
        "чтобы подтвердить, что почта принадлежит вам:\n\n"
        f"    {code}\n\n"
        f"Код действует {ttl_minutes} минут.\n\n"
        "Если вы не регистрировались в ПРАЙМ, просто удалите это письмо — "
        "без кода аккаунт активировать нельзя.\n"
    )
    spaced_code = " ".join(code)
    html_body = f"""<!doctype html>
<html lang="ru">
  <body style="margin:0;padding:24px;background:#F4F2F8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#1A1524;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background:#FFFFFF;border-radius:20px;overflow:hidden;">
      <tr>
        <td style="padding:28px 32px 8px 32px;">
          <div style="font-size:13px;letter-spacing:2px;text-transform:uppercase;color:{BRAND_DEEP};font-weight:600;">ПРАЙМ</div>
          <h1 style="margin:16px 0 8px 0;font-size:22px;line-height:1.3;">Подтвердите почту</h1>
          <p style="margin:0;font-size:15px;line-height:1.6;color:#5C5468;">
            {greeting} Осталось подтвердить, что эта почта принадлежит вам.
          </p>
        </td>
      </tr>
      <tr>
        <td style="padding:24px 32px;">
          <div style="background:{BRAND_PURPLE};border-radius:16px;padding:20px;text-align:center;">
            <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#FFFFFF;">{spaced_code}</div>
          </div>
          <p style="margin:16px 0 0 0;font-size:14px;line-height:1.6;color:#5C5468;">
            Код действует {ttl_minutes} минут. Введите его на шаге «Код» в приложении.
          </p>
        </td>
      </tr>
      <tr>
        <td style="padding:0 32px 28px 32px;">
          <p style="margin:0;font-size:13px;line-height:1.6;color:#7C6B96;">
            Если вы не регистрировались в ПРАЙМ, просто удалите это письмо —
            без кода аккаунт активировать нельзя.
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
"""
    return subject, text_body, html_body


def build_password_reset_email(
    *,
    name: str,
    token: str,
    ttl_minutes: int,
) -> tuple[str, str, str]:
    """Return a reset message; the raw token is delivered only by email."""
    greeting = f"{name}, здравствуйте!" if name.strip() else "Здравствуйте!"
    subject = "Восстановление пароля в ПРАЙМ"
    text_body = (
        f"{greeting}\n\n"
        "Мы получили запрос на смену пароля. Введите этот код в приложении:\n\n"
        f"{token}\n\n"
        f"Код действует {ttl_minutes} минут. Если запрос делали не вы, удалите письмо.\n"
    )
    html_body = f"""<!doctype html>
<html lang="ru"><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1A1524">
  <h2>Восстановление пароля</h2>
  <p>{greeting}</p>
  <p>Введите этот код в приложении:</p>
  <p style="font-size:20px;font-weight:700;letter-spacing:2px">{token}</p>
  <p>Код действует {ttl_minutes} минут.</p>
</body></html>"""
    return subject, text_body, html_body
