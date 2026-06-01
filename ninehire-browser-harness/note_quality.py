"""Shared validation for Ninehire team-chat notes.

The validator is intentionally conservative: it cannot prove a note is good, but it can
block the failure modes that made bulk keyword-generated notes look plausible enough to post.
"""

from __future__ import annotations

import re
from pathlib import Path


MAX_NOTE_CHARS = 1000

REQUIRED_LINES = (
    ("TLDR: ", 0),
    ("Estimated match: ", 1),
    ("- Evidence: ", 3),
    ("- Strengths: ", 4),
    ("- Gaps / follow-up: ", 5),
)

TEMPLATE_PHRASES = (
    "screen quality depends on depth behind the extracted projects",
    "relevant signals include",
    "extract cites",
    "general ui/ux execution",
    "ai, conversion/revenue",
    "mobile/app ux, ownership",
    "keyword scan",
    "keyword signal",
    "written evidence, with several jd/rubric signals present",
    "relevant ui/ux material found in attachments",
    "meets or likely meets the 3+ years ui/ux requirement",
    "portfolio/resume has some relevant ux/product signal",
    "human review still needed",
    "no strong keyword evidence found",
)

TEMPLATE_REGEXES = (
    re.compile(r"\b(?:signals?|keywords?)\s+(?:include|present|found|appears?)\b", re.I),
    re.compile(r"\b(?:business/revenue|conversion/revenue|research/data)\b", re.I),
    re.compile(r"\b(?:mobile/app UX|product/UIUX candidate)\b", re.I),
    re.compile(r"\b(?:depth behind|screen quality depends)\b", re.I),
    re.compile(r"\b(?:direct 1:1 matching/recommendation UX is not clearly shown)\b", re.I),
    re.compile(r"\b(?:paywall/subscription/premium-conversion UX is not clearly shown)\b", re.I),
    re.compile(r"\b(?:hypothesis/data-driven experimentation evidence is limited)\b", re.I),
)


def _nonempty_lines(note: str) -> list[str]:
    return note.strip().splitlines()


def validate_note_text(note: str) -> list[str]:
    """Return a list of blocking validation errors for one team-chat note."""
    errors: list[str] = []
    stripped = note.strip()
    lines = _nonempty_lines(note)

    if not stripped:
        return ["empty note"]
    if len(stripped) > MAX_NOTE_CHARS:
        errors.append(f"too long ({len(stripped)} > {MAX_NOTE_CHARS})")
    if len(lines) != 6:
        errors.append(f"expected exactly 6 lines, found {len(lines)}")

    for prefix, index in REQUIRED_LINES:
        if len(lines) <= index or not lines[index].startswith(prefix):
            errors.append(f"line {index + 1} must start with {prefix!r}")

    if len(lines) > 1:
        match = re.fullmatch(r"Estimated match: (\d{1,3})%", lines[1])
        if not match:
            errors.append("line 2 must be 'Estimated match: NN%'")
        elif not 0 <= int(match.group(1)) <= 100:
            errors.append("estimated match must be between 0 and 100")

    if len(lines) > 2 and lines[2].strip():
        errors.append("line 3 must be blank")

    lowered = stripped.lower()
    for phrase in TEMPLATE_PHRASES:
        if phrase in lowered:
            errors.append(f"generic/template phrase: {phrase}")

    for regex in TEMPLATE_REGEXES:
        if regex.search(stripped):
            errors.append(f"generic/template pattern: {regex.pattern}")

    if len(lines) > 3:
        evidence = lines[3].removeprefix("- Evidence: ").strip()
        if len(evidence) < 55:
            errors.append("evidence line is too thin to be grounded")
        if re.search(r"\b(?:extract|keyword|signals?)\b", evidence, re.I):
            errors.append("evidence line describes extraction/keywords instead of applicant work")
        if not re.search(r"[\d가-힣A-Za-z]{3,}", evidence):
            errors.append("evidence line lacks a concrete anchor")

    return errors


def validate_run_notes(run_dir: Path) -> list[dict[str, object]]:
    """Validate all note files under a run directory."""
    failures: list[dict[str, object]] = []
    seen_tldr: dict[str, Path] = {}

    for metadata_path in sorted(run_dir.glob("*/metadata.json")):
        folder = metadata_path.parent
        note_path = folder / "team_chat_note.txt"
        if not note_path.exists():
            failures.append({"folder": folder.name, "errors": ["missing team_chat_note.txt"]})
            continue

        note = note_path.read_text(encoding="utf-8").strip()
        errors = validate_note_text(note)
        lines = _nonempty_lines(note)
        if lines:
            tldr = lines[0].strip()
            if tldr in seen_tldr:
                errors.append(f"duplicate TLDR also used by {seen_tldr[tldr].parent.name}")
            else:
                seen_tldr[tldr] = note_path

        if errors:
            failures.append({"folder": folder.name, "path": str(note_path), "errors": errors})

    return failures
