# Repository guidance

- Read docs/RESEARCH.md before touching hinge capture, background behavior, or feature claims.
- No screen-size/orientation heuristics, private APIs, invented sensor/history APIs, or unrelated background modes.
- DUO_HINGE_API is an explicit SDK integration gate. Do not remove the gate without a successful new-SDK build and evidence of runtime behavior.
- One app-wide model; one active sensor leader; no counting across observation discontinuities.
- Write the authoritative archive before publishing state. Widgets are read-only snapshot consumers, not a second writer.
- A damaged file is an error, never a reason to silently replace history with zero.
- Keep demo/UI-test data isolated. Never seed fake counts into the normal counter or widget.
- Core changes need Swift tests, including temporal/lifecycle edge cases. Run swift test and generate/check the Xcode project. Report exactly which SDK builds were actually executed.
- Preserve manual-versus-observed attribution, explicit destructive confirmations, and the foreground-only UI disclosure.
- Do not add a license, tracking, cloud account, or analytics without an explicit product decision.
