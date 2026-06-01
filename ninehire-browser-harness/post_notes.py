"""STAGE 3 — Post grounded team-chat notes back to Ninehire.

Reads team_chat_note.txt from every applicant folder in a run dir and posts each to that
applicant's Ninehire 팀 채팅. Requires browser-harness against the user's logged-in Chrome.

    # Dry run (default): print exactly what WOULD be posted, touch nothing.
    NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/20260529_100830 \
        browser-harness < ninehire-browser-harness/post_notes.py

    # Actually post:
    NINEHIRE_POST=1 NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/20260529_100830 \
        browser-harness < ninehire-browser-harness/post_notes.py

Safety:
- Dry run unless NINEHIRE_POST=1.
- Skips folders with no metadata.json (no cardId -> cannot target the card) and reports them.
- Skips folders already marked posted_team_chat=true.
- Per-applicant the composer also checks the note's first line is not already in the chat
  (already_present) so a re-run never double-posts the same note.

NOTE: this does NOT detect a *different* note already posted to the same chat (e.g. an old
keyword note). If a run was posted before with different text, posting again ADDS a second
message. Check that before a bulk post.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path


HARNESS_ROOT = Path("ninehire-browser-harness")
if not HARNESS_ROOT.exists():
    HARNESS_ROOT = Path(".")
sys.path.insert(0, str(HARNESS_ROOT.resolve()))

from note_quality import validate_note_text


APPLICANTS_URL = os.environ.get(
    "NINEHIRE_APPLICANTS_URL",
    "https://app.ninehire.com/QPVABK96/recruitment/f2e064b0-42d7-11f1-b4c0-e798d055716c/applicants",
)
RUN_DIR = Path(os.environ["NINEHIRE_RUN_DIR"]) if os.environ.get("NINEHIRE_RUN_DIR") else None
DO_POST = os.environ.get("NINEHIRE_POST") == "1"
FORCE_REPOST = os.environ.get("NINEHIRE_FORCE_REPOST") == "1"
START_FOLDER = os.environ.get("NINEHIRE_START_FOLDER", "")


def open_applicant(card_id: str) -> None:
    progress_id = card_id.replace("card-", "", 1)
    url = f"{APPLICANTS_URL}?applicantProgressId={progress_id}&pagination=kanvan&activeTab=applicantApplication%2CteamChat&fullscreen=true"
    js(f"location.href = {json.dumps(url)}")
    wait_for_load()
    deadline = time.time() + 15
    while time.time() < deadline:
        loaded = js(
            r'''
(() => {
  const text = document.body.innerText || "";
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  return Boolean(text.includes("팀 채팅") && textarea);
})()
'''
        )
        if loaded:
            return
        time.sleep(0.4)
    raise RuntimeError(f"Timed out opening applicant {progress_id}")


def post_team_chat(note: str) -> str:
    first_line = note.splitlines()[0]
    existing = js(
        r'''
((firstLine) => (document.body.innerText || "").includes(firstLine))(%s)
'''
        % json.dumps(first_line)
    )
    if existing:
        return "already_present"

    clicked = js(
        r'''
(() => {
  const norm = s => (s || "").replace(/\s+/g, " ").trim();
  const candidates = [...document.querySelectorAll("button, [role=button]")]
    .map(el => {
      const r = el.getBoundingClientRect();
      return {el, text: norm(el.innerText || el.textContent), x: r.x, width: r.width, height: r.height};
    })
    .filter(o => o.text === "팀 채팅" && o.width > 40 && o.height > 20 && o.x > 800);
  candidates.sort((a, b) => (a.width * a.height) - (b.width * b.height));
  if (!candidates[0]) return false;
  candidates[0].el.click();
  return true;
})()
'''
    )
    deadline = time.time() + 10
    while time.time() < deadline:
        has_textarea = js(
            r'''[...document.querySelectorAll("textarea")]
  .some(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent)'''
        )
        if has_textarea:
            break
        time.sleep(0.3)
    else:
        raise RuntimeError(f"Could not open team chat tab; clicked={clicked}")

    draft_result = js(
        r'''
((note) => {
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  if (!textarea) return {ok: false, reason: "textarea not found"};
  textarea.focus();
  const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
  setter.call(textarea, note);
  textarea.dispatchEvent(new Event("input", {bubbles: true}));
  textarea.dispatchEvent(new Event("change", {bubbles: true}));
  const sendButton = [...document.querySelectorAll("button")]
    .find(el => (el.innerText || el.textContent || "").trim() === "보내기" && el.offsetParent);
  return {
    ok: textarea.value === note,
    valueLength: textarea.value.length,
    sendDisabled: sendButton ? sendButton.disabled : null
  };
})(%s)
'''
        % json.dumps(note)
    )
    if not draft_result.get("ok") or draft_result.get("sendDisabled"):
        raise RuntimeError(f"Could not populate team-chat textarea: {draft_result}")

    sent = js(
        r'''
(() => {
  const sendButton = [...document.querySelectorAll("button")]
    .find(el => (el.innerText || el.textContent || "").trim() === "보내기" && el.offsetParent);
  if (!sendButton || sendButton.disabled) return false;
  sendButton.click();
  return true;
})()
'''
    )
    if not sent:
        raise RuntimeError("Could not click enabled team-chat send button")

    deadline = time.time() + 12
    while time.time() < deadline:
        posted = js(
            r'''
((firstLine) => {
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  return {
    textareaCleared: textarea ? textarea.value.length === 0 : false,
    noteVisible: (document.body.innerText || "").includes(firstLine)
  };
})(%s)
'''
            % json.dumps(first_line)
        )
        if posted.get("textareaCleared") and posted.get("noteVisible"):
            return "posted"
        time.sleep(0.5)
    raise RuntimeError("Team-chat send did not verify as posted")


def main() -> None:
    if RUN_DIR is None:
        raise SystemExit("Set NINEHIRE_RUN_DIR to the run folder, e.g. .../batch_runs/<timestamp>")
    if not RUN_DIR.exists():
        raise SystemExit(f"Run dir not found: {RUN_DIR}")

    results = []
    for metadata_path in sorted(RUN_DIR.glob("*/metadata.json")):
        folder = metadata_path.parent
        if START_FOLDER and folder.name < START_FOLDER:
            continue
        note_path = folder / "team_chat_note.txt"
        metadata = json.loads(metadata_path.read_text())
        applicant = metadata.get("applicant", folder.name)
        card_id = metadata.get("card", {}).get("cardId")

        if not note_path.exists():
            results.append({"applicant": applicant, "status": "no_note (run STAGE 2 first)"})
            continue
        if not card_id:
            results.append({"applicant": applicant, "status": "no_cardId (extraction incomplete; cannot target card)"})
            continue
        if metadata.get("posted_team_chat") and not FORCE_REPOST:
            results.append({"applicant": applicant, "status": "skip_already_posted"})
            continue

        note = note_path.read_text().strip()
        validation_errors = validate_note_text(note)
        if validation_errors:
            results.append({"applicant": applicant, "status": f"quality_reject ({'; '.join(validation_errors)})"})
            continue
        if not DO_POST:
            results.append({"applicant": applicant, "status": "DRY_RUN", "chars": len(note), "first_line": note.splitlines()[0]})
            continue

        open_applicant(card_id)
        status = post_team_chat(note)
        if status == "posted":
            metadata["posted_team_chat"] = True
            metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        results.append({"applicant": applicant, "cardId": card_id, "status": status})
        print(json.dumps({"applicant": applicant, "status": status}, ensure_ascii=False))

    summary = {"run_dir": str(RUN_DIR), "posted_for_real": DO_POST, "results": results}
    (RUN_DIR / "post_results.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


main()
