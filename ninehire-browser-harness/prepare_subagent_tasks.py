"""Prepare isolated STAGE 2 task prompts: one applicant, one subagent, one note.

Usage:
    NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
        python3 ninehire-browser-harness/prepare_subagent_tasks.py
"""

from __future__ import annotations

import json
import os
from pathlib import Path


HARNESS_ROOT = Path("ninehire-browser-harness")
if not HARNESS_ROOT.exists():
    HARNESS_ROOT = Path(".")


def attachment_paths(folder: Path) -> list[Path]:
    cleaned = sorted(folder.glob("attachment_*.cleaned.txt"))
    raw_text = sorted(folder.glob("attachment_*.txt"))
    pdfs = sorted(folder.glob("attachment_*.pdf"))
    paths: list[Path] = []
    paths.extend(cleaned)
    paths.extend(path for path in raw_text if path not in paths)
    paths.extend(path for path in pdfs if path not in paths)
    return paths


def task_text(folder: Path, metadata: dict[str, object], attachments: list[Path]) -> str:
    applicant = str(metadata.get("applicant") or folder.name)
    note_path = folder / "team_chat_note.txt"
    image_only = bool(metadata.get("any_image_only_pdf") or metadata.get("image_only_pdf"))
    attachment_lines = "\n".join(f"- `{path}`" for path in attachments) or "- No attachment files found."
    image_instruction = (
        "\nThe metadata says one or more PDFs are image-only. Inspect the PDF pages visually; "
        "do not evaluate from empty extracted text.\n"
        if image_only
        else ""
    )

    return f"""# STAGE 2 isolated applicant evaluation

You are evaluating exactly one Ninehire applicant: `{applicant}`.

Read only these shared specs:
- `{HARNESS_ROOT / "evaluation_prompt.md"}`
- `{HARNESS_ROOT / "jd_eval_rubric.md"}`

Read only this applicant folder and its attachments:
- Applicant folder: `{folder}`
{attachment_lines}
{image_instruction}
Write exactly one output file:
- `{note_path}`

Rules:
- Do not inspect sibling applicant folders or compare this applicant to the batch.
- Do not use keyword scoring, category counting, or template generation.
- Cite real project/company/product names, metrics, roles, or decisions from this applicant's materials.
- If the source evidence is thin, say what is thin and lower the score; do not fill with generic strengths.
- Keep the note under 1000 characters and in the exact format required by `evaluation_prompt.md`.
"""


def main() -> None:
    run_dir_raw = os.environ.get("NINEHIRE_RUN_DIR")
    if not run_dir_raw:
        raise SystemExit("Set NINEHIRE_RUN_DIR to the batch run folder.")

    run_dir = Path(run_dir_raw)
    if not run_dir.exists():
        raise SystemExit(f"Run dir not found: {run_dir}")

    task_dir = run_dir / "stage2_tasks"
    task_dir.mkdir(exist_ok=True)
    manifest = []

    for metadata_path in sorted(run_dir.glob("*/metadata.json")):
        folder = metadata_path.parent
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        attachments = attachment_paths(folder)
        task_path = task_dir / f"{folder.name}.md"
        task_path.write_text(task_text(folder, metadata, attachments), encoding="utf-8")
        manifest.append(
            {
                "folder": folder.name,
                "applicant": metadata.get("applicant", folder.name),
                "task_path": str(task_path),
                "note_path": str(folder / "team_chat_note.txt"),
                "attachments": [str(path) for path in attachments],
                "image_only": bool(metadata.get("any_image_only_pdf") or metadata.get("image_only_pdf")),
            }
        )

    manifest_path = run_dir / "stage2_manifest.json"
    manifest_path.write_text(json.dumps({"run_dir": str(run_dir), "tasks": manifest}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"run_dir": str(run_dir), "task_count": len(manifest), "task_dir": str(task_dir), "manifest": str(manifest_path)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
