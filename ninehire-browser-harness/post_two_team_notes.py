from __future__ import annotations

import json
import time
from pathlib import Path


APPLICANTS_URL = "https://app.ninehire.com/QPVABK96/recruitment/f2e064b0-42d7-11f1-b4c0-e798d055716c/applicants"
TARGETS = [
    Path("ninehire-browser-harness/batch_runs/20260529_100830/01_김재영"),
    Path("ninehire-browser-harness/batch_runs/20260529_100830/02_최은미"),
]


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
    results = []
    for target in TARGETS:
        metadata_path = target / "metadata.json"
        note_path = target / "team_chat_note.txt"
        metadata = json.loads(metadata_path.read_text())
        note = note_path.read_text().strip()
        open_applicant(metadata["card"]["cardId"])
        status = post_team_chat(note)
        results.append(
            {
                "applicant": metadata["applicant"],
                "cardId": metadata["card"]["cardId"],
                "status": status,
                "note": str(note_path),
            }
        )
    print(json.dumps(results, ensure_ascii=False, indent=2))


main()
