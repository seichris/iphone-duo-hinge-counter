# App Store search and web SEO research

Research date: **September 14, 2026**. Scope: English-language launch, primarily US/UK; physical foldable-phone opening counters, not poker, origami, knitting or general screen-time apps.

## Decision

Position this as a **private record of observed openings**, not a hardware odometer. Lead with the descriptive product phrase **hinge counter**, use **fold counter** and **unfold** as complementary search terms, and show history/widgets as the supporting value. Do not compete on a 24/7 claim the product cannot deliver. Candidate metadata lives in [`appstore/metadata/en-US.json`](../appstore/metadata/en-US.json); it is a proposal, not a reserved App Store name or trademark clearance.

| Field | Candidate | Characters / limit |
|---|---|---:|
| Name | Hinge Counter: Opening Tracker | 30 / 30 |
| Subtitle | Daily Stats & Widgets | 21 / 30 |
| Keywords | unfold,foldable,opens,tally,usage,history,offline,private,chart,backup,export,screen,log | 88 / 100 |

The promotional text and opening description should sell clarity, while the first visible description section explains foreground-only coverage. The app, public website, screenshots and review notes must tell the same story.

## Method and limits

Reviewed the linked Android app, other publishers' live store listings, Apple search guidance and current search-engine results. Queries included `fold counter foldables app unfold counter hinge tracker`, `site:apps.apple.com "fold counter"`, `site:apps.apple.com "unfold counter"`, `"fold counter" "iPhone"`, `"iPhone Duo" "fold counter"`, `"iPhone Duo" "counter" app`, `"fold counter" "not counting"` and `site:play.google.com/store/apps/details "Fold Counter"`.

These are public web searches, **not authenticated App Store search results or keyword-volume measurements**. No Apple Ads popularity, App Store Connect analytics, search impressions, keyword difficulty or conversion data was available. No provider supplying that account data was found in the available integration search. Do not turn the priorities below into invented monthly search volumes or claim a first-to-market position. Recheck native US/UK App Store results and name availability in the owner's account before reserving the name.

The App Store web results inspected surfaced general tally utilities and unrelated “fold” uses such as poker and puzzle apps; they did not establish an existing direct iPhone Duo physical-opening counter. This is a limited search observation, not proof there are no competitors. The generic name also creates a differentiation/name-clearance risk.

## Primary-source competitor evidence

Store descriptions are publishers' claims; features were not tested on those devices. Listings can change after the research date.

| Product | Evidence and positioning | Consequence for our launch |
|---|---|---|
| TMC Apps — Fold Counter for Foldables [C1] | Daily, average and recorded total counts; offline/no-account positioning. Listing and developer replies discuss background undercounting. Listing updated August 24, 2026. | Strong relevance for “fold counter”; foreground coverage must be disclosed before download, not buried in help. Do not copy its wording, name extension or graphics. |
| MATLOOB — Unfold Counter [C2] | Daily/total/average counts, annual projection, duration, hinge angle and widgets. Listing updated January 25, 2026. | “Unfold” is useful vocabulary. Do not advertise duration or projections; this app does not implement them. |
| Roovie — Fold Counter [C3] | Another publisher uses the same generic name; listing contains ads. | Descriptive clarity alone is not a distinctive brand or proof the name can be reserved. |
| Flip & Fold Counter (Samsung) [C4] | Uses Samsung Routines and explicitly describes interference with the currently open app. Listing updated July 22, 2026. | Setup/friction and observation limits are important. Android routines are not evidence of an equivalent iOS automation trigger. |
| FoldMeter – Fold Counter [C5] | Emphasizes readable counts and full open/close cycles. | Large totals are a category expectation, not a unique benefit by themselves. |
| FoldTracker for foldables [C6] | Markets daily limits, notifications, trends and longer-term statistics. | Do not add unsupported “alerts” or “daily limits” keywords just to match a competitor. |
| Iconfactory — Clicker [C7] | A general manual tally app with watch support. | “Counter” alone attracts a broad audience with a different job. Our listing must immediately identify phone openings. |

## Prioritized keyword map

**Priority is a product-fit judgment, not measured volume or difficulty.** “Evidence” means category wording in a primary listing; “hypothesis” means a plausible query that needs native-store/analytics validation. Hardware-specific phrases belong naturally on the web page and in compatibility prose, not trademark-stuffed App Store keyword fields.

| Priority | Query / cluster | Intent | Evidence basis | Placement / decision |
|---|---|---|---|---|
| P1 | hinge counter | Find a hinge-opening utility | Our product wording; query hypothesis | Name; landing-page subject |
| P1 | unfold counter | Count device openings | C2 | Keyword `unfold` + title `counter` |
| P1 | fold counter for iPhone Duo | Device-specific utility | Hardware + C1; query hypothesis | Web title/H1 and compatibility prose |
| P1 | iPhone Duo opening counter | Device-specific recording | Hardware; query hypothesis | Landing page body, not hidden trademark stuffing |
| P1 | foldable phone counter | Category utility | C1, C2, C5 | Keyword `foldable`; description |
| P1 | daily fold count | Daily usage curiosity | C1, C2 | Subtitle + screenshots |
| P1 | fold counter widget | See totals without opening app | C2 | Subtitle; screenshot 3 after real capture |
| P1 | fold history | Review prior days | C1, C6 | Keyword; history screenshot |
| P2 | unfold tracker | Track repeated openings | C2; wording hypothesis | Keyword/title combination to test |
| P2 | phone opening tracker | Clarify the event counted | C1; wording hypothesis | Name/description; explain not unlock tracking |
| P2 | hinge counter | Hardware-oriented counter | C2; wording hypothesis | Keyword; no health claim |
| P2 | fold usage statistics | Understand patterns | C1, C6 | Subtitle/body; only recorded observations |
| P2 | private fold counter | Avoid data collection | C1 | Keyword and privacy section |
| P2 | offline fold counter | No connection needed | C1 | Keyword/body |
| P2 | fold counter backup | Preserve existing records | Our implemented feature; hypothesis | Keyword/body/support |
| P2 | export fold history | Obtain personal data | Our implemented feature; hypothesis | Keyword/body/support |
| P2 | fold counter not counting | Troubleshoot undercounting | C1 reviews/replies | Support FAQ; explain iOS limits, not Android battery steps |
| P2 | does fold counter work in background | Evaluate coverage | C1, C4 | Direct FAQ with an honest negative answer for this version |
| P3 | daily opening average | Summary statistics | C1, C2 | Description; explain denominator |
| P3 | how many times have I opened my phone | Natural-language discovery | C1; query hypothesis | FAQ; distinguish folds from screen unlocks |
| Exclude | hinge health / remaining fold life | Diagnose durability | Unsupported | Never a feature/keyword claim |
| Exclude | lifetime hardware folds / pre-install count | Recover device lifetime | Unsupported | Explain absence; never claim capability |
| Exclude | screen time / unlock counter | Track time or unlocks | Different task | Do not target as a functionality claim |
| Exclude | Samsung / Galaxy / Pixel / competitor names | Other products/platforms | C1–C6 | Research only; omit from store metadata |
| Exclude | 24/7 automatic counter | Always-on observation | Not supported | Negate clearly in description/support |

US and UK English do not require different functional vocabulary for this initial set. That is an editorial judgment, not evidence of equal demand. Start with en-US metadata and English UI; only create additional localizations when translated UI, help and screenshots are reviewed together. Do not promise Chinese, German or another language the binary does not provide.

## App Store optimization versus web SEO

Apple identifies title, subtitle, keywords and categories among text-relevance signals, alongside behavior such as downloads and reviews [A1]. Its keyword guidance excludes irrelevant/unauthorized trademark terms and repetition of title/subtitle/category words. Promotional text does not affect search ranking. The validator checks lengths and obvious duplicate/trademark stuffing; it is not Apple's ranking algorithm.

For this project, prefer a clear description over keyword repetition. Choose **Utilities**; no secondary category is necessary without a genuine second use. We deliberately omit price and “free” claims because the owner has not selected a business model. Do not use fake ratings, awards, install counts or a pretend App Store badge.

The proposed web destination is a GitHub Pages project site. `site/index.html` targets the narrower device-specific query, with a canonical URL, descriptive title, crawlable HTML and Open Graph text. The support page answers coverage and widget questions. Privacy copy is generated from the same JSON bundled in the app, preventing conflicting claims. There are no thin location pages or fabricated reviews. The site clearly says it is not yet on the App Store.

`site/sitemap.xml` can be submitted after deployment. A project-path `robots.txt` is **not** the origin's `/robots.txt`; do not assume it controls crawling of the whole `seichris.github.io` origin. A later custom domain requires updating the canonical base, metadata URLs and bundled links together, then regenerating the site. No domain purchase or hosting activation was performed.

## Conversion and measurement plan

Start the screenshot sequence with the benefit and coverage limitation together, then history, widget snapshots, data controls and privacy. Capture real UI; retain manual/observed attribution. Never turn simulator demo values into a fake live hinge reading or stretch an ordinary iPhone image into a Duo screenshot. The exact storyboard and sourced dimensions are in `appstore/screenshots.json`.

After release, establish a baseline with App Store Connect impressions, product-page views, downloads and conversion filtered by App Store Search and territory [A1]. Keep the definition/date range stable and separate paid traffic where available. Use Apple Ads keyword suggestions/popularity only as account-derived evidence, not an absolute volume estimate. No advertising campaign or budget is authorized by this plan.

For an initial experiment, compare a count-led versus history-led first screenshot. Apple's Product Page Optimization supports icon/screenshot/preview variants; it is **not a simultaneous title/subtitle A/B test** [A2]. Change title/subtitle/keywords deliberately with a version and annotate the date; small traffic means noisy results. No promised uplift or arbitrary minimum sample size. Use Search Console for web query/impression evidence after the public site is verified. Do not add an analytics SDK merely to measure store conversion.

## Sources

- **C1:** [TMC Apps Google Play listing and replies](https://play.google.com/store/apps/details?hl=en_US&id=com.themobilecoder.foldcounter); [publisher site](https://foldcounter.tmcapps.com/).
- **C2:** [MATLOOB Unfold Counter](https://play.google.com/store/apps/details?hl=en_US&id=com.matloob.unfolded).
- **C3:** [Roovie Fold Counter](https://play.google.com/store/apps/details?id=co.roovie.foldcounter).
- **C4:** [Flip & Fold Counter (Samsung)](https://play.google.com/store/apps/details?id=dev.akexorcist.flipfoldcounter).
- **C5:** [FoldMeter](https://play.google.com/store/apps/details?id=app.foldcounter.for.foldables).
- **C6:** [FoldTracker](https://play.google.com/store/apps/details?id=app.krafted.foldtracker).
- **C7:** [Clicker on the US App Store](https://apps.apple.com/us/app/clicker-count-anything/id1043951998).
- **A1:** [Apple: App Store search](https://developer.apple.com/app-store/search/).
- **A2:** [Apple: Creating your product page](https://developer.apple.com/app-store/product-page/).
- **Hardware:** [Apple iPhone Duo developer hub](https://developer.apple.com/iphone-duo/), still advertising the 27.1 beta as forthcoming on the research date; [hinge API talk](https://developer.apple.com/videos/play/tech-talks/111464/).

For publishing requirements and their separate sources, see [APP_STORE_RELEASE.md](APP_STORE_RELEASE.md).
