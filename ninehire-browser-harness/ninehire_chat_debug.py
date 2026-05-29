from __future__ import annotations

import json
import time


TEST_DRAFT = """TLDR: Debug draft only; do not send.
Estimated match: 88%

- Evidence: textarea focus and native value setting should enable the send button.
- Strengths: avoids coordinate typing and long keystroke playback.
- Gaps / follow-up: this draft is cleared before the script exits."""


def dump(label: str) -> None:
    state = js(
        r'''
(() => {
  const norm = s => (s || "").replace(/\s+/g, " ").trim();
  const lines = (document.body.innerText || "").split("\n").map(s => s.trim()).filter(Boolean);
  const modalIndex = lines.findIndex((line, index) =>
    /^\d+\/\d+$/.test(line) && lines[index + 1] && lines[index + 1].includes("[포도 스피킹]")
  );
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  const sendButton = [...document.querySelectorAll("button")]
    .find(el => (el.innerText || el.textContent || "").trim() === "보내기" && el.offsetParent);
  return {
    label: __LABEL__,
    url: location.href,
    modalLines: modalIndex >= 0 ? lines.slice(modalIndex, modalIndex + 8) : [],
    textarea: textarea ? {
      valueLength: textarea.value.length,
      focused: textarea === document.activeElement,
      x: Math.round(textarea.getBoundingClientRect().x),
      y: Math.round(textarea.getBoundingClientRect().y),
      width: Math.round(textarea.getBoundingClientRect().width),
      height: Math.round(textarea.getBoundingClientRect().height)
    } : null,
    sendButton: sendButton ? {disabled: sendButton.disabled, text: norm(sendButton.innerText || sendButton.textContent)} : null
  };
})()
'''.replace("__LABEL__", json.dumps(label))
    )
    print(json.dumps(state, ensure_ascii=False, indent=2))


def set_draft(value: str) -> dict:
    return js(
        r'''
((value) => {
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  if (!textarea) return {ok: false, reason: "textarea not found"};
  textarea.focus();
  const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
  setter.call(textarea, value);
  textarea.dispatchEvent(new Event("input", {bubbles: true}));
  textarea.dispatchEvent(new Event("change", {bubbles: true}));
  const sendButton = [...document.querySelectorAll("button")]
    .find(el => (el.innerText || el.textContent || "").trim() === "보내기" && el.offsetParent);
  return {ok: textarea.value === value, valueLength: textarea.value.length, sendDisabled: sendButton ? sendButton.disabled : null};
})(%s)
'''
        % json.dumps(value)
    )


def main() -> None:
    dump("before")

    clicked_team_chat = js(
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
    print(json.dumps({"clicked_team_chat": clicked_team_chat}, ensure_ascii=False))
    time.sleep(0.8)
    dump("after_team_chat_click")

    print(json.dumps({"set_draft": set_draft(TEST_DRAFT)}, ensure_ascii=False))
    time.sleep(0.5)
    dump("after_set_draft")

    print(json.dumps({"clear_draft": set_draft("")}, ensure_ascii=False))
    time.sleep(0.5)
    dump("after_clear_draft")


main()
