"""Branded HTML landing pages for email unsubscribe."""
from __future__ import annotations

from html import escape

from .email_unsubscribe import letter_label

BRAND_PURPLE = "#8B5CF6"
BRAND_DEEP = "#6D28D9"
BRAND_MIST = "#F4F2F8"
INK = "#1A1524"
INK_MUTED = "#5C5468"
INK_SOFT = "#7C6B96"


def _page_shell(
    *,
    title: str,
    eyebrow: str,
    heading: str,
    body: str,
    meta: str = "",
    note: str = "",
    accent: str = BRAND_DEEP,
    icon: str = "✉️",
) -> str:
    meta_block = (
        f'<p class="meta">{meta}</p>'
        if meta
        else ""
    )
    note_block = (
        f'<p class="note">{note}</p>'
        if note
        else ""
    )
    return f"""<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <meta name="robots" content="noindex, nofollow"/>
    <title>{escape(title)} · ПРАЙМ</title>
    <style>
      :root {{
        --brand-purple: {BRAND_PURPLE};
        --brand-deep: {BRAND_DEEP};
        --brand-mist: {BRAND_MIST};
        --ink: {INK};
        --ink-muted: {INK_MUTED};
        --ink-soft: {INK_SOFT};
        --accent: {accent};
      }}
      * {{ box-sizing: border-box; }}
      body {{
        margin: 0;
        min-height: 100vh;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at 12% 18%, rgba(139, 92, 246, 0.18), transparent 34%),
          radial-gradient(circle at 88% 12%, rgba(109, 40, 217, 0.12), transparent 28%),
          linear-gradient(180deg, #FAF8FD 0%, var(--brand-mist) 100%);
        padding: 32px 16px 48px;
      }}
      .shell {{
        max-width: 560px;
        margin: 0 auto;
      }}
      .brand {{
        display: inline-flex;
        align-items: center;
        gap: 10px;
        margin-bottom: 18px;
        color: var(--brand-deep);
        font-size: 12px;
        font-weight: 800;
        letter-spacing: 2.4px;
        text-transform: uppercase;
      }}
      .brand-dot {{
        width: 10px;
        height: 10px;
        border-radius: 999px;
        background: linear-gradient(135deg, var(--brand-purple), var(--brand-deep));
        box-shadow: 0 0 0 6px rgba(139, 92, 246, 0.12);
      }}
      .card {{
        background: rgba(255, 255, 255, 0.92);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(109, 40, 217, 0.08);
        border-radius: 28px;
        padding: 34px 30px 30px;
        box-shadow:
          0 24px 60px rgba(109, 40, 217, 0.10),
          0 2px 0 rgba(255, 255, 255, 0.7) inset;
        animation: rise 420ms ease-out both;
      }}
      @keyframes rise {{
        from {{ opacity: 0; transform: translateY(10px); }}
        to {{ opacity: 1; transform: translateY(0); }}
      }}
      .icon {{
        width: 64px;
        height: 64px;
        border-radius: 20px;
        display: grid;
        place-items: center;
        font-size: 28px;
        background: linear-gradient(135deg, rgba(139, 92, 246, 0.16), rgba(109, 40, 217, 0.10));
        border: 1px solid rgba(109, 40, 217, 0.10);
        margin-bottom: 18px;
      }}
      .eyebrow {{
        margin: 0 0 8px;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 1.4px;
        text-transform: uppercase;
        color: var(--accent);
      }}
      h1 {{
        margin: 0 0 14px;
        font-size: clamp(28px, 5vw, 34px);
        line-height: 1.15;
        letter-spacing: -0.02em;
      }}
      .lead {{
        margin: 0;
        font-size: 16px;
        line-height: 1.7;
        color: var(--ink-muted);
      }}
      .note {{
        margin: 22px 0 0;
        padding: 16px 18px;
        border-radius: 18px;
        background: var(--brand-mist);
        color: var(--ink-soft);
        font-size: 14px;
        line-height: 1.65;
      }}
      .meta {{
        margin: 22px 0 0;
        padding-top: 18px;
        border-top: 1px solid rgba(109, 40, 217, 0.08);
        font-size: 13px;
        line-height: 1.7;
        color: var(--ink-soft);
      }}
      .footer {{
        margin-top: 18px;
        text-align: center;
        font-size: 12px;
        color: var(--ink-soft);
      }}
      .footer a {{
        color: var(--brand-deep);
        text-decoration: none;
      }}
      .footer a:hover {{
        text-decoration: underline;
      }}
    </style>
  </head>
  <body>
    <div class="shell">
      <div class="brand"><span class="brand-dot"></span> ПРАЙМ</div>
      <div class="card">
        <div class="icon" aria-hidden="true">{icon}</div>
        <p class="eyebrow">{escape(eyebrow)}</p>
        <h1>{escape(heading)}</h1>
        <p class="lead">{body}</p>
        {meta_block}
        {note_block}
      </div>
      <p class="footer">
        <a href="https://inpr1me.ru/privacy">Политика конфиденциальности</a>
      </p>
    </div>
  </body>
</html>"""


def success_page(*, email: str, letter: str) -> str:
    letter_name = letter_label(letter)
    return _page_shell(
        title="Вы отписались",
        eyebrow="Рассылка",
        heading="Вы отписались от рассылки",
        body=(
            "Жаль, что вы уходите — но мы уважаем ваш выбор. "
            "Больше не будем присылать новости, советы и подборки от ПРАЙМ на эту почту."
        ),
        meta=(
            f"Почта: {escape(email)}<br/>"
            f"Письмо: {escape(letter_name)}"
        ),
        note=(
            "Служебные письма — подтверждение входа, безопасность — "
            "могут приходить, когда это необходимо."
        ),
        accent=BRAND_DEEP,
        icon="💜",
    )


def already_unsubscribed_page(*, email: str) -> str:
    return _page_shell(
        title="Уже отписаны",
        eyebrow="Рассылка",
        heading="Вы уже отписаны от рассылки",
        body=(
            "Вы уже отказались от новостей и советов ПРАЙМ — повторно ничего делать не нужно. "
            "Если передумали, подписку можно включить в настройках профиля в приложении."
        ),
        meta=f"Почта: {escape(email)}",
        note=(
            "Служебные письма — подтверждение входа, безопасность — "
            "могут приходить, когда это необходимо."
        ),
        accent=INK_SOFT,
        icon="✓",
    )


def expired_page() -> str:
    return _page_shell(
        title="Ссылка устарела",
        eyebrow="Рассылка",
        heading="Ссылка больше не действует",
        body=(
            "Срок действия ссылки истёк. Если хотите отписаться от рассылки, "
            "откройте любое свежее письмо от ПРАЙМ или напишите нам — поможем."
        ),
        accent="#B45309",
        icon="⏳",
    )


def invalid_page() -> str:
    return _page_shell(
        title="Ссылка недействительна",
        eyebrow="Рассылка",
        heading="Не удалось обработать ссылку",
        body=(
            "Ссылка повреждена или уже использована. "
            "Попробуйте открыть её из последнего письма от ПРАЙМ."
        ),
        accent="#BE123C",
        icon="!",
    )
