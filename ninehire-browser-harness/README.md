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

## Review Packet Workflow

Run this from the PRD workspace:

```bash
browser-harness < ninehire-browser-harness/ninehire_review_packet.py
```

The workflow:

1. Opens the applicant kanban.
2. Confirms or attempts to switch sorting to `단계별 도착 오래된 순`.
3. Opens the first visible applicant card in the `접수` column.
4. Reads the visible score-sheet state, including whether it appears to be `0 / 1`, `1 / 2`, etc.
5. Opens visible attachment chips so Ninehire fetches their signed PDF URLs.
6. Downloads those PDFs, runs `pdftotext -layout`, and writes cleaned text copies.
7. Writes a `review_draft.md` for human review.

Output is written to:

```text
ninehire-browser-harness/runs/<timestamp>_<applicant>/
```

The workflow intentionally does not choose or submit `찬성`, `반대`, or `기권`. Hiring decisions should stay human-reviewed; use the extracted packet and your rubric to make the final selection in Ninehire.

Current detection notes:

- Cards with a visible final label of `찬성`, `반대`, or `기권` are treated as already evaluated and skipped when choosing the first visible card.
- Score counts such as `0 / 1` or `1 / 2` are captured in metadata, but they are not treated as final decisions by themselves.
- The script generates evidence packets; final evaluation form entry remains manual.

The signed PDF URLs are intentionally not saved here because they are sensitive and expire.
