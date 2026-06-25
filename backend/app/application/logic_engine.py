"""No-code logic engine.

Users author rules in plain language, e.g.::

    Condition: Hydrotest Complete AND Nitrogen Available
    Action:    Enable Leak Test

This module compiles the *condition* into a structured boolean tree (supporting
AND / OR / NOT, nesting with parentheses) and parses the *action* into a verb +
target. The tree is stored alongside the original plain text so nothing is lost,
and the API can convert simple "X Complete -> Enable Y" rules into Finish-to-Start
relationships. More complex constraint gating is recorded for Phase-2 solving.
"""

from __future__ import annotations

import re

# --- tokenizer ----------------------------------------------------------
_TOKEN_RE = re.compile(r"\(|\)|\bAND\b|\bOR\b|\bNOT\b", re.IGNORECASE)


def _tokenize(text: str) -> list[str]:
    tokens: list[str] = []
    pos = 0
    for m in _TOKEN_RE.finditer(text):
        if m.start() > pos:
            atom = text[pos : m.start()].strip()
            if atom:
                tokens.append(atom)
        tok = m.group()
        tokens.append("(" if tok == "(" else ")" if tok == ")" else tok.upper())
        pos = m.end()
    tail = text[pos:].strip()
    if tail:
        tokens.append(tail)
    return tokens


class _Parser:
    """Recursive-descent parser: OR < AND < NOT < atom/parens."""

    def __init__(self, tokens: list[str]):
        self.tokens = tokens
        self.i = 0

    def peek(self) -> str | None:
        return self.tokens[self.i] if self.i < len(self.tokens) else None

    def next(self) -> str | None:
        tok = self.peek()
        if tok is not None:
            self.i += 1
        return tok

    def parse(self) -> dict | None:
        if not self.tokens:
            return None
        return self._or()

    def _or(self) -> dict:
        node = self._and()
        children = [node]
        while self.peek() == "OR":
            self.next()
            children.append(self._and())
        return {"op": "OR", "children": children} if len(children) > 1 else node

    def _and(self) -> dict:
        node = self._not()
        children = [node]
        while self.peek() == "AND":
            self.next()
            children.append(self._not())
        return {"op": "AND", "children": children} if len(children) > 1 else node

    def _not(self) -> dict:
        if self.peek() == "NOT":
            self.next()
            return {"op": "NOT", "children": [self._not()]}
        return self._atom()

    def _atom(self) -> dict:
        tok = self.next()
        if tok == "(":
            node = self._or()
            if self.peek() == ")":
                self.next()
            return node
        return {"atom": (tok or "").strip()}


def parse_condition(condition: str) -> dict | None:
    """Compile a plain-language condition into a boolean tree."""
    return _Parser(_tokenize(condition)).parse()


_ACTION_VERBS = {
    "enable": ["enable", "allow", "then enable", "can start", "start", "permit"],
    "block": ["block", "prevent", "disallow", "hold"],
}


def parse_action(action: str) -> dict:
    """Parse a plain-language action into ``{"verb": ..., "target": ...}``."""
    text = action.strip()
    low = text.lower()
    for verb, kws in _ACTION_VERBS.items():
        for kw in kws:
            if low.startswith(kw):
                return {"verb": verb, "target": text[len(kw) :].strip(" :-")}
            if kw in low:
                idx = low.index(kw) + len(kw)
                return {"verb": verb, "target": text[idx:].strip(" :-")}
    return {"verb": "enable", "target": text}


def atoms_of(tree: dict | None) -> list[str]:
    """Collect the leaf atom strings of a condition tree (in order)."""
    if not tree:
        return []
    if "atom" in tree:
        return [tree["atom"]]
    out: list[str] = []
    for child in tree.get("children", []):
        out.extend(atoms_of(child))
    return out


def compile_rule(condition: str, action: str) -> dict:
    """Return the structured form of a rule (condition tree + parsed action)."""
    return {
        "condition": parse_condition(condition),
        "action": parse_action(action),
    }
