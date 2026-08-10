# Design QA

final result: passed

## Sources

- Home reference: `/Users/may/Downloads/ChatGPT_Image_2026年6月9日_15_54_17.png`
- Login reference: `/Users/may/Downloads/ChatGPT_Image_2026年6月9日_15_53_06_(1).png`
- Home implementation: `/var/folders/gj/72jvr0zj5v3_spxh42hcmbpr0000gn/T/screenshot_optimized_7183595c-2074-44d0-ba2c-37fb9d449a5b.jpg`
- Login implementation: `/var/folders/gj/72jvr0zj5v3_spxh42hcmbpr0000gn/T/screenshot_optimized_d63c64ec-e56f-4dba-bbd2-2448b93eddda.jpg`
- Viewport: iPhone 17 Pro, 368 x 800 optimized simulator capture
- State: initial login and initial home

## Full-View Comparison

- Home hero now uses a dedicated black-background character asset, so the card remains continuously black like the reference.
- Home section rhythm now places the community author row above the lowered floating tab bar, matching the reference composition.
- Login character is smaller than the first revision and no longer clips on the right edge.
- Login title typography, security assurance, agreement row, navigation bar, and feature-card micro-dimensional effects remain unchanged per user direction.

## Focused Comparison

- Home hero: character crop, black background continuity, left text block, and white CTA checked.
- Login hero: complete right outline and both shoulders checked.
- Home bottom: community author row and tab-bar vertical placement checked.

## Accepted Differences

- Existing feature-card and tab-bar shadows remain stronger than the reference because the user explicitly requested preserving their micro-dimensional effect.
- Login security and agreement content remain in the existing product format because the user explicitly requested that those blocks and font sizes not change.

## Verification

- `build_run_sim`: succeeded with no warnings or errors.
- Login progression, onboarding skip, and home rendering verified in Simulator.

## DIY Entry Page (2026-08-09)

final result: passed

### Source and implementation

- Source visual truth: `/Users/may/.codex/generated_images/019fb22f-3599-7762-8950-04afed115245/exec-cf841bcd-dc05-4a55-959a-a2166ec95d37.png`
- Implementation screenshot: `/tmp/diy-entry-typography-final.png`
- Source pixels: 853 x 1844, designed as a 390 x 844 mobile viewport (approximately 2.187x density).
- Implementation pixels: 1320 x 2868, iPhone 17 Pro Max 440 x 956 logical viewport at 3x density.
- Density normalization: both full views were compared at equal displayed width; the source normalizes to approximately 440 x 951, with the remaining five-point height difference coming from native device chrome.
- State: DIY tab selected, entry page at the top of its scroll view.

### Full-view comparison evidence

- Header, hero, capability grid, and bottom navigation follow the selected design's vertical rhythm and remain visible in one frame.
- Typography uses the native system/PingFang fallback with the selected design's compact sizing, black/gray hierarchy, heavy display title, and lighter supporting copy.
- The dedicated hardware collage uses multiply blending on white, has no rectangular edge, does not cover text, and remains inside the right side of the hero.
- The capability cards use horizontal icon-and-copy layouts, subtle borders, white surfaces, and one-line supporting copy matching the source density.
- Bottom navigation uses icon-only items per the user's final direction, with consistent selected/unselected SF Symbol pairs; DIY uses the native selected pill.

### Focused comparison evidence

- Hero: title wrapping, benefit spacing, CTA proportions, image crop, and the collage's right edge were checked.
- Capability grid: two-column tracks, icon wells, title/subtitle scale, and row rhythm were checked.
- Navigation: equal icon size, icon-only presentation, fixed black DIY wrench/screwdriver icon, selected DIY state, and capsule placement were checked.

### Comparison history

- Pass 1 (`/tmp/diy-entry-implementation.png`): P2 hardware art touched the right edge, capability subtitles wrapped, and tab labels were absent.
- Fix: shifted the collage left, forced compact one-line subtitles, and made all tab icons use the same selected/unselected treatment.
- Pass 2 (`/tmp/diy-entry-implementation-v2.png`): earlier P2 findings were resolved; remaining section and card typography was slightly larger than the source.
- Fix: reduced the capability-section heading and card typography to the source proportions.
- Pass 3 (`/tmp/diy-entry-implementation-final.png`): hardware composition and type hierarchy still needed closer matching.
- Fix: replaced the hero with the black case/motherboard/triple-fan GPU/PSU/RAM collage and recalibrated every visible text style against the selected source.
- Pass 4 (`/tmp/diy-entry-typography-final.png`): no actionable P0, P1, or P2 differences remain. Navigation labels are intentionally absent per the user's final instruction.
- Fix: removed the five shortcut tiles and the header notification bell per the user's follow-up direction, then tightened the resulting vertical rhythm. The DIY tab icon is now the same black filled symbol in both selection states.
- Pass 5 (`/tmp/diy-entry-no-shortcuts-later.png`): no actionable P0, P1, or P2 differences remain.
- Fix: moved the capability section down by 16pt and added a directional fade/slide transition between the DIY entry page and builder page.
- Pass 6: static layout change is covered by the pre-change simulator evidence and the new build compiles successfully; transition code is wired for both forward and back navigation.
- Fix: increased the vertical spacing between the hero label, title, description, and benefit list, and expanded the hero region to keep the lower composition balanced.
- Pass 7: typography spacing change compiles successfully with no new diagnostics.
- Fix: hid the native bottom tab bar while the eight-component builder is active and removed its header notification icon; the entry page keeps the tab bar.
- Pass 8: builder navigation visibility and header cleanup compile successfully.

### Accepted platform differences

- The selected design omits OS chrome; the native build correctly preserves the iPhone status bar and Dynamic Island.
- The bottom capsule uses iOS 26 native TabView material and shadow rather than rasterizing the generated mock's exact translucent surface.

### Interaction and build verification

- `开始 DIY` successfully opens the existing eight-component selection page.
- The builder's back button successfully returns to the DIY entry page.
- `xcodebuild -quiet -project May/May.xcodeproj -target May -sdk iphonesimulator -configuration Debug build`: passed.

## Apple 登录页重设计（2026-08-09）

final result: passed

### Source and implementation

- Source visual truth: `/Users/may/.codex/generated_images/019fe48b-a3d8-7623-b202-ea91c6ca3ba2/exec-c7e29a38-4c4a-4670-ad0b-31574877a3bf.png`
- Implementation screenshot: `/tmp/uzbox-redesigned-login-final.png`
- Final side-by-side comparison: `/tmp/uzbox-login-design-qa-final-side-by-side.png`
- Source pixels: 853 x 1844.
- Implementation pixels: 1206 x 2622, iPhone 17 Pro 402 x 874 logical viewport at 3x density.
- Density normalization: source was proportionally resized and white-padded to 1206 x 2622 before being placed beside the native 3x capture; no dimensions were judged from unmatched density.
- State: logged out, agreement unchecked, Apple authorization idle, light appearance.

### Full-view comparison evidence

- Information architecture and copy match the selected target: top-left UzBox wordmark, exploded monochrome hardware hero, two-line Chinese headline, supporting sentence, native Apple button, agreement row, and password privacy note.
- Fonts and typography use the native iOS/PingFang fallback with black display weights, compact negative tracking, readable neutral-gray supporting text, and the same two-line headline wrap as the source.
- Spacing and layout preserve the source's leading alignment and vertical hierarchy while respecting the native status bar and Dynamic Island.
- Colors use only white, black, and neutral grays. No app accent color, chromatic shadow, or tinted system control appears.
- The dedicated 1374 x 1145 hardware image remains sharp at the rendered size and preserves the source's grayscale exploded-component art direction; no visible UI imagery is approximated with code-drawn shapes.
- App-specific copy is exact and untruncated. The Apple control remains `SignInWithAppleButton`, not a rasterized or imitation button.

### Focused comparison evidence

- The full-resolution side-by-side comparison keeps the wordmark, headline, Apple button label, agreement text, lock icon, and privacy note legible, so a separate crop was not needed.
- Hero subject, white-background edge treatment, memory/GPU/cooler placement, and image sharpness were checked at original resolution.
- Control details checked: button width and radius, unchecked-circle weight, legal-link contrast, neutral-gray trust text, and horizontal centering.

### Findings and comparison history

- Pass 1 (`/tmp/uzbox-login-design-qa-side-by-side.png`): P2 Apple button was wider than the source and the login control group sat too high, weakening the source's vertical rhythm.
- Fix: capped the native Apple button at 320pt and increased the gap above the control group while keeping the agreement and trust note attached to it.
- Pass 2 (`/tmp/uzbox-login-design-qa-final-side-by-side.png`): the earlier width and vertical-rhythm findings are resolved. No actionable P0, P1, or P2 mismatch remains.

### Accepted platform differences and verification

- The source omits OS chrome; the implementation correctly retains the native iPhone status bar and Dynamic Island.
- The standalone hero asset has a slightly tighter base crop than the generated full-screen target, but it preserves the same subject, hierarchy, tonal range, and image quality; this is accepted as P3 polish.
- `xcodebuild -quiet -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,id=882873B7-251C-4C78-8D72-881998442588' -configuration Debug build`: passed.
- The built app was installed and launched on the dedicated iPhone 17 Pro simulator; the final logged-out state was captured after the launch transition completed.
- A focused test command was attempted, but this Xcode project exposes only the `May` app target and its scheme has no test action. Existing Apple authorization, nonce exchange, agreement guard, and session code were left intact by this visual pass.

## Apple 登录页微调（2026-08-10）

final result: blocked

### Source and requested change

- Title reference: `/var/folders/gj/72jvr0zj5v3_spxh42hcmbpr0000gn/T/TemporaryItems/NSIRD_screencaptureui_fdkXg2/截屏2026-08-10 04.15.22.png`
- Removal reference: `/var/folders/gj/72jvr0zj5v3_spxh42hcmbpr0000gn/T/TemporaryItems/NSIRD_screencaptureui_CH8v2S/截屏2026-08-10 04.15.38.png`
- Requested state: logged-out Apple login page, title slightly smaller, password-sharing trust note absent.

### Implementation and non-visual verification

- The title changed from 40pt to 36pt on the regular layout and from 36pt to 33pt on compact layouts.
- The lock icon and `Apple 不会向 UzBox 分享你的密码` row were removed together; agreement controls and Apple authorization behavior were not changed.
- `xcodebuild -quiet -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,id=882873B7-251C-4C78-8D72-881998442588' -configuration Debug build`: passed.
- `git diff --check`: passed.

### Visual QA blocker

- No post-change implementation screenshot or side-by-side comparison is recorded because the user explicitly chose to perform the visual check locally.
- Fonts, final spacing rhythm, and responsive appearance therefore remain user-owned visual verification; no visual fidelity pass is claimed for this follow-up.
