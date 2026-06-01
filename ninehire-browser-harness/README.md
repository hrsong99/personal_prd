# Ninehire Applicant Review Harness

Screens UI/UX-designer applicants in **Ninehire** (the ATS at `app.ninehire.com`) and writes a
short, **grounded** evidence note into each applicant's team chat — one that cites the person's
real projects, metrics, and gaps, not keyword boilerplate.

It never submits the hire/reject vote (`찬성`/`반대`/`기권`). That stays human.

---

## TL;DR — "run on N applicants"

Point at this repo and say *"run the Ninehire review on N applicants."* The agent then does:

```text
STAGE 1  EXTRACT   browser-harness < extract_applicants.py     (NINEHIRE_TARGET_COUNT=N)
STAGE 2  EVALUATE  prepare_subagent_tasks.py → one subagent per applicant → validate_notes.py
STAGE 3  POST      browser-harness < post_notes.py             (dry run, then NINEHIRE_POST=1)
```

Run all commands from the **PRD workspace root** (`personal_prd/`), not from inside this folder —
the scripts use the `ninehire-browser-harness/...` path prefix.

---

## The three stages in detail

### STAGE 1 — Extract (browser, mechanical)

```bash
NINEHIRE_TARGET_COUNT=20 browser-harness < ninehire-browser-harness/extract_applicants.py
```

Walks the `접수` kanban (oldest-first), picks **eligible** cards, opens each attachment in the
inline viewer so Ninehire emits its signed `file.ninehire.com` PDF URL, downloads the PDFs, runs
`pdftotext -layout`, and cleans whitespace. Writes per applicant:

```text
batch_runs/<timestamp>/NN_<applicant>/
    attachment_*.pdf  attachment_*.txt  attachment_*.cleaned.txt
    metadata.json     # card (incl. cardId), applicant, attachments, posted_team_chat:false
```

**Eligible** = has a `card-…` id, no final `찬성`/`반대`/`기권`, score status starts at `0`
(`평가 중 (0/1)` etc.), and `0` team-chat messages. Anything already scored or chatted is skipped.

This stage does **no scoring**. It only extracts.

### STAGE 2 — Evaluate (isolated subagents, judgment)

First generate explicit isolated tasks:

```bash
NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
    python3 ninehire-browser-harness/prepare_subagent_tasks.py
```

This writes:

```text
batch_runs/<timestamp>/stage2_tasks/NN_<applicant>.md
batch_runs/<timestamp>/stage2_manifest.json
```

For each task file, spawn **one subagent**. The task file hands it:

- `evaluation_prompt.md` — the output contract + grounding rules (read it; it is the spec)
- `jd_eval_rubric.md` — the role's JD and scoring standard
- that applicant's `attachment_*.cleaned.txt`, raw text, and PDFs

The subagent writes a grounded `team_chat_note.txt` into that folder in this exact shape
(**≤ 1000 chars — Ninehire's chat textarea is `maxlength=1000`; target ≤ 950**):

```text
TLDR: <one sentence: this person's most relevant real work + the biggest gap>
Estimated match: NN%

- Evidence: <real project/company names, real metrics, real role>
- Strengths: <what specifically maps to the JD>
- Gaps / follow-up: <missing must-have evidence, framed as interview questions>
```

One subagent **per applicant** (not one big pass) keeps each note grounded only in that person's
documents and avoids the averaged, identical-sounding output the old keyword scorer produced.

After all subagents finish, run the validator:

```bash
NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
    python3 ninehire-browser-harness/validate_notes.py
```

The validator is a posting gate. It checks the exact format, the 1000-character limit, duplicate
TLDRs, and known generic/template phrasing. It cannot prove a note is excellent, but it blocks the
specific keyword-eval failure mode and forces bad notes back to STAGE 2 before posting.

> **Image-only PDFs:** `pdftotext` returns ~empty text for scanned/image resumes. STAGE 1 flags
> this in `metadata.json` as `image_only_pdf: true` / `any_image_only_pdf: true`. When set, the
> subagent MUST read the PDF pages as images (via the Read tool on the `.pdf`) instead of trusting
> the empty `.cleaned.txt` — otherwise it would score someone on zero text.

### STAGE 3 — Post (browser, mechanical)

```bash
# 1) Dry run — prints what WOULD post, touches nothing:
NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
    browser-harness < ninehire-browser-harness/post_notes.py

# 2) For real:
NINEHIRE_POST=1 NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
    browser-harness < ninehire-browser-harness/post_notes.py
```

Posts each folder's `team_chat_note.txt` to that applicant's `팀 채팅`. It:
- is a **dry run unless `NINEHIRE_POST=1`**;
- **skips** folders with no `metadata.json` (no `cardId` → can't target the card) and reports them;
- **skips** folders already marked `posted_team_chat:true`;
- only reposts to already-posted folders when `NINEHIRE_FORCE_REPOST=1` is explicitly set;
- can resume from a folder with `NINEHIRE_START_FOLDER=NN_name` when a browser timeout interrupts a long run;
- runs the same note validator used in STAGE 2 and rejects bad notes before dry-run or posting;
- per applicant, checks the note's first line isn't already in the chat (won't double-post the
  same note on a re-run);
- marks `posted_team_chat:true` and writes `post_results.json` after a verified send.

> **⚠️ It does NOT detect a *different* note already in a chat.** If a chat already has an older
> note (e.g. a legacy keyword note), posting again **adds a second message**. Before a bulk post,
> confirm the target chats are empty of prior notes.

---

## Files

| File | Stage | Role |
|---|---|---|
| `jd_eval_rubric.md` | — | The role's JD + scoring standard. The evaluation's "what good looks like." |
| `evaluation_prompt.md` | 2 | Output contract + grounding rules each subagent follows. |
| `extract_applicants.py` | 1 | Browser extraction → cleaned PDF text + `metadata.json`. |
| `prepare_subagent_tasks.py` | 2 | Writes one isolated task prompt per applicant plus `stage2_manifest.json`. |
| `validate_notes.py` | 2/3 | Validates `team_chat_note.txt` files before posting. |
| `note_quality.py` | 2/3 | Shared validator used by `validate_notes.py` and `post_notes.py`. |
| `post_notes.py` | 3 | Posts `team_chat_note.txt` per applicant (dry run by default). |
| `cleanup_pdf_text.sh` | 1 | Standalone whitespace cleanup for extracted text (extractor inlines the same logic). |
| `ninehire_chat_debug.py` | — | Diagnostic: drafts into the chat textarea + verifies the send button **without sending**. Use when the composer misbehaves. |
| `batch_runs/`, `runs/` | — | Output + history of past runs. |

The browser mechanics (CDP) come from the global `browser-harness` skill. Posting needs the
user's Chrome logged into Ninehire; if it hits a login wall, stop and ask the user.

---

## Tuning the evaluation

The whole point of STAGE 2 is grounded, differentiated notes. To change the bar, edit
`jd_eval_rubric.md` (the standard) and/or `evaluation_prompt.md` (the rules + format). Do **not**
reintroduce a keyword/point-sum scorer — that was the removed legacy path, and it made every note
read the same (everyone landed at ~90%). The agent reading each resume against the rubric is the
design.
