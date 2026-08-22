# Stage 21 — third-person playtest gate

## Build and route

- Launch `res://tests/visual/third_person_locomotion_course.tscn` for the focused course.
- Then play the Ashen Grove for 10–15 minutes with keyboard/mouse or a gamepad.
- Course order: camera wall → dodge wall → columns → low ceiling → slope → stairs → finish marker.
- Controls: `Space/A` jump, `Shift/L3` sprint, `Alt/B` dodge, `V/D-pad Up` swap shoulder.

## Pass criteria

- No camera clipping, persistent jitter, surprise zoom, or loss of the player silhouette.
- Jump buffering and coyote time feel forgiving without creating double jumps.
- Sprint, jump, and dodge all visibly consume the same stamina pool.
- Dodge never crosses the authored wall.
- The player can finish the course on both input types without rebinding due to discomfort.
- Median comfort score is at least 4/5, and fewer than half of testers request a control change.

## Session log

Do not pre-fill results. Record one row immediately after each external session.

| # | Tester | Input | Finished | Comfort 1–5 | Changed controls? | Camera defect | Notes |
|---:|---|---|---|---:|---|---|---|
| 1 |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |
| 7 |  |  |  |  |  |  |  |
| 8 |  |  |  |  |  |  |  |
| 9 |  |  |  |  |  |  |  |
| 10 |  |  |  |  |  |  |  |

## Gate result

- Status: **awaiting external sessions**.
- Engineering regression: run `tests/qa/third_person_locomotion_course_test.gd`.
- Close the gate only after all ten rows are based on real play sessions.

