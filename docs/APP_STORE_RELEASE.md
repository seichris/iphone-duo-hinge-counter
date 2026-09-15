# App Store release runbook

Prepared September 14, 2026. **This is a release-preparation pack, not a ready-to-submit binary.** The PR may be merged after its code checks pass; publication remains blocked independently. Nothing here reserves an app name, activates hosting, signs a binary, spends money, uploads to TestFlight or submits to App Review.

## What is prepared

- English candidate name, subtitle, keywords, promotional text, description and URL fields in `appstore/metadata/en-US.json`.
- Candidate version **1.0.0 (2)** and existing bundle/App Group IDs in `appstore/release.json`; the Xcode generator reads these instead of duplicating them. Increment the build number when replacing an uploaded build.
- Bundled offline Help & Support and Privacy Policy pages accessible at the top of Settings; the app displays its version/build. These use `Resources/HelpContent.json`.
- A matching generated static marketing/support/privacy site, manual GitHub Pages workflow, sourced screenshot specifications/storyboard, real-UI capture test and dimension checker.
- Draft reviewer notes, release evidence template and fail-closed preflight/archive helpers. Standard non-Duo Release builds deliberately fail at compile time; the compatibility scheme is Debug-only, not a way to submit a pretend automatic counter.
- CI selects an installed non-beta Xcode with iOS SDK 26+ instead of accepting the runner's older default. The Duo build is a distinct conditional step; unavailable SDK validation is explicitly reported as skipped.

## Blockers — do not bypass

| Gate | Required evidence before publication |
|---|---|
| Name and rights | Confirm the candidate name in App Store Connect and resolve similarity/trademark concerns. Confirm rights to all code and artwork. Do not assume a public repo has an open-source license; none has been added. |
| Duo SDK and hardware | Obtain a submission-accepted SDK; compile **Duo Debug and Duo Release**, verify public API signatures and angle convention, and test a physical device. Record closed/open angle samples, normal cycles, partial folds, screen lock, scene suspension, display handoff and missed-event behavior. A successful ordinary iPhone build or synthetic demo is not this evidence. |
| TestFlight and accessibility | Install the signed build through TestFlight. Test iPhone and iPad fallback, Duo poses/multitasking, VoiceOver, large text, contrast, Reduce Motion, corruption recovery, import/export/erase confirmations and persistence. Do not declare App Store accessibility support based only on compilation. |
| Screenshots | Capture the actual shipping UI and widget, select the correct dimensions/slots, inspect readability and coverage claims, and remove private data. Duo inner/outer screenshots cannot be manufactured from a regular simulator capture. |
| Privacy/compliance | Review the actual archive privacy report and App Store privacy questionnaire, encryption answers, age rating, required contracts and applicable regional declarations. These are account-holder decisions, not generated certifications. |
| Signing and app record | Active program membership, actual seller/account, unique registered app and extension IDs, matching App Group, distribution signing, App Store Connect app record and genuine private review contact details. |
| Pricing/storefronts | Owner selects price, availability, licenses and launch scope. No store territory, payment model or legal entity has been invented or enabled. Use manual release control. |
| Public URLs/support | Deploy and verify the exact marketing, support and privacy URLs over HTTPS, including on a phone without a login. Check issue intake is enabled and monitored. Configure a private support channel before requesting sensitive diagnostics. |

As of the research date, Apple's Duo hub says **Xcode 27.1 beta is coming later this month** [P1]. An eventual beta release does not by itself prove Apple accepts that SDK for App Store distribution. Separately, the current general upload baseline has required Xcode 26+/iOS 26 SDK since April 28, 2026 [P2]. Deployment target and SDK used to build are different; the manual-compatible deployment target can remain iOS 18 unless the validated Duo integration requires a change.

**Product gate:** decide whether foreground-only recording is valuable enough to ship. The app must observe both ends of a movement; display handoff may prevent a typical full opening from being counted. If physical testing shows this core flow cannot work reliably, stop and change the product/metadata rather than approving the gate. A wider feature list does not guarantee acceptance under minimum-functionality review [P3].

## Local verification

```sh
python3 -m unittest discover -s scripts/tests -v
python3 scripts/build_site.py --check
python3 scripts/release_preflight.py
swift test
python3 scripts/check_project.py
```

The non-strict preflight validates **draft consistency** and prints outstanding external gates. It can pass while publishing is blocked. `--archive` checks only name/rights and signing/app-record evidence for a clean current source commit, allowing a candidate to be built before TestFlight results exist. `--strict` requires a clean tracked working tree, exact current source commit, evidence for every fixed gate, actual selected PNGs in each project-required group and live HTTPS content. Evidence references are human attestations; the script cannot establish hardware accuracy, trademark rights or Apple's approval by itself.

## App Store Connect account work

Create the iOS app record using the actual seller and registered bundle identifier. Reserve the selected name; choose English (US), Utilities, the agreed price and territories. The current project builds for iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`); prepare and test iPad behavior rather than omitting its required screenshots. Never invent a private device-capability entitlement to restrict installation to Duo.

Set the public URL fields from metadata after the pages are live. Paste the reviewed description and promotional text; paste the comma-separated keyword string without repeating the name/subtitle. Record actual contact details privately in App Store Connect. Review the default Apple EULA versus any owner-provided custom agreement; do not auto-add a repository license or seller identity.

The source currently has no accounts, ads, analytics SDKs or app-operated network upload. **“Data Not Collected” is a candidate questionnaire answer, not a submitted declaration.** Reassess the complete signed binary, third-party dependencies (currently none), diagnostics actually accessible to the developer and the final support flow using Apple's definition [P4]. Browser visits/public GitHub issues and user-chosen exports are explained separately in the policy.

`PrivacyInfo.xcprivacy` currently declares no collected/tracking data and no required-reason API use. Direct source inspection found local file operations and a process-relative `ContinuousClock` duration, not direct `UserDefaults`, disk-space, file-timestamp or system-uptime API calls. Do not invent reason codes. Generate/review Xcode's archive privacy report and Apple's current API list before approving this declaration; source review alone does not validate the compiled binary [P5]. `ITSAppUsesNonExemptEncryption = false` is already set; confirm the final binary relies only on applicable OS/exempt facilities before accepting export-compliance answers [P6].

Complete the age-rating questionnaire from the actual functionality. There is no embedded open web browser, UGC feed, gambling or medical measurement in this app; an external support link is not an in-app forum. Let App Store Connect calculate the rating and review regional results. Do not select a rating simply because a competitor has it. If distributing in the EU, complete the account's actual trader/non-trader assessment and verification [P7]. For other selected markets, check the live App Store Connect compliance prompts rather than asserting universal eligibility.

## Website activation (after merge)

In this repository's Settings > Pages, choose GitHub Actions as the publishing source. Run **Publish support site (manual)** on `main`; it uploads only `site/`, not the repository or private release files. The PR does not deploy automatically. Expected URLs are:

- `https://seichris.github.io/iphone-duo-hinge-counter/`
- `https://seichris.github.io/iphone-duo-hinge-counter/support.html`
- `https://seichris.github.io/iphone-duo-hinge-counter/privacy.html`

These are intended endpoints, **not verified live URLs**. Policy edits belong in `Resources/HelpContent.json`; run `python3 scripts/build_site.py` and commit regenerated pages. Update the honest prelaunch banner and final availability link only when launch status actually changes. Do not add an App Store badge with a fabricated app ID.

## Real screenshots

Apple's inspected specification lists the Duo outer display at **1398 × 2034** and inner display at **2007 × 2853**, with reversed landscape sizes [P8]. Confirm what App Store Connect actually requests for Duo when the matching tooling becomes available. Separate Duo groups are **our quality gate**, not an assertion that Apple mandates separate slots. The specification also supplies accepted 6.9-inch iPhone and 13-inch iPad sizes; they are versioned in `appstore/screenshots.json`.

On a Mac, select a matching installed simulator UDID using `xcrun simctl list devices available`, then:

```sh
SIMULATOR_UDID=YOUR_SIMULATOR_UDID SCREENSHOT_GROUP=iphone-6.9 \
  bash scripts/capture_screenshots.sh
# For a validated Duo SDK, explicitly set CAPTURE_SCHEME='FoldCounter Duo'
# and configure the intended display/pose in Apple's Device Hub first.
```

The UI test creates three **manual** openings in isolated test storage, then attaches Today, History, Settings, Privacy and Support captures to the result bundle. It does not write the real widget snapshot. CI captures are development evidence, not an automatically uploadable screenshot set. Review images, choose originals, and copy only the selected PNGs into `.release/screenshots/<group>/`; then run `python3 scripts/check_screenshots.py`. Capture the widget separately on a signed test installation; do not fake it from the app screen. Keep raw originals and any captioned versions. Inspect pixels, not only dimensions. No screenshots have been claimed as captured or App Store approved by this runbook.

## Signed archive and submission

Keep `.release/` ignored. Copy `appstore/release-evidence.example.json` to `.release/evidence.json`. Set `source_commit` to `git rev-parse HEAD`. Record real name/rights and signing/app-record evidence first; these are the two prerequisites for creating a signed candidate. Leave the later gates false until actually verified. After TestFlight and the remaining checks, record references to actual evidence for every gate. Never mark a gate passed merely to make a command succeed; new tracked source changes invalidate prior evidence. Choose a final build number before collecting release evidence.

```sh
# Candidate archive: does NOT require TestFlight results that do not exist yet.
DEVELOPMENT_TEAM=YOUR_REAL_TEAM_ID bash scripts/archive_release.sh
# After testing that exact build and completing ALL other release evidence:
python3 scripts/release_preflight.py --strict
```

The script creates a local **Duo Release** signed archive with your existing signing setup, checks its signature and refuses to overwrite an existing archive. It does **not** upload, create credentials, submit review or release automatically. It requires genuine candidate prerequisites, the selected Duo SDK and local signing. It does not require finished TestFlight results or live public pages before a candidate can be tested. Those, hardware validation and all other gates remain mandatory in the separate strict submission check. Account-dependent identifiers can be changed in `appstore/release.json` before regenerating the project; update App Group registration for both targets. Do not pass one global `PRODUCT_BUNDLE_IDENTIFIER` override to all targets, because the widget needs its own identifier.

Open the archive in Xcode Organizer, validate it, inspect its contents/privacy report and distribute the correct build to TestFlight. Test the actual distributed build, then select it in App Store Connect, attach the verified screenshots, replace the draft heading/unverified passages in `appstore/review-notes.txt` with real test evidence, complete all required fields and submit when the owner authorizes it. Keep release manual so approval does not unexpectedly publish the app. Code signing and successful preflight do not guarantee App Review approval.

## Sources

- P1: [Duo developer hub](https://developer.apple.com/iphone-duo/); detailed API research in [RESEARCH.md](RESEARCH.md).
- P2: [Apple upcoming/submission requirements](https://developer.apple.com/news/upcoming-requirements/).
- P3: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), especially completeness, accurate metadata, actual-use screenshots, minimum functionality and accessible privacy policy.
- P4: [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
- P5: [Required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- P6: [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
- P7: [EU Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).
- P8: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
