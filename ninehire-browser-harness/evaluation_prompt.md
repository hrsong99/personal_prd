# Applicant Evaluation Prompt (harness-driven)

This is the instruction set a Claude Code / Codex subagent follows to write ONE applicant's
team-chat note. It replaces the keyword-template builders (`build_note`, `strict_note`,
`generate_strict_notes.py`), which produced near-identical notes for everyone.

The harness — not the browser-harness Python script — does the judgment. No API call is
embedded anywhere: the extract step writes cleaned text, a subagent reads it and writes the
note file, and the existing posting script posts that file.

## Inputs given to each subagent

- One applicant's extracted documents: `batch_runs/<ts>/NN_name/attachment_*.cleaned.txt`
- The role spec + standard: `jd_eval_rubric.md`
- Nothing about any other applicant. Each note must be grounded only in this person's documents.

## Output contract (write to `batch_runs/<ts>/NN_name/team_chat_note.txt`)

English only. **HARD LIMIT: the note must be ≤ 1000 characters — Ninehire's team-chat textarea
has `maxlength=1000` and silently truncates anything longer, so an over-length note cannot be
posted. Target ≤ 950 characters to leave margin.** Count the characters before you finish; if
over, cut filler words and redundant clauses (keep the concrete names/metrics). Exact shape:

```text
TLDR: <one sentence naming THIS applicant's most relevant real work + the single biggest gap>
Estimated match: NN%

- Evidence: <2-3 concrete items from the documents — real project/company names, real metrics, real role>
- Strengths: <what specifically maps to the JD: name the project and what they owned/shipped>
- Gaps / follow-up: <the specific must-have evidence that is absent or unclear, framed as an interview question>
```

## Grounding rules (this is the whole point)

1. **Quote real specifics, never category labels.** Write "redesigned the paywall on App X,
   reported +18% trial→paid" — NOT "conversion/subscription/paywall signal appears."
   If you cannot name the project, company, role, or number, the line is not grounded enough.
2. **No canned sentences.** Two applicants must never get the same Strengths/TLDR wording. The
   phrasing should be impossible to reuse for a different person because it cites their work.
3. **Numbers are gold.** Pull every concrete metric in the documents (%, revenue, users, MAU,
   conversion, retention, team size, years) and prefer them over adjectives.
4. **Absence must be specific.** Instead of "no clear matching/monetization evidence," write
   what you DID see and what's missing: "Portfolio is B2B SaaS dashboards; no 1:1 matching,
   dating, or recommendation surface anywhere — confirm in interview whether any consumer
   matching/discovery work exists."
5. **Clean the source.** The cleaned text still has `--- Page Break ---` markers and OCR noise.
   Never paste raw fragments into Evidence; rephrase into readable English.
6. **Score from the rubric, justify in the note.** Use the bands in `jd_eval_rubric.md`
   (85-100 strong + a key preferred signal; 70-84 solid ownership/impact missing a preferred
   signal; 50-69 relevant but gaps; <50 mostly executional). The Evidence/Strengths/Gaps must
   make the chosen NN% obvious — a reader should agree with the number from the bullets alone.
7. **Judge depth, not keyword presence.** "Used data" only counts if there is a hypothesis,
   an experiment, or a decision that followed from the data. Visual polish ≠ product ownership.

## What "good" vs the old output looks like

Old (keyword template, same for everyone):
> Strong signals: product planning / UX structure / ownership signal appears; some data/research/hypothesis signal appears.

Grounded (this prompt):
> Strengths: Owned the '어플레이즈' music-recommendation app end-to-end — defined the problem,
> ran the UI/UX renewal, and shipped the spatial-data recommendation flow. Closest thing to a
> recommendation surface in the batch, though it's content recsys, not 1:1 person-to-person matching.

## Notes

- This file is the durable spec. The per-run fan-out hands each subagent: this file +
  `jd_eval_rubric.md` + that applicant's cleaned text, and tells it to write `team_chat_note.txt`.
- Posting stays manual/opt-in via the existing posting scripts. Generating notes posts nothing.
