# BYPT Calculator — Business Requirements Document (BRD)

## 1. Overview
- **Purpose**: Deliver a modern calculator for mobile and web with scientific functions and persistent history.
- **Platforms**: Android, iOS, Web (Chrome/Edge/Safari latest).
- **Stakeholders**: Product Owner, Engineering, QA, Design.

## 2. Goals & Non‑Goals
- **Goals**:
  - Provide reliable basic and scientific calculations.
  - Offer an intuitive, delightful UI with responsive layouts.
  - Persist calculation history locally with quick restore.
- **Non‑Goals**:
  - Graphing calculator features.
  - Cloud sync of history across devices.
  - Advanced programming features (variables, custom functions).

## 3. Personas
- **Casual User**: Needs quick everyday arithmetic with history recall.
- **Student/Pro**: Uses scientific keys (sin, cos, tan, log, ln, sqrt, power, π, e).

## 4. Scope
- **In Scope**:
  - Basic operations: +, −, ×, ÷, %, parentheses, decimal.
  - Scientific: sin, cos, tan, log, ln, sqrt, ^, π, e.
  - History: append on evaluate, list view, tap‑to‑restore, clear all.
  - Responsive UI: stacked (mobile) and sidebar/card (web/desktop).
  - Local persistence using `shared_preferences`.
- **Out of Scope**:
  - Multi-line programming mode, variables, unit conversion.
  - Multi-language i18n (Phase‑2 candidate).
  - Cross‑device history sync.

## 5. User Stories & Acceptance Criteria
- **US1**: As a user, I can perform basic arithmetic operations.
  - AC: Tapping keypad updates expression; pressing = shows correct result.
- **US2**: As a user, I can use scientific functions.
  - AC: Scientific keys insert valid tokens; evaluation returns correct numeric results.
- **US3**: As a user, I can see previous calculations in a history drawer.
  - AC: After evaluate, a history card with expression/result/timestamp appears at top.
- **US4**: As a user, I can tap a history item to restore it into the calculator.
  - AC: Expression/result fields update and the drawer closes.
- **US5**: As a user, I can clear my entire history.
  - AC: Clear action empties history list and local storage; shows "No history yet".
- **US6**: As a web user, I see a centered card layout with consistent spacing.
  - AC: On web, content is constrained to a max width and visually centered.

## 6. Functional Requirements
- **FR1**: Expression input composed by on‑screen keys or keyboard (desktop/web).
- **FR2**: Parsing/evaluation via `math_expressions` with normalization of `%` → `/100`.
- **FR3**: Number formatting trims trailing zeros; avoids spurious `.0`; supports scientific notation.
- **FR4**: History (max 100 items) stored as JSON in `shared_preferences` under `calc_history_v1`.
- **FR5**: Avoid consecutive duplicate history entries (refresh timestamp instead).
- **FR6**: History drawer opens from AppBar icon; supports clear all.
- **FR7**: Scientific panel toggles via AppBar icon.

## 7. Non‑Functional Requirements
- **NFR1**: Performance: Evaluate typical expressions in < 50 ms on mid‑range devices.
- **NFR2**: UX: 60 fps animations for panel reveal and list interactions.
- **NFR3**: Accessibility: Sufficient color contrast; large tap targets; semantic icons.
- **NFR4**: Privacy: All data stored locally only; no PII collected or transmitted.
- **NFR5**: Reliability: Gracefully handle invalid expressions (show "Error").
- **NFR6**: Maintainability: Widget tests cover core flows; CI-capable.

## 8. UX & Interaction Requirements
- AppBar: logo, history icon, scientific toggle.
- Mobile layout: display → animated scientific panel → basic pad.
- Wide layout: optional left scientific sidebar; main area with display + basic pad.
- Web: center within card (rounded corners, soft elevation).
- History drawer: list with expression (2 lines max), result, and timestamp label.

## 9. Data Model
- History item: `{ expression: string, result: string, ts: epochMs }`.
- Storage key: `calc_history_v1` (List<String> JSON‑encoded).

## 10. Error Handling
- Invalid parse/evaluate → result displays `Error` and no history entry is recorded.
- Division by zero → `Error`.

## 11. Dependencies
- Flutter/Dart (3.x), `math_expressions`, `shared_preferences`, `flutter_native_splash`.

## 12. Analytics/Telemetry (Optional/Future)
- Local only in v1. Future: add usage metrics with explicit consent.

## 13. Localization (Future)
- Phase‑2: add i18n for labels and number formatting locales.

## 14. Security & Privacy
- No network calls; local storage only.
- Users can clear all history at any time.

## 15. Milestones
- M1: MVP basic calculator + tests.
- M2: Scientific functions + UI polish.
- M3: History drawer + persistence + tests.
- M4: Web card layout + responsive refinements.

## 16. Acceptance Test Plan (High Level)
- Verify arithmetic correctness.
- Verify formatting for decimals and large numbers.
- Verify scientific functions with known inputs (e.g., sin(0) = 0).
- Verify history append, restore, and clear flows.
- Verify web centered layout and mobile flow unchanged.
- Run full `flutter test` suite passes.

## 17. Risks & Mitigations
- Parsing limitations → Clear error handling; rely on upstream lib updates.
- UX inconsistency across platforms → Platform-adaptive theming and responsive rules.
- Local storage corruption → Robust JSON parsing with safe fallbacks.

## 18. Assumptions
- Users accept local‑only history in v1.
- Network access not required.

## 19. Open Questions
- Add per‑item delete in history?
- Persist scientific panel state across launches?
- Copy/share results from history?
