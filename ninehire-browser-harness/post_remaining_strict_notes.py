from __future__ import annotations

import json
import time
from pathlib import Path


APPLICANTS_URL = "https://app.ninehire.com/QPVABK96/recruitment/f2e064b0-42d7-11f1-b4c0-e798d055716c/applicants"
BATCH_DIR = Path("ninehire-browser-harness/batch_runs/20260529_100830")
SKIP_CARD_IDS = {
    "card-7c743550-4dc6-11f1-ad52-ddaac2cdd4f0",
    "card-7c74aa80-4dc6-11f1-ad52-ddaac2cdd4f0",
}


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


def note_present(note: str) -> bool:
    first_two = "\n".join(note.splitlines()[:2])
    return js(
        r'''
((firstTwo) => (document.body.innerText || "").includes(firstTwo))(%s)
'''
        % json.dumps(first_two)
    )


def post_team_chat(note: str) -> str:
    if note_present(note):
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
((firstTwo) => {
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  return {
    textareaCleared: textarea ? textarea.value.length === 0 : false,
    noteVisible: (document.body.innerText || "").includes(firstTwo)
  };
})(%s)
'''
            % json.dumps("\n".join(note.splitlines()[:2]))
        )
        if posted.get("textareaCleared") and posted.get("noteVisible"):
            return "posted"
        time.sleep(0.5)
    raise RuntimeError("Team-chat send did not verify as posted")


def main() -> None:
    results = []
    for metadata_path in sorted(BATCH_DIR.glob("*/metadata.json")):
        metadata = json.loads(metadata_path.read_text())
        card_id = metadata["card"]["cardId"]
        if card_id in SKIP_CARD_IDS:
            continue
        note_path = metadata_path.parent / "team_chat_note.strict.txt"
        if not note_path.exists():
            continue
        note = note_path.read_text().strip()
        open_applicant(card_id)
        status = post_team_chat(note)
        metadata["strict_posted_team_chat"] = status
        metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        row = {
            "applicant": metadata["applicant"],
            "cardId": card_id,
            "strict_estimated_match": metadata.get("strict_estimated_match"),
            "status": status,
            "note": str(note_path),
        }
        results.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        time.sleep(0.8)
    (BATCH_DIR / "strict_post_results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"posted_or_present": len(results), "results": results}, ensure_ascii=False, indent=2))


main()
