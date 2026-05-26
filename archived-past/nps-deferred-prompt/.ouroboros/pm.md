# Deferred NPS Prompt

*Created At: 2026-04-28T10:17:02.171316+00:00*

## Goal

Lift NPS survey reach from ~7% to 50%+ of real PODO classes (7× lift) by showing a deferred NPS prompt on /home after a recently-attended class, catching the ~93% of classes missed because users don't click the in-flow '나가기' button.

## User Stories

1. **As a** Student who closed the app mid-class or used OS back, **I want to** See an NPS prompt for my recently-completed class when I next open the app and land on /home, **so that** I can provide feedback on my class experience without needing to follow the exact post-class in-flow exit path.
2. **As a** Student who took multiple classes before reopening the app, **I want to** See an NPS prompt only for the most recently-finished eligible class, **so that** I'm not overwhelmed with back-to-back survey prompts for older classes.
3. **As a** Student mid-checkout or on a blocked screen, **I want to** Not be interrupted by an NPS prompt until I navigate to /home, **so that** My critical flows (payment, booking, onboarding) are never disrupted.
4. **As a** Student who doesn't want to rate a class, **I want to** Tap an explicit '평가하지 않고 나가기' text link to permanently dismiss the prompt for that class, **so that** I'm not repeatedly asked about a class I don't want to rate, and the system respects my choice.
5. **As a** PM / Analytics team, **I want to** Measure NPS reach as (submitted + explicit skip) / total real classes over a 14-day window, **so that** We can track whether the deferred prompt meaningfully closes the feedback gap and detect self-selection bias.

## Constraints

- Prompt displays ONLY on the /home page — hook mounts exclusively in the /home page or a layout wrapping only /home, not in the global app shell
- Blocked screens: never show on classroom URL, login, onboarding, payment, checkout, /my-podo, /reservation, or any non-/home route
- Never show while a modal/overlay is open on /home — use existing global overlay state (overlay.isOpen()); queue prompt and watch for overlay.isClosed before showing
- Never show if user has a class starting in < 10 minutes
- Session cap: 1 deferred prompt per app session, consumed only by explicit user action (Submit score OR Skip button press); silent dismissals (nav-away) do NOT consume the cap
- Class cap: 1 deferred prompt per class total (enforced by nps_skip or nps_response row)
- Priority: most recently-finished eligible class only; older eligible classes are silently abandoned (fall out of 24h window)
- Eligibility window: class scheduled end must be in the past AND within last 24 hours
- Eligibility requires: real PODO class (not prestudy/AI), student owner, not canceled/no-show, attendance signal present, no prior NPS response row, no prior NPS skip row
- Attendance signal uses OR semantics: `meet_connected` event (or `meet_participant_joined` count ≥ 2) for this class, OR CLASS_STATE='FINISH'. If either is true, the class is eligible. If BOTH are missing, the class is NOT eligible (better to miss than to ask someone who didn't attend).
- `meet_connected` is REQUIRED at launch — not deferred to v2 — because tutor manual completion lag is the dominant case (median 1 min, average ~9 min, long tail to hours). Without `meet_connected`, the deferred prompt would silently miss any user who foregrounds the app before the tutor presses complete, which is most of the target cohort. Implementation must include the attendance mirror table (or equivalent cheap query path) before client launch.
- CLASS_STATE='FINISH' is the secondary OR-branch (belt-and-suspenders) for the rare case where the `meet_connected` event was lost in transit but the tutor did mark complete.
- API call strategy: cache getPendingNps result once per session; invalidate cache on attention-regain (native background→active postMessage OR Page Visibility API visibilitychange hidden→visible); re-call on next /home mount after invalidation; no API call on plain in-app tab bouncing while /home stays visible
- Nav-away while prompt is visible: dismiss silently — no skip row written; class stays eligible and re-prompts on next /home return within the same session
- Re-show after silent dismiss: prompt re-appears on every /home return within the session until session cap is consumed by an explicit action
- Cold start (app killed → fresh open) triggers the same flow as background→foreground — hook mounts on /home regardless of how user arrived
- No lower-bound buffer on attendance signal — trigger immediately at now >= class_end, trust signal lands in seconds
- getPendingNps latency budget: 100ms p95
- Error rate on getPendingNps and /nps/skip: < 1%
- Reuses existing /review-complete page with ?source=deferred query param
- NPS title copy changes from '오늘 레슨, 어떠셨나요?' to '이번 레슨, 어떠셨나요?' on BOTH paths (in-flow and deferred) — single canonical copy. Subtitle '솔직한 평가는 더 좋은 레슨을 만드는 데 큰 힘이 돼요.' stays unchanged.
- New tutor context card rendered below the subtitle on BOTH paths. Layout: a pill/card containing an avatar circle on the left and stacked text on the right (tutor name on top, class date/time below). Example: avatar 'A' (orange background, white letter) + 'Alice' + '4월 26일 11:00'.
- Avatar fallback rule: until real profile photos are available, the avatar is the first character of the tutor's display name on a solid orange circle with white text. Works for both English names (Alice → 'A') and Korean names (김철수 → '김'). When real profile photos exist later, the photo replaces the initial; this is a v1 fallback.
- Date/time shown in the card use the class start time in KST, formatted as '{M}월 {D}일 {HH}:{MM}'.
- Tutor name, tutor profile (when available), and class start datetime must be available to the /review-complete page. The existing data fetch may not include all of these — verify and extend the API as needed (the new getPendingNps response already returns tutor_name and class_end_datetime_unix; class_start_datetime should be added).
- Skip button: rendered as a tertiary text link at the bottom of the page (NOT a gray button under the primary CTA). Copy: '평가하지 않고 나가기'. Tapping it writes a row to nps_skip via POST /api/v1/lesson-review/nps/skip, closes the prompt, consumes the session cap, and clears the cross-tab lock. Class is permanently retired from eligibility.
- Skip destination routing: the in-flow path's existing `getReturnUrl(referrer)` logic is preserved unchanged for in-flow (`reserved` → `/reservation`, `home` → `/home`, `lesson-list`/`booking`/default → `/subscribes`, `ai-home` → `/home/ai`). For the deferred path, add a new branch `case 'deferred': return '/home'` (or treat `?source=deferred` as a referrer override that maps to `/home`) — since /home is the origin of the deferred prompt, skip should return the user to /home, not to /subscribes (the default fallback).
- Cross-tab coordination: only one NPS surface (deferred prompt OR /review-complete) may be active for a given classId across all open tabs. Implemented via BroadcastChannel (preferred) with localStorage fallback. When any tab opens an NPS surface, it broadcasts/writes `nps_prompt_active:{classId}={timestamp}` with a 60-second TTL (handles tab crashes). Other tabs read this before showing their own surface and suppress if set. On submit/skip/explicit close, the lock is cleared.
- /review-complete in-flow path respects the cross-tab lock: when the user clicks '나가기' on the classroom page, the existing isClassEnded gate also checks the cross-tab lock. If another tab is actively rating this class, route directly to /home instead of /review-complete — silent reroute, no intermediate "rating elsewhere" page.
- Multi-tab simultaneous-display prevention: if a deferred prompt is visible on /home tab and the user opens /review-complete on another tab, /review-complete sees the lock and routes itself away to /home. If /review-complete mounts first and the user later switches focus to /home, /home sees the lock and suppresses the deferred prompt.
- Rollout: backend deployed first, then client behind feature flag tbd_260X_nps_deferred_prompt, 100% on launch (no ramp); kill switch = flag off

## Success Criteria

1. Primary: NPS reach (submitted + explicit skip) / total real PODO classes ≥ 50% within a 14-day window, measured within first 30 days post-launch (vs ~5.3% submission baseline)
2. Secondary: Deferred-path skip rate not meaningfully higher than in-flow skip rate
3. Secondary: Deferred-path average NPS rating not meaningfully different from in-flow average rating
4. Secondary: No /home p95 latency regression beyond getPendingNps 100ms budget
5. Secondary: Error rate on getPendingNps and /nps/skip < 1%
6. Secondary: Submitted / total real classes (apples-to-apples comparison vs current baseline, since explicit-skip tracking is new)

## Assumptions

- Most users foreground the app within 24h of their class, so the 'most recent only, others abandoned' policy will not significantly erode the 50% reach target
- Most sessions touch /home, so scoping the hook to /home only (rather than a broader safe-screen list) provides sufficient coverage
- Attendance signal (meet_connected or CLASS_STATE='FINISH') lands within seconds of class end — no multi-minute lag expected
- The existing global overlay/modal state (overlay.isOpen() / overlay.isClosed) is reliable and comprehensive enough to gate prompt display
- The existing /review-complete page can be reused as-is with a ?source=deferred query param to distinguish the deferred path
- The denominator for reach metric (all real PODO classes where student+tutor both joined, not canceled, not no-show) is a stable and queryable dataset
- Current NPS reach baseline is ~7% (~1,248 / 16,778 real classes over 14 days)
- BroadcastChannel API is available in target browsers; localStorage fallback covers any gaps
- Web is the only platform where multi-tab races occur — native WebView is single-surface, so the lock is web-only but harmless if read on native

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- If post-launch analytics shows non-trivial misses due to attendance signal lag, revisit adding a soft client-side retry or grace buffer
- Exact feature flag name (placeholder: tbd_260X_nps_deferred_prompt)
- Avatar treatment when real tutor profile photos are available (current v1: first-character orange circle)
- Showing NPS for more than one class per session (back-to-back surveys rejected in favor of simplicity)
- Recovering older eligible classes that are abandoned when a more recent class takes priority
- Gradual rollout ramp — launching at 100% behind flag, no percentage ramp
- Showing the deferred prompt on screens other than /home (e.g., /my-podo, /reservation)

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260428_095339*
*Interview ID: interview_20260428_095339*
