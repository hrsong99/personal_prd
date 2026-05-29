from __future__ import annotations

import json
import re
from pathlib import Path


BATCH_DIR = Path("ninehire-browser-harness/batch_runs/20260529_100830")
POSTED_CARD_IDS = {
    "card-7c743550-4dc6-11f1-ad52-ddaac2cdd4f0",  # first 김재영 note already posted
    "card-7c74aa80-4dc6-11f1-ad52-ddaac2cdd4f0",  # first 최은미 note already posted
}

FEATURES = {
    "strong_matching": [
        "매칭 플랫폼", "스포츠 매칭", "1:1", "dating", "데이팅", "소개팅", "matchmaking", "matching platform",
        "네트워킹 매칭", "matching ux",
    ],
    "weak_recommendation": [
        "개인화 추천", "추천 알고리즘", "맞춤 추천", "recommendation", "personalized recommendation",
    ],
    "core_monetization": [
        "유료 회원 전환", "구매 전환율", "결제 전환", "첫 결제 전환", "전환율", "conversion", "페이월",
        "paywall", "구독", "subscription", "premium", "프리미엄", "arpu", "ltv", "수익화", "revenue",
    ],
    "data_hypothesis": [
        "가설", "hypothesis", "a/b", "ab test", "데이터", "data", "analytics", "googleanalytics", "ga4",
        "리서치", "interview", "user research", "survey", "사용성", "usability", "로그", "지표",
    ],
    "senior_product": [
        "pm", "product", "프로덕트", "기획", "문제 정의", "설계", "리드", "lead", "owner", "ownership",
        "strategy", "roadmap", "ia", "user flow", "wireframe",
    ],
    "design_system": [
        "디자인 시스템", "design system", "component", "컴포넌트", "library", "토큰", "스타일가이드", "style guide",
    ],
    "gamification": [
        "게임", "game", "gamification", "게이미피케이션", "reward", "리워드", "challenge", "챌린지", "quest", "streak",
    ],
    "ai_tools": [
        "ai", "midjourney", "cursor", "v0", "생성형", "generative",
    ],
    "engineering": [
        "frontend", "front-end", "html", "css", "javascript", "react", "개발", "구현", "qa", "handoff",
    ],
}


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).lower()


def has_any(text: str, terms: list[str]) -> bool:
    lower = normalize(text)
    return any(term.lower() in lower for term in terms)


def build_evidence_summary(flags: dict[str, bool], years: int | None) -> str:
    evidence = []
    if years:
        evidence.append(f"{years}+ years of experience signal")
    if flags["strong_matching"]:
        evidence.append("direct matching-platform / 1:1 matching keyword signal")
    elif flags["weak_recommendation"]:
        evidence.append("personalization/recommendation signal, not necessarily 1:1 matching")
    if flags["core_monetization"]:
        evidence.append("conversion, subscription, paywall, or revenue keyword signal")
    if flags["data_hypothesis"]:
        evidence.append("data, research, hypothesis, A/B test, or usability keyword signal")
    if flags["senior_product"]:
        evidence.append("product planning, UX structure, or ownership keyword signal")
    if flags["design_system"]:
        evidence.append("design system or component keyword signal")
    if flags["gamification"]:
        evidence.append("gaming, gamification, challenge, or reward-loop keyword signal")
    if flags["engineering"]:
        evidence.append("implementation or engineering-collaboration keyword signal")
    return "; ".join(evidence[:4]) if evidence else "no strong keyword evidence found in extracted text"


def detect_years(text: str) -> int | None:
    candidates = []
    patterns = [
        r"(?:총\s*경력|경력\s*총|총)\s*(\d{1,2})\s*년",
        r"(?<!\d)(\d{1,2})\s*년\s*(\d{1,2})?\s*개월",
        r"(?<!\d)(\d{1,2})\+?\s*years?",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.I):
            value = int(match.group(1))
            if 1 <= value <= 25:
                candidates.append(value)
    return max(candidates) if candidates else None


def strict_note(applicant: str, text: str) -> tuple[int, str]:
    years = detect_years(text)
    flags = {name: has_any(text, terms) for name, terms in FEATURES.items()}

    score = 20
    positives: list[str] = []
    concerns: list[str] = []

    if years and years >= 5:
        score += 8
        positives.append(f"seniority signal: about {years}+ years appears in the documents")
    elif years and years >= 3:
        score += 5
        positives.append(f"meets the minimum 3+ years requirement ({years}+ years signal)")
    else:
        concerns.append("3+ years UI/UX experience is not clearly proven in extracted text")

    if flags["strong_matching"]:
        score += 18
        positives.append("direct matching / 1:1 / matching-platform signal appears")
    elif flags["weak_recommendation"]:
        score += 7
        positives.append("weaker recommendation/personalization signal appears, but not necessarily 1:1 matching")
    else:
        concerns.append("no clear 1:1 matching/dating/recommendation UX evidence")

    if flags["core_monetization"]:
        score += 18
        positives.append("conversion/subscription/paywall/revenue signal appears")
    else:
        concerns.append("no clear paywall/subscription/payment-conversion ownership")

    if flags["data_hypothesis"]:
        score += 12
        positives.append("some data/research/hypothesis signal appears")
    else:
        concerns.append("hypothesis-driven or metric-driven product decision evidence is weak")

    if flags["senior_product"]:
        score += 10
        positives.append("product planning / UX structure / ownership signal appears")
    else:
        concerns.append("strategic product ownership is not strongly visible")

    if flags["design_system"]:
        score += 7
        positives.append("design system/component signal appears")

    if flags["gamification"]:
        score += 5
        positives.append("gaming/gamification/reward-loop signal appears")

    if flags["ai_tools"]:
        score += 3
        positives.append("AI-tool signal appears")

    if flags["engineering"]:
        score += 4
        positives.append("implementation/engineering collaboration signal appears")

    exact_core = flags["strong_matching"] and flags["core_monetization"]
    exceptional_signals = sum(flags[k] for k in ["data_hypothesis", "senior_product", "design_system", "gamification", "engineering"])

    if exact_core and exceptional_signals >= 3:
        score = min(score, 88)
    elif exact_core:
        score = min(score, 82)
    elif flags["core_monetization"] and (flags["weak_recommendation"] or exceptional_signals >= 3):
        score = min(score, 76)
    elif flags["core_monetization"] or flags["strong_matching"]:
        score = min(score, 70)
    elif flags["weak_recommendation"] and exceptional_signals >= 2:
        score = min(score, 66)
    else:
        score = min(score, 62)

    if years is None or years < 3:
        score = min(score, 58)

    score = max(30, score)

    if score >= 82:
        tldr = "Strong strict-fit signal, but still needs human review for depth and actual ownership."
    elif score >= 70:
        tldr = "Potentially relevant, but not a clear high-confidence fit under the stricter bar."
    elif score >= 55:
        tldr = "Partial fit; useful UI/UX signal, but core JD/rubric evidence is incomplete."
    else:
        tldr = "Weak strict-fit signal from the extracted documents."

    positives_text = "; ".join(positives[:3]) if positives else "No strong differentiating signal found in extracted text"
    concerns_text = "; ".join(concerns[:3]) if concerns else "Need human review to validate depth, ownership, and outcomes"
    evidence_text = build_evidence_summary(flags, years)

    note = (
        f"TLDR: {tldr}\n"
        f"Strict estimated match: {score}%\n\n"
        f"- Evidence: {evidence_text}.\n"
        f"- Strong signals: {positives_text}.\n"
        f"- Main concerns: {concerns_text}."
    )
    return score, note


def main() -> None:
    rows = []
    for metadata_path in sorted(BATCH_DIR.glob("*/metadata.json")):
        metadata = json.loads(metadata_path.read_text())
        card_id = metadata["card"]["cardId"]
        texts = []
        for attachment in metadata.get("attachments", []):
            path = Path(attachment["cleaned_text"])
            if path.exists():
                texts.append(path.read_text(errors="ignore"))
        score, note = strict_note(metadata["applicant"], "\n".join(texts))
        strict_path = metadata_path.parent / "team_chat_note.strict.txt"
        strict_path.write_text(note + "\n", encoding="utf-8")
        metadata["strict_estimated_match"] = score
        metadata["strict_team_chat_note"] = note
        metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        rows.append(
            {
                "dir": metadata_path.parent.name,
                "applicant": metadata["applicant"],
                "cardId": card_id,
                "strict_estimated_match": score,
                "posted_previously": card_id in POSTED_CARD_IDS,
                "note": str(strict_path),
            }
        )

    index = ["# Strict Batch Notes", "", "| # | Applicant | Strict match | Posted previously | Note |", "|---:|---|---:|---|---|"]
    for i, row in enumerate(rows, 1):
        index.append(
            f"| {i} | {row['applicant']} | {row['strict_estimated_match']}% | {row['posted_previously']} | `{row['note']}` |"
        )
    (BATCH_DIR / "strict_batch_index.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    print(json.dumps(rows, ensure_ascii=False, indent=2))


main()
