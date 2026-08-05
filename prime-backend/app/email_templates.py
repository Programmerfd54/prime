"""Branded HTML + plain-text bodies for transactional mail."""
from __future__ import annotations

from html import escape

from .config import get_settings
from .email_unsubscribe import (
    LETTER_MARKETING,
    LETTER_PASSWORD_RESET,
    LETTER_SIGNUP_VERIFICATION,
    letter_label,
)

BRAND_PURPLE = "#8B5CF6"
BRAND_DEEP = "#6D28D9"
BRAND_MIST = "#F4F2F8"
INK = "#1A1524"
INK_MUTED = "#5C5468"
INK_SOFT = "#7C6B96"


def _support_contact_email() -> str:
    settings = get_settings()
    return (settings.mail_reply_to or settings.mail_from or settings.smtp_username).strip()


def _footer_lines(
    *,
    email: str,
    letter: str,
    transactional: bool,
    unsubscribe_url: str,
) -> tuple[str, str]:
    """Plain + HTML footer with marketing unsubscribe."""
    letter_name = letter_label(letter)
    support_email = _support_contact_email()
    if transactional:
        plain = (
            f"\n\n—\n"
            f"Это служебное письмо ({letter_name}). Его нельзя отключить, "
            f"пока вы завершаете действие в приложении.\n"
            f"От новостей и советов ПРАЙМ можно отписаться:\n{unsubscribe_url}\n"
            f"\nПРАЙМ · {support_email} · https://inpr1me.ru/privacy"
        )
        html = f"""
          <tr>
            <td style="padding:0 32px 24px 32px;border-top:1px solid #E8E4F0;">
              <p style="margin:0 0 12px 0;font-size:12px;line-height:1.6;color:{INK_SOFT};">
                Служебное письмо: {escape(letter_name)}. Без него нельзя завершить действие в приложении.
              </p>
              <p style="margin:0;font-size:12px;line-height:1.6;color:{INK_SOFT};">
                Не хотите получать новости и советы?
                <a href="{escape(unsubscribe_url)}" style="color:{BRAND_DEEP};text-decoration:underline;">
                  Отписаться от рассылки
                </a>
              </p>
            </td>
          </tr>"""
        return plain, html

    plain = (
        f"\n\n—\n"
        f"Вы получили это письмо, потому что подписаны на {letter_name}.\n"
        f"Отписаться: {unsubscribe_url}\n"
        f"\nПРАЙМ · {support_email} · https://inpr1me.ru/privacy"
    )
    html = f"""
          <tr>
            <td style="padding:0 32px 24px 32px;border-top:1px solid #E8E4F0;">
              <p style="margin:0;font-size:12px;line-height:1.6;color:{INK_SOFT};">
                <a href="{escape(unsubscribe_url)}" style="color:{BRAND_DEEP};text-decoration:underline;">
                  Отписаться от рассылки
                </a>
                · {escape(email)}
              </p>
            </td>
          </tr>"""
    return plain, html


def _wrap_html(*, preheader: str, body_rows: str, footer_html: str) -> str:
    return f"""<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <meta name="color-scheme" content="light"/>
    <title>ПРАЙМ</title>
  </head>
  <body style="margin:0;padding:24px 12px;background:{BRAND_MIST};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:{INK};">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">{escape(preheader)}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:0 auto;">
      <tr>
        <td style="padding:0 0 16px 0;text-align:center;">
          <div style="display:inline-block;padding:10px 18px;border-radius:999px;background:linear-gradient(135deg,{BRAND_PURPLE},{BRAND_DEEP});color:#FFFFFF;font-size:12px;font-weight:700;letter-spacing:2px;">ПРАЙМ</div>
        </td>
      </tr>
      <tr>
        <td>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FFFFFF;border-radius:24px;overflow:hidden;box-shadow:0 12px 40px rgba(109,40,217,0.08);">
            {body_rows}
            {footer_html}
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>"""


def build_verification_email(
    *,
    name: str,
    code: str,
    ttl_minutes: int,
    email: str,
    unsubscribe_url: str,
) -> tuple[str, str, str, str | None]:
    """Returns subject, text, html, list-unsubscribe URL."""
    greeting = f"{name}, здравствуйте!" if name.strip() else "Здравствуйте!"
    subject = "Подтверждение регистрации в ПРАЙМ"
    spaced_code = " ".join(code)
    footer_plain, footer_html = _footer_lines(
        email=email,
        letter=LETTER_SIGNUP_VERIFICATION,
        transactional=True,
        unsubscribe_url=unsubscribe_url,
    )
    text_body = (
        f"{greeting}\n\n"
        "Вы почти в команде! Остался один шаг — подтвердить, что эта почта ваша.\n\n"
        f"Код для приложения: {code}\n\n"
        "Как ввести код:\n"
        "1. Откройте приложение ПРАЙМ\n"
        "2. На шаге «Код» введите 6 цифр из письма\n"
        "3. Нажмите «Подтвердить»\n\n"
        f"Код действует {ttl_minutes} минут. Если время вышло — запросите новый код в приложении.\n\n"
        "Если вы не регистрировались, просто удалите письмо — без кода аккаунт не активируется."
        f"{footer_plain}"
    )
    body_rows = f"""
            <tr>
              <td style="padding:32px 32px 8px 32px;">
                <h1 style="margin:0 0 12px 0;font-size:26px;line-height:1.25;color:{INK};">Подтвердите почту</h1>
                <p style="margin:0;font-size:16px;line-height:1.65;color:{INK_MUTED};">
                  {escape(greeting)} Вы на финишной прямой регистрации в ПРАЙМ.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 8px 32px;">
                <div style="background:linear-gradient(135deg,{BRAND_PURPLE},{BRAND_DEEP});border-radius:18px;padding:24px;text-align:center;">
                  <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;color:rgba(255,255,255,0.82);margin-bottom:8px;">Ваш код</div>
                  <div style="font-size:28px;font-weight:800;letter-spacing:6px;color:#FFFFFF;white-space:nowrap;word-break:keep-all;">{spaced_code}</div>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 8px 32px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{BRAND_MIST};border-radius:16px;">
                  <tr>
                    <td style="padding:18px 20px;font-size:14px;line-height:1.7;color:{INK_MUTED};">
                      <strong style="color:{INK};">Как подтвердить:</strong><br/>
                      1. Откройте приложение ПРАЙМ<br/>
                      2. На шаге «Код» введите 6 цифр<br/>
                      3. Нажмите «Подтвердить»
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 24px 32px;">
                <p style="margin:0;font-size:14px;line-height:1.65;color:{INK_MUTED};">
                  Код действует <strong>{ttl_minutes} мин</strong>. Не пришло письмо — проверьте «Спам»
                  или запросите новый код в приложении.
                </p>
              </td>
            </tr>"""
    html_body = _wrap_html(
        preheader=f"Код подтверждения для завершения регистрации. Действует {ttl_minutes} минут.",
        body_rows=body_rows,
        footer_html=footer_html,
    )
    return subject, text_body, html_body, unsubscribe_url


def build_password_reset_email(
    *,
    name: str,
    code: str,
    ttl_minutes: int,
    email: str,
    unsubscribe_url: str,
) -> tuple[str, str, str, str | None]:
    greeting = f"{name}, здравствуйте!" if name.strip() else "Здравствуйте!"
    subject = "Восстановление пароля в ПРАЙМ"
    spaced_code = " ".join(code)
    footer_plain, footer_html = _footer_lines(
        email=email,
        letter=LETTER_PASSWORD_RESET,
        transactional=True,
        unsubscribe_url=unsubscribe_url,
    )
    text_body = (
        f"{greeting}\n\n"
        "Мы получили запрос на смену пароля в ПРАЙМ.\n\n"
        f"Код для приложения: {code}\n\n"
        "Как ввести код:\n"
        "1. Откройте приложение ПРАЙМ\n"
        "2. На экране «Код восстановления» введите 6 цифр из письма\n"
        "3. Нажмите «Подтвердить» и задайте новый пароль\n\n"
        f"Код действует {ttl_minutes} минут. Если вы не запрашивали смену пароля, просто удалите это письмо."
        f"{footer_plain}"
    )
    body_rows = f"""
            <tr>
              <td style="padding:32px 32px 8px 32px;">
                <h1 style="margin:0 0 12px 0;font-size:26px;line-height:1.25;color:{INK};">Смена пароля</h1>
                <p style="margin:0;font-size:16px;line-height:1.65;color:{INK_MUTED};">
                  {escape(greeting)} Используйте код ниже в приложении ПРАЙМ.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 8px 32px;">
                <div style="background:linear-gradient(135deg,{BRAND_PURPLE},{BRAND_DEEP});border-radius:18px;padding:24px;text-align:center;">
                  <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;color:rgba(255,255,255,0.82);margin-bottom:8px;">Код восстановления</div>
                  <div style="font-size:28px;font-weight:800;letter-spacing:6px;color:#FFFFFF;white-space:nowrap;word-break:keep-all;">{spaced_code}</div>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 8px 32px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{BRAND_MIST};border-radius:16px;">
                  <tr>
                    <td style="padding:18px 20px;font-size:14px;line-height:1.7;color:{INK_MUTED};">
                      <strong style="color:{INK};">Как восстановить пароль:</strong><br/>
                      1. Откройте приложение ПРАЙМ<br/>
                      2. Введите 6 цифр из письма<br/>
                      3. Подтвердите код и задайте новый пароль
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 24px 32px;">
                <p style="margin:0;font-size:14px;line-height:1.65;color:{INK_MUTED};">
                  Код действует {ttl_minutes} мин. Если запрос делали не вы — удалите письмо.
                </p>
              </td>
            </tr>"""
    html_body = _wrap_html(
        preheader="Код для восстановления пароля в ПРАЙМ.",
        body_rows=body_rows,
        footer_html=footer_html,
    )
    return subject, text_body, html_body, unsubscribe_url
