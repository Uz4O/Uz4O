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

## Flutter iOS 像素级复刻持续校准（2026-08-10）

final result: in progress

- 性能结果页已完成同尺寸 SwiftUI 对照：`/tmp/swift-performance-result.png` 与 `/tmp/flutter-performance-result2.png`。
- 已对齐顶部 Time Spy 卡片高度、2K 深色选中态、0/47K 仪表盘标尺、474/227/184 FPS、测试配置图标/型号和结果说明。
- DIY 选件页与 CPU 选择弹层已采集：`/tmp/flutter-diy.png`、`/tmp/flutter-diy-picker.png`；仍需继续复核原版弹层卡片阴影、价格列与其他选件状态。
- 注销页已采集：`/tmp/flutter-delete.png`；继续保留原版 NavigationStack 的取消入口与禁用态校准。
- `dart analyze`、Flutter widget tests、Flutter iOS simulator build、Xcode workspace build、`git diff --check` 均通过。
- 仍未宣称完成：升级结果、硬件选择弹层、配置详情/保存状态、DIY 选择后的动态统计和全部页面最终并排复核仍在进行。

## Flutter 前端后续页面复刻（2026-08-10）

final result: in progress

- 配置排雷手动填写页恢复六项“型号 + 单项价格”输入、型号选择弹层、填写数量/总价底栏；检测中恢复进度数字、主板素材和四阶段检查列表；结果页恢复综合结论、指标、编号风险项及复制话术栏。
- 升级建议第 2/3 步补齐游戏目标、预算、优先游戏选择弹层、分辨率和参考帧率目标；无游戏时生成按钮会提示先选择游戏。
- `/tmp/swift-config-manual.png` 与 `/tmp/flutter-config-manual.png` 已生成同尺寸并排检查；主结构、行高、底栏和文案已对齐，保留字体/图标的跨平台 P3 差异。
- 配置排雷结果和升级第 2/3 步仍需更多原生截图状态做最终像素级复核；本轮不宣称百分百完成。

## Flutter iOS 界面还原进度（2026-08-10）

final result: in progress

### 本轮对照证据

- 风格详情 SwiftUI / Flutter 同尺寸对比：`/tmp/uzbox-style-overview-pass6-comparison.jpg`。
- AI 写配置第 1 步 SwiftUI / Flutter 同尺寸对比：`/tmp/uzbox-ai-step1-pass5-comparison.jpg`。
- AI 写配置第 2–4 步并排证据：`/tmp/uzbox-ai-step2-pass1-comparison.jpg`、`/tmp/uzbox-ai-step3-pass1-comparison.jpg`、`/tmp/uzbox-ai-step4-pass1-comparison.jpg`。
- 方案选择与配置详情并排证据：`/tmp/uzbox-build-options-pass1-comparison.jpg`、`/tmp/uzbox-build-result-pass1-comparison.jpg`。
- 配置排雷、升级建议、性能测试入口并排证据：`/tmp/uzbox-config-review-pass1-comparison.jpg`、`/tmp/uzbox-upgrade-pass1-comparison.jpg`、`/tmp/uzbox-performance-pass1-comparison.jpg`。
- 根页对照延用：`/tmp/uzbox-home-pass3-comparison.jpg` 与 `/tmp/uzbox-styles-pass3-comparison.jpg`。
- 所有对比图均为 1320 x 2868 的 iPhone 17 Pro Max 屏幕状态，左侧 SwiftUI，右侧 Flutter。

### 本轮已修正

- 风格详情 Hero 画框恢复为 244pt，补上原版缩放和垂直偏移，标题恢复单行，颜色切换使用 SwiftUI 原始黑/白机箱素材。
- 风格详情的标题、颜色胶囊、配件行高、字号、价格、底部费用栏与 SwiftUI 参数对齐；“替换”已接通平替选择弹层和费用更新。
- AI 第 1 步使用 28pt 紧凑页头、22pt 步骤指示、独立步骤胶囊、34pt 预算控件和始终可见的上一步按钮，底部安全区算法已与 SwiftUI 一致。
- AI 后续步骤已改为真实游戏封面四列网格（16 项）、完成步骤勾选、购买/外观偏好、容量/升级偏好，并接通带进度环和阶段时间线的生成动画、可选方案和配置详情。
- 方案选择页恢复 SwiftUI 的二手/全新/混合顺序、文案、彩色徽章和真实参考价格；配置详情恢复二手方案的八项配件、环形性能指标和总价。
- 装机风格目录已扩展到完整目录，使用 SwiftUI 素材的黑白机箱图片；左上角沉浸全景按钮仍只保留入口，不实现全景页。
- 配置排雷已接通手动填写、检测进度和结果；升级建议已接通 1/3、2/3、3/3 和保存状态；游戏性能测试已接通分辨率、Time Spy 和游戏帧率结果。
- DIY 选件后会更新已选数量、总价、功耗与型号；注销账号恢复为完整 DELETE 确认界面。

### 验证

- `/Users/may/Developer/flutter/bin/dart analyze lib test`：通过，`No issues found!`。
- `/Users/may/Developer/flutter/bin/flutter test --no-pub`：4 组 widget 测试通过，覆盖四标签、主流程入口、排雷结果、升级结果、性能结果和配置详情。
- `xcodebuild -workspace flutter_app/ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=iOS Simulator,id=E98EA16E-2ADD-42CA-B08D-A4B70C14C2ED' -derivedDataPath flutter_app/build/xcode-derived build -quiet`：通过。
- 最新 Runner 已安装并运行在 iPhone 17 Pro Max 模拟器。

### 尚未封板的视觉 QA

- AI 第 2-4 步、生成页、方案选择页与配置详情仍需继续做最终微调（当前并排证据已记录，字体栅格与液态胶囊阴影仍有 P3 差异）。
- 排雷后续状态、升级 2/3-3/3、性能结果、DIY 选件弹层和注销界面仍需逐页并排校准；升级/性能入口页已完成同尺寸检查。
- 左上角“沉浸全景”按用户要求保留入口但不实现全景界面。

### Visual QA status

- 已使用同尺寸 SwiftUI / Flutter 拼图检查关键 AI 流程、方案选择和配置详情；剩余差异主要是系统字体栅格、液态胶囊阴影和状态栏回退指示器等平台渲染细节。
- 仍保留 `final result: in progress`，因为排雷、升级、性能结果、DIY 弹层和注销页尚未逐页完成最终并排校准。

## Android 主页 SwiftUI 高保真复刻（2026-08-10）

final result: passed

### Source and implementation

- Source visual truth: `/tmp/uzbox-ios-home-source.png`.
- Implementation screenshot: `/tmp/uzbox-android-home-final.png`.
- Full-view side-by-side comparison: `/tmp/uzbox-home-final-comparison.png`.
- Focused content comparison: `/tmp/uzbox-home-final-focused-comparison.png`.
- Four selector states: `/tmp/uzbox-home-final-feature-states.png`.
- Source and implementation pixels: 1320 x 2868.
- CSS/logical viewport equivalent: 440 x 956 at 3x density.
- Density normalization: none required; both captures use the same pixel and logical viewport dimensions.
- State: light appearance, AI 一键装机 selected, page at scroll origin. The Android bottom navigation is intentionally absent per the user's scope.

### Full-view comparison evidence

- Layout and spacing: the 406dp centered content width, 17dp compact side margin, header baseline, 316dp hero region, 50dp selector controls, section gaps, 126dp style rows, and separators align with the SwiftUI source at the same viewport.
- Fonts and typography: Android system sans/Noto CJK remains platform-native, while optical sizes, black/heavy hierarchy, line height, letter spacing, wrapping, and baseline positions were calibrated against the iOS SF Pro/PingFang rendering. All app text is untruncated.
- Colors and tokens: the page uses the same `#F8FAFA` background, black primary text/actions, neutral secondary text, translucent white selector surfaces, and low-opacity dividers. No prior green card tint or extra card surface remains.
- Image quality: hero and style-list imagery comes directly from the iOS asset catalog. Subject, transparency, crop, scale, sharpness, and white-background integration match; no image was replaced with a placeholder or code-drawn approximation.
- Copy and content: hero labels, all four feature titles/subtitles/bullets/actions, section copy, three style names, and starting prices match the current SwiftUI source.
- Icons: text glyph placeholders were removed. The closest official Material outline icons are used for Android, with the same 24dp optical size, selected fill, 50dp hit target, order, and state behavior as the SF Symbols source.

### Focused comparison evidence

- The focused comparison keeps the hero label/title/subtitle, three bullet baselines, pill button, four selectors, section heading, prices, row imagery, and dividers readable at matched density.
- Hero geometry was checked independently: text and image columns, image top/bottom anchors, 136 x 44 action control, and selector positions match the source.
- Style rows were checked independently: image frames are 148 x 106, text uses the same three-line hierarchy, and every divider spans the same content width.

### Findings and comparison history

- Pass 1 (`/tmp/uzbox-android-home-pass1.png`): P1 the Android page still used the old header spacing and section rhythm; P2 brand width and hero text baselines were visibly displaced from the source.
- Fix: capped the responsive content width, recalibrated top inset and wordmark typography, and aligned the hero/selector/section anchors to the SwiftUI measurements.
- Pass 2 (`/tmp/uzbox-android-home-pass2-1320.png`): structural anchors and all imagery aligned, but P2 hero bullet rhythm was too compressed near the action and the section heading/subtitle baselines were several pixels low.
- Fix: retuned label/title/subtitle/bullet spacing, preserved the bottom-anchored action, and balanced the section-heading gaps without moving the already-aligned style rows.
- Pass 3 (`/tmp/uzbox-home-final-comparison.png`): no actionable P0, P1, or P2 visual mismatch remains. The focused crop confirms the five required fidelity surfaces: typography, spacing, colors, image quality, and copy.

### Accepted platform differences and verification

- Android system status icons differ from the iPhone Dynamic Island/status bar. OS chrome is outside app-owned content.
- Android uses official Material outline icons rather than Apple-restricted SF Symbols; their role, size, alignment, stroke family, and selected treatment match.
- Minor glyph rasterization differences between Android Noto/Roboto and iOS PingFang/SF Pro are accepted as P3 platform rendering, after optical size and baseline calibration.
- All four feature selectors were tapped and rendered successfully; horizontal hero swipe also changed AI 一键装机 to 游戏性能测试.
- `env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:assembleDebug --console=plain`: passed.
- `env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --console=plain`: passed.

## Android 四主标签与悬浮导航复刻（2026-08-10）

final result: passed

### Source and implementation

- Source visual truth: `/tmp/uzbox-ios-home-nav-source.png`, `/tmp/uzbox-ios-styles-source.png`, `/tmp/uzbox-ios-diy-source.png`, `/tmp/uzbox-ios-profile-source.png`.
- Implementation screenshots: `/tmp/uzbox-android-home-nav-exact-v3.png`, `/tmp/uzbox-android-styles-final.png`, `/tmp/uzbox-android-diy-exact-v3.png`, `/tmp/uzbox-android-profile-exact-v3.png`.
- Full-view comparisons: `/tmp/uzbox-home-nav-final-comparison.jpg`, `/tmp/uzbox-styles-final-comparison-v2.jpg`, `/tmp/uzbox-diy-final-comparison.jpg`, `/tmp/uzbox-profile-final-comparison.jpg`.
- Focused navigation comparison: `/tmp/uzbox-nav-focused-final.jpg`.
- Source and implementation pixels: 1320 x 2868 for every compared screen.
- Logical viewport and density: 440 x 956 at 3x density; Android was temporarily captured at the exact iOS viewport and then restored to the emulator's physical display size.
- States: light appearance, page at scroll origin, each of 首页 / 风格 / DIY / 我的 selected in turn.

### Full-view comparison evidence

- Information architecture matches the SwiftUI source: four icon-only root tabs in the same order, with the selected tab carried by a moving pale capsule inside a floating white translucent shell.
- Fonts and typography: display weights, optical sizes, line heights, wrapping, and hierarchy were matched per screen. Android keeps its native Noto/Roboto CJK rasterization; all fixed app copy remains legible and untruncated.
- Spacing and layout: the floating bar width and four icon centers, Styles showcase row heights, DIY 389dp hero and two-column capability grid, and Profile 360dp content column/card rhythm align at the matched viewport.
- Colors and tokens: white/near-white surfaces, neutral blue-gray background, black controls, secondary-gray copy, subtle borders, shadows, and destructive red follow the current iOS values without the previous Android green treatment.
- Image quality: all visible case and DIY hero imagery is copied directly from the iOS asset catalog at source resolution. Crops, aspect ratios, transparency, sharpness, and scale were inspected side by side; no product art uses placeholders or code-drawn substitutes.
- Copy and content: headings, descriptions, style names/prices, DIY capability copy, profile labels, completion copy, contact email, and destructive-account text match the SwiftUI source.
- Icons: the closest official Material symbols replace SF Symbols on Android. Icon order, semantic role, selected state, optical size, and tap target are preserved.

### Focused comparison evidence

- `/tmp/uzbox-nav-focused-final.jpg` isolates the persistent bottom region. The bar silhouette, width, 4-slot spacing, selected capsule, icon baseline, elevation, and content overlap were checked without the rest of the page masking differences.
- Styles imagery and text remain readable in the full-resolution paired capture, including the 01-05 indices, two-line VISION COMPACT title, cost baselines, arrow controls, case scale, and grounding shadows.
- DIY hero/title/collage/button and capability-card typography were checked at original resolution; Profile avatar, dividers, row icons, subtitles, and destructive state were likewise checked at original resolution.

### Findings and comparison history

- Pass 1: P2 the custom Android navigation shell was too narrow, so the four icon centers did not match the iOS native tab bar; P2 Styles reflections rendered as heavy gray bars; P2 Profile row icons used the full 32dp frame and made the settings card too tall.
- Fix: widened the floating shell to 396dp, recalibrated the selection travel and width, removed the artifact-prone reflected image layer, reduced grounding-shadow opacity, and placed 22dp profile icons inside the original 32dp alignment column.
- Pass 2 (`/tmp/uzbox-styles-final-comparison-v2.jpg`, `/tmp/uzbox-nav-focused-final.jpg`, `/tmp/uzbox-profile-final-comparison.jpg`): the earlier P2 findings are resolved. No actionable P0, P1, or P2 difference remains across the five required fidelity surfaces.

### Accepted platform differences and verification

- The user explicitly exempted Swift-only liquid-glass refraction. Android uses a translucent white capsule, subtle border/elevation, and spring-selected surface without imitating Apple's private material.
- Android status icons and gesture indicator differ from the iPhone Dynamic Island/home region; OS chrome is outside app-owned content.
- Material Icons replace SF Symbols, and Noto/Roboto replace SF Pro/PingFang. Minor glyph shape and antialiasing differences are accepted as P3 platform rendering.
- All four main tabs were tapped on the Android emulator and each selected state rendered correctly; the selected background moves with a spring animation.
- `env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:assembleDebug :app:testDebugUnitTest --console=plain`: passed.
- `git diff --check`: passed.
