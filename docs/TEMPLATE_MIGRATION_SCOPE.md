# Template Migration Scope

## Goal
- Preserve current product behavior (`functional parity = 100%`).
- Migrate UI/UX to flutter template patterns with measurable coverage (`>= 80%` of key screens).
- Stop endless polishing by locking scope and explicit Done criteria.

## Non-Goals
- No feature creep.
- No logic rewrites without regression need.
- No redesign experiments outside template components.

## Fixed Scope
1. UI foundation
- Single token system (spacing/radius/type/colors/states).
- Reusable primitives only: cards, buttons, chips, fields, tabs, page scaffold, loading/error/empty.

2. App shell
- Unified app bars, safe areas, list paddings, bottom navigation behavior.

3. Reports list
- Template tabs/search/cards/states.
- State logic moved out of view into controller layer.

4. Report editor
- Split into controller/view blocks.
- Keep media/tags/VIN/test-drive logic intact.

5. Inspection/media
- Template-level visual consistency for groups/cards/overlays.
- No behavior changes for gallery selection, notes, and tagging.

6. Company mode
- Keep exactly 3 tabs: reports, staff, profile.
- Reuse the same template primitives and screen scaffold.

## Prioritized Delivery Plan
1. Reports list and shell hardening
- Status: in progress.
- Exit: controller-based state, no regression in create/open/delete draft flow.

2. Report editor architecture split
- Status: in progress.
- Exit: shell and navigation orchestration isolated from screen body.

3. Section-by-section template alignment
- Vehicle -> Params -> Docs -> Legal -> Inspection -> Test Drive -> Summary.
- Exit: each section uses shared primitives; no local one-off widgets unless justified.

4. Company screens alignment
- Exit: shared scaffold and states across all company screens.

5. Regression gate and freeze
- Exit: all checks green, manual smoke passed, no open P1/P2.

## Definition of Done
1. Automated checks
- `flutter analyze` passes.
- `flutter test` passes.

2. Manual smoke flows
- Create draft -> fill sections -> open inspection -> add media -> add note -> summary.
- Reopen draft after restart.
- Company flow: create report, assign staff, open staff details.

3. Coverage target
- >= 80% key screens mapped to template primitives.

4. Freeze rule
- After reaching coverage and passing smoke: only bug fixes, no UX drift.

## Screen Matrix
- Reports list: `in progress` (controller introduced, template tabs/cards active).
- New report screen: `pending`.
- Report editor shell: `in progress`.
- Vehicle: `pending`.
- Params: `pending`.
- Docs check: `pending`.
- Legal: `pending`.
- Inspection groups: `in progress`.
- Inspection media grid: `in progress`.
- Test drive: `pending`.
- Summary: `pending`.
- Company reports: `pending`.
- Company staff: `pending`.
- Company profile: `pending`.

## Rules During Migration
- Every UI change must reuse existing template primitives first.
- If a new primitive is needed, add it once in shared UI, then reuse.
- No section starts before previous section has analyze/test green.
