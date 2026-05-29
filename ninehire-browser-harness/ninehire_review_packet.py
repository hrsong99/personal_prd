from __future__ import annotations

import json
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
RUBRIC_PATH = ROOT / "jd_eval_rubric.md"


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
  const applicantName = lines.find((line, index) =>
    index > 0 &&
    index < 30 &&
    line.length >= 2 &&
    line.length <= 20 &&
    /^[가-힣A-Za-z\s]+$/.test(line) &&
    !["데이원컴퍼니", "채용 관리", "지원자 관리", "채용 캘린더", "채용 설정", "접수", "인재 소싱"].includes(line)
  ) || "";

  const scoreSummary = (modalText.match(/\[포도\] Resume Feedback[\s\S]{0,120}?\d+\s*\/\s*\d+/) || [""])[0]
    .replace(/\s+/g, " ")
    .trim();

  const decisionMarkers = lines.filter(line => ["찬성", "반대", "기권"].includes(line));

  const attachmentTexts = lines
    .filter(t => /\.(pdf|html)$/i.test(t) || t.includes(".pdf"))
    .map(t => t.replace(/\s+/g, " "))
    .filter((t, i, arr) => arr.indexOf(t) === i)
    .slice(0, 20);

  return {
    url: location.href,
    title: document.title,
    bodySample: modalText.slice(0, 3000),
    guessedHeading: (modalMatch && modalMatch[1] ? modalMatch[1].trim() : applicantName),
    scoreSummary,
    decisionMarkers,
    attachmentTexts,
    sortIsOldest: text.includes("단계별 도착 오래된 순")
  };
})()
'''
    )


def wait_until_text(keyword: str, timeout: int = 12) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if keyword in page_state().get("bodySample", ""):
            return True
        time.sleep(0.5)
    return False


def set_oldest_sort_if_needed() -> bool:
    wait_until_text("지원자 관리", timeout=15)
    state = page_state()
    if state.get("sortIsOldest"):
        return True

    clicked = js(
        r'''
(() => {
  const candidates = [...document.querySelectorAll("button, [role=button]")];
  const button = candidates.find(el => (el.innerText || el.textContent || "").includes("단계별"));
  if (!button) return false;
  button.click();
  return true;
})()
'''
    )
    if not clicked:
        return False
    wait_for_load()

    selected = js(
        r'''
(() => {
  const candidates = [...document.querySelectorAll("button, [role=button], li, div, span")];
  const option = candidates.find(el => (el.innerText || el.textContent || "").trim() === "단계별 도착 오래된 순");
  if (!option) return false;
  option.click();
  return true;
})()
'''
    )
    wait_for_load()
    time.sleep(1)
    return bool(selected or page_state().get("sortIsOldest"))


def open_first_visible_reception_card() -> None:
    clicked = js(
        r'''
(() => {
  const cards = [...document.querySelectorAll("[class*=applicant-card-target]")].filter(el => {
    const r = el.getBoundingClientRect();
    return r.width > 100 && r.height > 80 && r.y >= 250 && r.y < window.innerHeight;
  });

  const parseCard = (el) => {
    const text = (el.innerText || el.textContent || "").trim();
    const lines = text.split("\n").map(s => s.trim()).filter(Boolean);
    const finalDecision = /(^|\n)(찬성|반대|기권)(\n|$)/.test(text);
    const scoreMatch = text.match(/평가 중\s*\((\d+)\s*\/\s*(\d+)\)/);
    const scoreDone = scoreMatch ? Number(scoreMatch[1]) : null;
    const chatCount = Number(lines.find(line => /^\d+$/.test(line)) || "0");
    return {text, lines, finalDecision, scoreDone, chatCount};
  };

  const eligible = cards.find(el => {
    const parsed = parseCard(el);
    return !parsed.finalDecision && parsed.scoreDone === 0 && parsed.chatCount === 0;
  });

  const card = eligible;
  if (!card) return null;
  const r = card.getBoundingClientRect();
  const parsed = parseCard(card);
  card.click();
  return {text: parsed.text, scoreDone: parsed.scoreDone, chatCount: parsed.chatCount, x: Math.round(r.x), y: Math.round(r.y)};
})()
'''
    )
    if not clicked:
        raise RuntimeError("Could not find a visible 접수 applicant card with no evaluation and no chat")
    wait_for_load()
    time.sleep(1)
    state = page_state()
    if "applicantProgressId=" in state.get("url", "") or "첨부 파일" in state.get("bodySample", ""):
        return
    raise RuntimeError(f"Clicked eligible card but applicant modal did not open: {clicked}")


def visible_card_eligibility_summary() -> list[dict]:
    return js(
        r'''
(() => {
  const cards = [...document.querySelectorAll("[class*=applicant-card-target]")].filter(el => {
    const r = el.getBoundingClientRect();
    return r.width > 100 && r.height > 80 && r.y >= 250 && r.y < window.innerHeight;
  });
  return cards.map((el, index) => {
    const text = (el.innerText || el.textContent || "").trim();
    const lines = text.split("\n").map(s => s.trim()).filter(Boolean);
    const scoreMatch = text.match(/평가 중\s*\((\d+)\s*\/\s*(\d+)\)/);
    const finalDecision = (text.match(/(^|\n)(찬성|반대|기권)(\n|$)/) || [null, null, null])[2];
    const chatCount = Number(lines.find(line => /^\d+$/.test(line)) || "0");
    const scoreDone = scoreMatch ? Number(scoreMatch[1]) : null;
    const name = lines[0] || "";
    return {
      index,
      name,
      scoreDone,
      scoreTotal: scoreMatch ? Number(scoreMatch[2]) : null,
      finalDecision,
      chatCount,
      eligible: !finalDecision && scoreDone === 0 && chatCount === 0
    };
  }).slice(0, 20);
})()
'''
    )


def collect_pdf_urls() -> list[str]:
    return js(
        r'''
(() => [...new Set(performance.getEntriesByType("resource")
  .map(r => r.name)
  .filter(u => u.includes("file.ninehire.com") && u.includes(".pdf")))])()
'''
    )


def open_attachment_cards() -> None:
    # Open the first several visible attachment chips in the applicant modal. Each click causes
    # Ninehire's viewer to fetch the signed PDF URL, which we collect from performance resources.
    wait_until_text("첨부 파일", timeout=10)
    state = page_state()
    count_hint = max(1, min(5, len(state.get("attachmentTexts", [])) or 1))
    for i in range(count_hint):
        x = 300 + (i % 3) * 285
        y = 323 + (i // 3) * 52
        click_at_xy(x, y)
        wait_for_load()
        time.sleep(1)
        # Back button inside the document viewer.
        click_at_xy(143, 184)
        wait_for_load()
        time.sleep(0.5)


def extract_pdfs(run_dir: Path, urls: list[str]) -> list[dict]:
    attachments = []
    for index, url in enumerate(urls, 1):
        pdf_path = run_dir / f"attachment_{index}.pdf"
        raw_txt_path = run_dir / f"attachment_{index}.txt"
        clean_txt_path = run_dir / f"attachment_{index}.cleaned.txt"

        response = httpx.get(url, timeout=60)
        response.raise_for_status()
        pdf_path.write_bytes(response.content)

        subprocess.run(["pdftotext", "-layout", str(pdf_path), str(raw_txt_path)], check=True)
        clean_txt_path.write_text(clean_pdf_text(raw_txt_path.read_text(errors="ignore")))

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
                "bytes": pdf_path.stat().st_size,
                "pages": pages,
                "text_chars": len(clean_txt_path.read_text(errors="ignore")),
                "source_url_redacted": url.split("?", 1)[0],
            }
        )
    return attachments


def write_review_draft(run_dir: Path, metadata: dict, attachments: list[dict]) -> None:
    rubric = RUBRIC_PATH.read_text(errors="ignore") if RUBRIC_PATH.exists() else ""
    attachment_lines = "\n".join(
        f"- Attachment {a['index']}: `{Path(a['cleaned_text']).name}` ({a.get('pages') or '?'} pages, {a['text_chars']} chars)"
        for a in attachments
    )
    (run_dir / "review_draft.md").write_text(
        f"""# Applicant Review Packet

This packet is for human review. It intentionally does not select or submit 찬성, 반대, or 기권.

## Applicant Metadata

```json
{json.dumps(metadata, ensure_ascii=False, indent=2)}
```

## Extracted Attachments

{attachment_lines or "- No attachment PDFs were extracted."}

## JD + Rubric Placeholder

Paste or update the rubric in `{RUBRIC_PATH}` before making a final decision.

Current rubric contents:

```md
{rubric}
```

## Human Decision

- Decision: `찬성` / `반대` / `기권`
- Rationale:
- Follow-up questions:
""",
        encoding="utf-8",
    )


def main() -> None:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)

    new_tab(APPLICANTS_URL)
    wait_for_load()
    wait_until_text("단계별", timeout=20)
    sorted_ok = set_oldest_sort_if_needed()
    eligible_before_open = visible_card_eligibility_summary()
    open_first_visible_reception_card()

    metadata = page_state()
    metadata["sorted_oldest_first_confirmed"] = sorted_ok
    metadata["visible_card_eligibility_before_open"] = eligible_before_open
    applicant_name = metadata.get("guessedHeading") or "applicant"

    before_urls = set(collect_pdf_urls())
    open_attachment_cards()
    pdf_urls = collect_pdf_urls()
    if before_urls:
        # Keep URLs seen after opening this modal, but preserve any attachment already loaded
        # if this is a resumed run on the same applicant.
        pdf_urls = list(dict.fromkeys(pdf_urls))

    run_dir = RUNS_DIR / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{slugify(applicant_name)}"
    run_dir.mkdir(parents=True, exist_ok=False)

    attachments = extract_pdfs(run_dir, pdf_urls)
    metadata["pdf_count"] = len(pdf_urls)
    metadata["attachments"] = attachments
    (run_dir / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    write_review_draft(run_dir, metadata, attachments)

    print(json.dumps({"run_dir": str(run_dir), "metadata": metadata, "attachments": attachments}, ensure_ascii=False, indent=2))


main()
