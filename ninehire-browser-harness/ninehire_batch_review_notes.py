from __future__ import annotations

import json
import os
import re
import subprocess
import time
import unicodedata
from datetime import datetime
from pathlib import Path

import httpx


APPLICANTS_URL = "https://app.ninehire.com/QPVABK96/recruitment/f2e064b0-42d7-11f1-b4c0-e798d055716c/applicants"
ROOT = Path("ninehire-browser-harness")
RUNS_DIR = ROOT / "runs"
BATCH_DIR = ROOT / "batch_runs"
TARGET_COUNT = int(os.environ.get("NINEHIRE_TARGET_COUNT", "20"))
POST_TEAM_CHAT = os.environ.get("NINEHIRE_POST_TEAM_CHAT") == "1"


def clean_pdf_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\f", "\n\n--- Page Break ---\n\n")
    text = re.sub(r"[\t \u00a0]+", " ", text)
    text = "\n".join(line.strip() for line in text.splitlines())
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).strip()
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"[^0-9A-Za-z가-힣._-]+", "", value)
    return value[:80] or "applicant"


def page_state() -> dict:
    return js(
        r'''
(() => {
  const text = document.body.innerText || "";
  const modalStart = Math.max(text.lastIndexOf("\n\n나인하이어 | Ninehire"), text.lastIndexOf("\n나인하이어 | Ninehire"));
  const modalText = modalStart >= 0 ? text.slice(modalStart) : text;
  const lines = modalText.split("\n").map(s => s.trim()).filter(Boolean);
  const modalMatch = modalText.match(/\d+\s*\/\s*\d+\n[^\n]*\n(?:\d+\n)?([^\n]+)\n접수/);
  const scoreSummary = (modalText.match(/\[포도\] Resume Feedback[\s\S]{0,120}?\d+\s*\/\s*\d+/) || [""])[0]
    .replace(/\s+/g, " ")
    .trim();
  const attachmentTexts = lines
    .filter(t => /\.(pdf|html)$/i.test(t) || t.includes(".pdf"))
    .map(t => t.replace(/\s+/g, " "))
    .filter((t, i, arr) => arr.indexOf(t) === i)
    .slice(0, 20);
  return {
    url: location.href,
    title: document.title,
    bodySample: modalText.slice(0, 2400),
    applicantName: modalMatch && modalMatch[1] ? modalMatch[1].trim() : "",
    scoreSummary,
    attachmentTexts,
    sortIsOldest: text.includes("단계별 도착 오래된 순")
  };
})()
'''
    )


def set_oldest_sort_if_needed() -> bool:
    for _ in range(30):
        if "단계별" in (js("document.body.innerText || ''") or ""):
            break
        time.sleep(0.5)
    if page_state().get("sortIsOldest"):
        return True
    clicked = js(
        r'''
(() => {
  const button = [...document.querySelectorAll("button, [role=button]")]
    .find(el => (el.innerText || el.textContent || "").includes("단계별"));
  if (!button) return false;
  button.click();
  return true;
})()
'''
    )
    if not clicked:
        return False
    time.sleep(0.5)
    selected = js(
        r'''
(() => {
  const option = [...document.querySelectorAll("button, [role=button], li, div, span")]
    .find(el => (el.innerText || el.textContent || "").trim() === "단계별 도착 오래된 순");
  if (!option) return false;
  option.click();
  return true;
})()
'''
    )
    time.sleep(1)
    return bool(selected or page_state().get("sortIsOldest"))


def visible_cards() -> list[dict]:
    return js(
        r'''
(() => {
  const cards = [...document.querySelectorAll("[class*=applicant-card-target]")].filter(el => {
    const r = el.getBoundingClientRect();
    return r.width > 100 && r.height > 80 && r.x < 650;
  });
  return cards.map((el, index) => {
    const text = (el.innerText || el.textContent || "").trim();
    const lines = text.split("\n").map(s => s.trim()).filter(Boolean);
    const scoreMatch = text.match(/평가 중\s*\((\d+)\s*\/\s*(\d+)\)/);
    const finalDecision = (text.match(/(^|\n)(찬성|반대|기권)(\n|$)/) || [null, null, null])[2];
    const numbers = lines.filter(line => /^\d+$/.test(line)).map(Number);
    const chatCount = numbers.length ? numbers[0] : 0;
    const scoreDone = scoreMatch ? Number(scoreMatch[1]) : null;
    const cardId = [...el.classList].find(c => c.startsWith("card-")) || "";
    const r = el.getBoundingClientRect();
    return {
      index,
      cardId,
      name: lines[0] || "",
      scoreDone,
      scoreTotal: scoreMatch ? Number(scoreMatch[2]) : null,
      finalDecision,
      chatCount,
      eligible: Boolean(cardId) && !finalDecision && scoreDone === 0 && chatCount === 0,
      x: Math.round(r.x + r.width / 2),
      y: Math.round(r.y + Math.min(60, r.height / 2))
    };
  });
})()
'''
    )


def scroll_reception_column() -> None:
    scroll(500, 760, dy=520)
    time.sleep(0.7)


def load_more_reception_cards() -> bool:
    clicked = js(
        r'''
(() => {
  const candidates = [...document.querySelectorAll("button, [role=button], div, span")]
    .filter(el => (el.innerText || el.textContent || "").trim() === "더 불러오기")
    .map(el => {
      const r = el.getBoundingClientRect();
      return {el, x: r.x, y: r.y, width: r.width, height: r.height};
    })
    .filter(o => o.width > 40 && o.height > 12 && o.x < 650);
  if (!candidates.length) return false;
  candidates[0].el.scrollIntoView({block: "center"});
  candidates[0].el.click();
  return true;
})()
'''
    )
    time.sleep(1.5)
    return bool(clicked)


def open_card_by_id(card: dict) -> None:
    progress_id = card["cardId"].replace("card-", "", 1)
    url = f"{APPLICANTS_URL}?applicantProgressId={progress_id}&pagination=kanvan&activeTab=applicantApplication%2CteamChat&fullscreen=true"
    js(f"location.href = {json.dumps(url)}")
    wait_for_load()
    deadline = time.time() + 15
    while time.time() < deadline:
        state = page_state()
        if state.get("applicantName") or state.get("attachmentTexts"):
            return
        time.sleep(0.5)
    raise RuntimeError(f"Could not open applicant detail for {card.get('name')} ({progress_id})")


def close_modal() -> None:
    js(
        r'''
(() => {
  const closeLike = [...document.querySelectorAll("button, [role=button]")]
    .filter(el => {
      const label = [el.innerText, el.textContent, el.getAttribute("aria-label"), el.title]
        .filter(Boolean).join(" ").trim();
      const r = el.getBoundingClientRect();
      return r.width > 12 && r.height > 12 && r.x > window.innerWidth - 220 &&
        (label.includes("닫기") || label.includes("Close") || label === "×" || label === "X");
    });
  closeLike[0]?.click();
})()
'''
    )
    time.sleep(0.3)
    click_at_xy(1395, 66)
    time.sleep(0.8)
    press_key("Escape")
    time.sleep(0.5)


def collect_pdf_urls() -> list[str]:
    return js(
        r'''
(() => [...new Set(performance.getEntriesByType("resource")
  .map(r => r.name)
  .filter(u => u.includes("file.ninehire.com") && u.includes(".pdf")))])()
'''
    )


def open_attachment_cards() -> None:
    points = js(
        r'''
(() => {
  const seen = new Set();
  const candidates = [...document.querySelectorAll("div, span, button, a")].map(el => {
    const raw = (el.innerText || el.textContent || "").trim();
    const text = raw.replace(/\s+/g, " ");
    const r = el.getBoundingClientRect();
    return {raw, text, x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2), w: r.width, h: r.height};
  }).filter(o =>
    /^[^\n]+\.pdf$/i.test(o.raw) &&
    o.w >= 40 && o.w <= 520 &&
    o.h >= 12 && o.h <= 90 &&
    o.x >= 100 && o.x <= 900 &&
    o.y >= 180 && o.y <= 760
  );
  const out = [];
  for (const c of candidates) {
    const key = c.text;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(c);
  }
  return out.slice(0, 8);
})()
'''
    )
    if not points:
        raise RuntimeError("Could not find exact PDF filename elements to click")
    for point in points[:6]:
        before_count = len(collect_pdf_urls())
        click_at_xy(point["x"], point["y"])
        wait_for_load()
        deadline = time.time() + 8
        while time.time() < deadline and len(collect_pdf_urls()) <= before_count:
            time.sleep(0.4)
        click_at_xy(143, 184)
        wait_for_load()
        time.sleep(0.5)


def extract_pdfs(run_dir: Path, urls: list[str]) -> list[dict]:
    attachments = []
    for index, url in enumerate(urls, 1):
        pdf_path = run_dir / f"attachment_{index}.pdf"
        raw_txt_path = run_dir / f"attachment_{index}.txt"
        clean_txt_path = run_dir / f"attachment_{index}.cleaned.txt"
        response = httpx.get(url, timeout=90)
        response.raise_for_status()
        pdf_path.write_bytes(response.content)
        subprocess.run(["pdftotext", "-layout", str(pdf_path), str(raw_txt_path)], check=True)
        clean_txt_path.write_text(clean_pdf_text(raw_txt_path.read_text(errors="ignore")), encoding="utf-8")
        info = subprocess.run(["pdfinfo", str(pdf_path)], text=True, capture_output=True)
        pages = None
        for line in info.stdout.splitlines():
            if line.startswith("Pages:"):
                pages = line.split(":", 1)[1].strip()
                break
        attachments.append(
            {
                "index": index,
                "pdf": str(pdf_path),
                "raw_text": str(raw_txt_path),
                "cleaned_text": str(clean_txt_path),
                "pages": pages,
                "bytes": pdf_path.stat().st_size,
                "text_chars": len(clean_txt_path.read_text(errors="ignore")),
                "source_url_redacted": url.split("?", 1)[0],
            }
        )
    return attachments


def build_note(applicant: str, texts: list[str]) -> tuple[int, str]:
    combined = "\n".join(texts)
    lower = combined.lower()
    score = 45
    evidence = []
    strengths = []
    gaps = []

    if re.search(r"3년|4년|5년|6년|7년|8년|9년|10년|3\s*years|4\s*years|5\s*years", combined, re.I):
        score += 10
        evidence.append("meets or likely meets the 3+ years UI/UX requirement")
    if any(k in combined for k in ["매출", "전환", "ARPU", "LTV", "결제", "revenue", "conversion", "payment", "sales"]):
        score += 12
        strengths.append("has some business/revenue or conversion-related signal")
    if any(k in combined for k in ["매칭", "matching", "추천", "recommendation", "1:1", "네트워킹"]):
        score += 14
        strengths.append("shows matching/recommendation/networking-related signal")
    else:
        gaps.append("direct 1:1 matching/recommendation UX is not clearly shown")
    if any(k in combined for k in ["페이월", "구독", "subscription", "paywall", "premium", "프리미엄"]):
        score += 10
        strengths.append("shows subscription/paywall/premium-conversion signal")
    else:
        gaps.append("paywall/subscription/premium-conversion UX is not clearly shown")
    if any(k in combined for k in ["가설", "A/B", "AB test", "데이터", "data", "리서치", "interview", "user research", "analytics"]):
        score += 10
        strengths.append("shows data/research or hypothesis-driven work signal")
    else:
        gaps.append("hypothesis/data-driven experimentation evidence is limited")
    if any(k in combined for k in ["게임", "게이미피케이션", "리워드", "reward", "gamification", "challenge", "streak"]):
        score += 8
        strengths.append("shows gaming/gamification or reward-loop signal")
    if any(k in combined for k in ["디자인 시스템", "design system", "component", "컴포넌트", "library"]):
        score += 7
        strengths.append("shows design system/component ownership")
    if any(k in combined for k in ["개발", "engineering", "frontend", "implementation", "QA", "구현"]):
        score += 5
        strengths.append("shows engineering collaboration / implementation follow-through")

    score = max(25, min(92, score))
    evidence_text = "; ".join(evidence[:2]) or "relevant UI/UX material found in attachments"
    strengths_text = "; ".join(strengths[:3]) or "portfolio/resume has some relevant UX/product signal"
    gaps_text = "; ".join(gaps[:3]) or "no major gap identified from keyword scan; human review still needed"
    tldr = "Relevant UX/product evidence found, but key matching/monetization fit should be reviewed manually."
    if score >= 80:
        tldr = "Strong apparent fit on written evidence, with several JD/rubric signals present."
    elif score < 60:
        tldr = "Partial fit on written evidence; several core JD/rubric signals are missing or unclear."
    note = (
        f"TLDR: {tldr}\n"
        f"Estimated match: {score}%\n\n"
        f"- Evidence: {evidence_text}.\n"
        f"- Strengths: {strengths_text}.\n"
        f"- Gaps / follow-up: {gaps_text}."
    )
    return score, note


def post_team_chat(note: str) -> None:
    clicked = js(
        r'''
(() => {
  const norm = s => (s || "").replace(/\s+/g, " ").trim();
  const candidates = [...document.querySelectorAll("button, [role=button]")]
    .map(el => {
      const r = el.getBoundingClientRect();
      return {el, text: norm(el.innerText || el.textContent), x: r.x, y: r.y, width: r.width, height: r.height};
    })
    .filter(o => o.text === "팀 채팅" && o.width > 40 && o.height > 20 && o.x > 800);
  candidates.sort((a, b) => (a.width * a.height) - (b.width * b.height));
  const btn = candidates[0]?.el;
  if (!btn) return false;
  btn.click();
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
        raise RuntimeError(f"Could not open 팀 채팅 tab; clicked={clicked}")

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
    deadline = time.time() + 10
    while time.time() < deadline:
        posted = js(
            r'''
(() => {
  const textarea = [...document.querySelectorAll("textarea")]
    .find(el => (el.placeholder || "").includes("모든 사용자가") && el.offsetParent);
  const firstLine = %s;
  return {
    textareaCleared: textarea ? textarea.value.length === 0 : false,
    noteVisible: (document.body.innerText || "").includes(firstLine)
  };
})()
'''
            % json.dumps(note.splitlines()[0])
        )
        if posted.get("textareaCleared") and posted.get("noteVisible"):
            return
        time.sleep(0.5)
    raise RuntimeError("Team-chat send did not verify as posted")


def process_card(card: dict, batch_dir: Path) -> dict:
    open_card_by_id(card)
    state = page_state()
    applicant = state.get("applicantName") or card.get("name") or "applicant"
    run_dir = batch_dir / f"{len(list(batch_dir.glob('*')))+1:02d}_{slugify(applicant)}"
    run_dir.mkdir(parents=True, exist_ok=False)

    js("performance.clearResourceTimings()")
    open_attachment_cards()
    urls = collect_pdf_urls()
    if not urls:
        raise RuntimeError(f"No fresh PDF URLs fetched for {applicant}")
    attachments = extract_pdfs(run_dir, list(dict.fromkeys(urls)))
    texts = [Path(a["cleaned_text"]).read_text(errors="ignore") for a in attachments]
    match, note = build_note(applicant, texts)

    metadata = {
        "card": card,
        "applicant": applicant,
        "state": state,
        "estimated_match": match,
        "team_chat_note": note,
        "posted_team_chat": False,
        "attachments": attachments,
    }
    (run_dir / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    (run_dir / "team_chat_note.txt").write_text(note + "\n", encoding="utf-8")
    if POST_TEAM_CHAT:
        post_team_chat(note)
        metadata["posted_team_chat"] = True
        (run_dir / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    close_modal()
    return metadata


def main() -> None:
    batch_dir = BATCH_DIR / datetime.now().strftime("%Y%m%d_%H%M%S")
    batch_dir.mkdir(parents=True, exist_ok=False)
    processed_ids: set[str] = set()
    results = []

    new_tab(APPLICANTS_URL)
    wait_for_load()
    set_oldest_sort_if_needed()

    idle_rounds = 0
    successful_count = 0
    attempt_count = 0
    while successful_count < TARGET_COUNT and idle_rounds < 8 and attempt_count < TARGET_COUNT + 10:
        cards = visible_cards()
        eligible = [c for c in cards if c.get("eligible") and c.get("cardId") not in processed_ids]
        if not eligible:
            idle_rounds += 1
            if not load_more_reception_cards():
                scroll_reception_column()
            continue
        idle_rounds = 0
        card = eligible[0]
        processed_ids.add(card["cardId"])
        attempt_count += 1
        try:
            result = process_card(card, batch_dir)
            results.append(result)
            successful_count += 1
            print(json.dumps({"processed": successful_count, "applicant": result["applicant"], "estimated_match": result["estimated_match"]}, ensure_ascii=False))
        except Exception as exc:
            error = {"card": card, "error": repr(exc)}
            results.append({"error": error})
            (batch_dir / f"error_{len(results):02d}.json").write_text(json.dumps(error, ensure_ascii=False, indent=2), encoding="utf-8")
            try:
                close_modal()
            except Exception:
                pass

    summary = {
        "target_count": TARGET_COUNT,
        "post_team_chat": POST_TEAM_CHAT,
        "completed_or_attempted": len(results),
        "successful": len([r for r in results if "error" not in r]),
        "batch_dir": str(batch_dir),
        "results": results,
    }
    (batch_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


main()
