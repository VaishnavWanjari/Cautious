"""Anthropic Claude assistant wrapper.

Wired to the Claude API for the natural-language scheduling assistant. The app
is offline-first: when no API key is configured (or the SDK/network is
unavailable) the assistant returns a clear, helpful message and the rest of the
application keeps working. The current project's schedule summary is passed as
context so answers are grounded in the user's data.
"""

from __future__ import annotations

import json

from ...config import get_settings

_SYSTEM_PROMPT = (
    "You are the scheduling assistant inside Commissioning Scheduler Pro, an EPC "
    "pre-commissioning and commissioning planning tool for Oil & Gas / LNG / "
    "Refinery projects. Answer concisely and practically. Use the provided "
    "project schedule JSON to ground your answers about the critical path, "
    "float, durations, startup risks and sequencing. When asked to optimise, "
    "suggest concrete logic or duration changes."
)

_OFFLINE_MSG = (
    "AI assistant is unavailable offline. Set the ANTHROPIC_API_KEY environment "
    "variable (and ensure the `anthropic` package is installed) to enable it. "
    "All scheduling, network, Gantt and export features work without it."
)


def is_available() -> bool:
    return get_settings().has_ai


def ask(message: str, context: dict) -> tuple[str, bool]:
    """Return ``(reply, ai_available)``."""
    settings = get_settings()
    if not settings.has_ai:
        return _OFFLINE_MSG, False

    try:
        import anthropic  # imported lazily so the app runs without the dependency
    except ImportError:
        return (
            "The `anthropic` package is not installed. Run `pip install anthropic` "
            "to enable the AI assistant.",
            False,
        )

    try:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        ctx = json.dumps(context, default=str)[:12000]
        resp = client.messages.create(
            model=settings.anthropic_model,
            max_tokens=1024,
            system=_SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": f"Project schedule context:\n{ctx}\n\nQuestion: {message}",
                }
            ],
        )
        parts = [blk.text for blk in resp.content if getattr(blk, "type", "") == "text"]
        return ("\n".join(parts).strip() or "(no response)", True)
    except Exception as exc:  # network/auth/etc. — stay graceful
        return (f"AI request failed: {exc}", True)
