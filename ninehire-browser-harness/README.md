# Ninehire Browser Harness Notes

This directory captures what worked for extracting text from Ninehire applicant attachments using `browser-harness`.

## What Worked

Ninehire's inline document viewer loads applicant attachments as signed PDF URLs from `file.ninehire.com`. Those URLs are visible in the page's browser resource list after opening an attachment in the viewer.

The reliable workflow is:

1. Open the Ninehire applicant page with `browser-harness`.
2. Open each attachment once in the inline viewer.
3. Read PDF URLs from `performance.getEntriesByType("resource")`.
4. Fetch each signed PDF URL directly.
5. Run local PDF text extraction with `pdftotext -layout`.
6. Run `cleanup_pdf_text.sh` on the extracted text files to remove layout whitespace.
7. Use screenshots only as a fallback for scanned/image-only pages or bad text layers.

## Example

```bash
browser-harness <<'PY'
from pathlib import Path
import httpx
import subprocess

urls = js('''
(() => [...new Set(performance.getEntriesByType("resource")
  .map(r => r.name)
  .filter(u => u.includes("file.ninehire.com") && u.includes(".pdf")))])()
''')

out_dir = Path("ninehire-browser-harness")
out_dir.mkdir(exist_ok=True)

for i, url in enumerate(urls, 1):
    pdf_path = out_dir / f"attachment_{i}.pdf"
    txt_path = out_dir / f"attachment_{i}.txt"
    response = httpx.get(url, timeout=60)
    response.raise_for_status()
    pdf_path.write_bytes(response.content)
    subprocess.run(["pdftotext", "-layout", str(pdf_path), str(txt_path)], check=True)
    print(txt_path)
PY
```

Then clean the text output:

```bash
./ninehire-browser-harness/cleanup_pdf_text.sh \
  ninehire-browser-harness/attachment_1.txt \
  ninehire-browser-harness/attachment_2.txt
```

The cleanup script:

- converts PDF page breaks into `--- Page Break ---`;
- collapses repeated spaces/tabs into one space;
- trims leading/trailing whitespace on each line;
- collapses repeated blank lines.

## Files

- `resume.txt`: extracted text from the resume PDF.
- `portfolio.txt`: extracted text from the portfolio PDF.
- `resume.cleaned.txt`: whitespace-cleaned resume text.
- `portfolio.cleaned.txt`: whitespace-cleaned portfolio text.
- `cleanup_pdf_text.sh`: reusable cleanup step for extracted PDF text.
- `jd_eval_rubric.md`: placeholder for the JD and evaluation rubric.
- `ninehire_review_packet.py`: browser-harness workflow that sorts the queue, opens the first visible `접수` applicant, extracts attachment text, and writes a human-review packet without submitting a vote.
- `ninehire_batch_review_notes.py`: batch workflow that processes up to 20 eligible applicants, extracts attachments, and writes local packets with short English-only evidence notes. Team-chat posting is opt-in because Ninehire's chat composer is not consistently controllable through browser-harness.
- `ninehire_chat_debug.py`: safe diagnostic workflow for the current applicant. It opens/validates `팀 채팅`, writes a debug draft into the textarea, verifies the send button enables, and clears the draft without sending.
- `generate_strict_notes.py`: regenerates stricter notes that reserve high match scores for exact matching/monetization/data evidence or clearly exceptional product/UI ownership. Evidence lines are English summaries of detected signals, not raw PDF snippets.
- `post_remaining_strict_notes.py`: posts generated strict notes for applicants that already have local packets, skipping the first two cards that were handled separately.

## Review Packet Workflow

Run this from the PRD workspace:

```bash
browser-harness < ninehire-browser-harness/ninehire_review_packet.py
```

The workflow:

1. Opens the applicant kanban.
2. Confirms or attempts to switch sorting to `단계별 도착 오래된 순`.
3. Opens the first visible applicant card in the `접수` column.
4. Chooses the first visible `접수` card that appears to have no final evaluation and no team-chat messages.
5. Reads the visible score-sheet state, including whether it appears to be `0 / 1`, `1 / 2`, etc.
6. Opens visible attachment chips so Ninehire fetches their signed PDF URLs.
7. Downloads those PDFs, runs `pdftotext -layout`, and writes cleaned text copies.
8. Writes a `review_draft.md` for human review.

Output is written to:

```text
ninehire-browser-harness/runs/<timestamp>_<applicant>/
```

The workflow intentionally does not choose or submit `찬성`, `반대`, or `기권`. Hiring decisions should stay human-reviewed; use the extracted packet and your rubric to make the final selection in Ninehire.

Batch run:

```bash
browser-harness < ninehire-browser-harness/ninehire_batch_review_notes.py
```

The batch runner uses the same eligibility rules, then writes a short English-only team-chat note with:

- `TLDR:`
- `Estimated match: NN%`
- `Evidence`
- `Strengths`
- `Gaps / follow-up`

The percentage is a heuristic written-evidence match against the JD/rubric, not a final hiring decision.

To opt into team-chat posting, set `NINEHIRE_POST_TEAM_CHAT=1`. Keep it unset for safer local-only batch runs:

```bash
NINEHIRE_TARGET_COUNT=20 browser-harness < ninehire-browser-harness/ninehire_batch_review_notes.py
NINEHIRE_TARGET_COUNT=20 NINEHIRE_POST_TEAM_CHAT=1 browser-harness < ninehire-browser-harness/ninehire_batch_review_notes.py
```

Team-chat reliability notes:

- The chat composer is a normal `textarea` with placeholder text beginning `모든 사용자가 볼 수 있는 메시지입니다`.
- The reliable path is to select the exact `팀 채팅` button, wait for that textarea, set the textarea value with the native setter, dispatch `input`/`change`, verify `보내기` is enabled, then click the actual `보내기` button.
- Avoid broad coordinate fallbacks for posting. They can hit the tab label, modal body, share/refresh/fullscreen buttons, or stale UI after attachment viewer transitions.
- Fullscreen applicant mode exposes top-left previous/next buttons. The right button moves to the next applicant and the left button moves back; this can reduce close/reopen flicker for future sequential workflows.

Current detection notes:

- Cards with a visible final label of `찬성`, `반대`, or `기권` are treated as already evaluated and skipped when choosing the first visible card.
- Cards are eligible only when the visible score status starts at `0`, e.g. `평가 중 (0/1)` or `평가 중 (0/2)`.
- Cards are eligible only when the visible chat count is `0`.
- Cards with score counts such as `1 / 2` are skipped because someone has already evaluated them.
- The script generates evidence packets; final evaluation form entry remains manual.
- Team-chat notes should be English-only, short, and start with `TLDR:` plus `Estimated match: NN%` to avoid truncation and make the review easier to scan.
- Strict team-chat notes should use `Strict estimated match: NN%`. Treat 70s as "possibly relevant but not exact," 80s as strong exact/exceptional evidence, and 90s as rare.

The signed PDF URLs are intentionally not saved here because they are sensitive and expire.
