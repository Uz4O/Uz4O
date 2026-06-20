# User Agreement and Privacy Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship truthful legal documents and the working consent, account deletion, community safety, disclosure, and AI notice controls required for the mainland-China release of AI 装机助手.

**Architecture:** Legal Markdown files in the app bundle are the single source displayed before and after login. A small authenticated Swift API client connects the existing SwiftUI prototype to focused FastAPI endpoints; backend account deletion and community safety behavior live in repositories with database constraints and API tests. Release documents are generated from the verified production data flow, and unknown vendors remain explicit release blockers instead of appearing in the effective privacy policy.

**Tech Stack:** Swift 5 / SwiftUI / URLSession / Security, iOS privacy manifest, Python 3.9, FastAPI, SQLAlchemy, Alembic, Pydantic, pytest, PostgreSQL

---

## Worktree Safety

The repository already contains unrelated uncommitted UI work, including files this plan will later touch. Before implementation, record `git status --short` and the existing diff. Every commit step below means “stage only task-owned changes”; do not stage pre-existing hunks. Before each commit, run `git diff --cached --check` and inspect `git diff --cached --stat`. If clean staging cannot separate task work from existing edits, keep that task uncommitted and report the constraint instead of absorbing the user's changes.

## File Map

### Create

- `May/May/Legal/LegalDocument.swift`: legal document metadata and bundle loading.
- `May/May/Legal/LegalDocumentView.swift`: reusable scrollable legal-document screen.
- `May/May/Legal/UserAgreement.md`: effective user agreement shown in the app.
- `May/May/Legal/PrivacyPolicy.md`: effective privacy policy shown in the app.
- `May/May/Legal/ThirdPartySharingList.md`: enabled-provider disclosure; initially records that no production provider is enabled.
- `May/May/Legal/CommunityGuidelines.md`: community publication and enforcement rules.
- `May/May/Networking/AppAPIClient.swift`: typed authentication, account deletion, and community-safety requests.
- `May/May/Models/AppSession.swift`: access-token lifecycle and logout cleanup.
- `May/May/PrivacyInfo.xcprivacy`: required-reason declaration for local preferences.
- `May/MayTests/LegalComplianceRulesTests.swift`: pure Swift consent, metadata, and AI notice rules.
- `backend/app/community/safety_models.py`: reports and user blocks.
- `backend/app/community/safety_repository.py`: report, block, moderation, and ownership operations.
- `backend/migrations/versions/20260621_0007_community_safety.py`: safety tables, account moderation flag, and indexes.
- `backend/tests/test_account_deletion_api.py`: deletion and post-deletion token tests.
- `backend/tests/test_community_safety_api.py`: deletion, report, block, and moderation authorization tests.
- `docs/legal/app-store-privacy-disclosure.md`: App Store Connect privacy answers tied to current code.
- `docs/legal/release-compliance-checklist.md`: named release blockers and operator sign-off.

### Modify

- `May/May/Screens/LoginView.swift`: two-step login, default-off consent, and legal links.
- `May/May/ContentView.swift`: own `AppSession`, route logout/deletion, and inject the API client.
- `May/May/Screens/ProfileView.swift`: legal, contact, and account-deletion destinations.
- `May/May/Screens/CommunityView.swift`: load feed and expose report/block/delete actions.
- `May/May/Screens/CommunityDetailView.swift`: report/block/delete menus and error feedback.
- `May/May/Screens/CommunityComposerView.swift`: guidelines acknowledgement and real publish request.
- `May/May/Screens/AIBuildView.swift`: persistent AI-assisted-content notice.
- `May/May/Models/CommunityContent.swift`: API identifiers, ownership, comments, and action rules.
- `backend/app/auth/models.py`: moderator flag.
- `backend/app/auth/repository.py`: transactional account erasure.
- `backend/app/api/auth.py`: authenticated deletion endpoint.
- `backend/app/community/repository.py`: owner deletion and blocked-author filtering.
- `backend/app/api/community.py`: authenticated feed context and safety endpoints.
- `backend/progress.json`: track the compliance capability accurately.

## Task 1: Effective Legal Documents and Release Disclosures

**Files:**
- Create: `May/May/Legal/UserAgreement.md`
- Create: `May/May/Legal/PrivacyPolicy.md`
- Create: `May/May/Legal/ThirdPartySharingList.md`
- Create: `May/May/Legal/CommunityGuidelines.md`
- Create: `docs/legal/app-store-privacy-disclosure.md`
- Create: `docs/legal/release-compliance-checklist.md`

- [ ] **Step 1: Write the four effective documents**

Use identical metadata at the top of each file:

```markdown
版本：1.0
更新日期：2026年6月21日
生效日期：2026年6月21日
运营者：孙裕凤
联系邮箱：youz66811@gmail.com
```

The user agreement must state that users under 14 years old cannot register or use the service, then cover account lifecycle, community content license limited to operating the service, prohibited content, enforcement and appeal, AI/price/compatibility limitations, IP complaints, service changes, lawful liability limits, PRC law, and operator email. The privacy policy must enumerate every data category from the approved design, state that AI requests exclude account identifiers, explain permissions and user rights, use the approved retention table, state mainland storage/no unassessed export, and describe deletion exceptions. Community guidelines must define reportable content and enforcement. The third-party list must say that production AI, SMS, hosting, database, object storage, moderation, crash, and analytics vendors are not yet enabled/confirmed and that the corresponding capability cannot ship until the list is updated; do not name DeepSeek or Alibaba as effective processors merely because development defaults exist.

- [ ] **Step 2: Write the App Store disclosure matrix**

Use a table with these exact columns:

```markdown
| App Store 类别 | 当前数据 | 与用户关联 | 用于追踪 | 用途 | 代码依据 |
| --- | --- | --- | --- | --- | --- |
| 联系信息 | 手机号 | 是 | 否 | App 功能、账号管理 | `backend/app/auth/models.py` |
| 用户内容 | 帖子、评论、图片、自由文本备注 | 是 | 否 | App 功能 | `backend/app/community/models.py`, `backend/app/builds/ai_provider.py` |
| 标识符 | Apple 用户标识、内部账号 ID | 是 | 否 | App 功能、账号管理 | `backend/app/auth/models.py` |
| 购买项目 | 不收集 | 不适用 | 否 | 不适用 | 当前版本无交易接口 |
| 使用数据 | 点赞、收藏、屏蔽、举报 | 是 | 否 | App 功能、安全 | 社区接口与安全模型 |
| 诊断 | 仅必要安全日志；无崩溃 SDK | 视生产日志配置 | 否 | 安全、诊断 | 发布前日志核验 |
```

- [ ] **Step 3: Write the release checklist**

Require operator sign-off for Apple account identity, App filing, server/database/object-storage region, each enabled vendor, privacy labels, legal URLs, account deletion, community reporting/blocking/content deletion, moderation coverage, backup deletion, image-object deletion, and a final packet/data-flow audit. Each unresolved item uses `- [ ]` and is explicitly marked “未完成时不得发布”.

- [ ] **Step 4: Verify document consistency**

Run:

```bash
rg -n '运营者|联系邮箱|版本：|更新日期：|生效日期：' May/May/Legal/*.md
rg -n '【|待填写|绝对安全|永久免费' May/May/Legal docs/legal
```

Expected: all four effective documents show 孙裕凤 and `youz66811@gmail.com`; the second command prints nothing.

- [ ] **Step 5: Commit**

```bash
git add May/May/Legal/*.md docs/legal
git commit -m "docs: add app legal and release disclosures"
```

## Task 2: Bundle Legal Documents and Enforce Consent Rules

**Files:**
- Create: `May/May/Legal/LegalDocument.swift`
- Create: `May/May/Legal/LegalDocumentView.swift`
- Create: `May/MayTests/LegalComplianceRulesTests.swift`
- Modify: `May/May/Screens/LoginView.swift`
- Modify: `May/May/ContentView.swift`

- [ ] **Step 1: Write the failing pure Swift rule test**

```swift
import Foundation

@main
struct LegalComplianceRulesTests {
    static func main() {
        precondition(LegalDocument.allCases.map(\.title) == ["用户协议", "隐私政策", "第三方信息共享清单", "社区规范"])
        precondition(LoginConsentState().canAuthenticate == false)
        precondition(LoginConsentState(hasAcceptedTerms: true).canAuthenticate == true)
        precondition(AIContentDisclosure.text.contains("AI 辅助生成"))
        print("LegalComplianceRulesTests passed")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swiftc May/May/Legal/LegalDocument.swift May/MayTests/LegalComplianceRulesTests.swift -o /tmp/legal-rules
```

Expected: FAIL because `LegalDocument.swift` and the rule types do not exist.

- [ ] **Step 3: Implement the legal metadata and consent rules**

```swift
import Foundation

enum LegalDocument: String, CaseIterable, Identifiable {
    case userAgreement = "UserAgreement"
    case privacyPolicy = "PrivacyPolicy"
    case thirdPartySharing = "ThirdPartySharingList"
    case communityGuidelines = "CommunityGuidelines"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .userAgreement: "用户协议"
        case .privacyPolicy: "隐私政策"
        case .thirdPartySharing: "第三方信息共享清单"
        case .communityGuidelines: "社区规范"
        }
    }

    func load(bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: rawValue, withExtension: "md", subdirectory: "Legal")
                ?? bundle.url(forResource: rawValue, withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

struct LoginConsentState: Equatable {
    var hasAcceptedTerms = false
    var canAuthenticate: Bool { hasAcceptedTerms }
}

enum AIContentDisclosure {
    static let text = "内容由 AI 辅助生成，仅供装机参考，请在购买前核对价格、规格与兼容性。"
}
```

- [ ] **Step 4: Add a reusable document screen**

Implement `LegalDocumentView(document:)` with a `ScrollView`, selectable `Text(try AttributedString(markdown: content))`, navigation title, loading error, and no web view or remote URL dependency. Present `.userAgreement` and `.privacyPolicy` with separate buttons in `LoginView`.

- [ ] **Step 5: Change login consent from default-on to default-off**

Replace `@State private var hasAgreed = true` with `@State private var consent = LoginConsentState()`. Disable authentication while `canAuthenticate` is false, keep the button visually disabled, and show `请先阅读并同意用户协议和隐私政策` when tapped through an explicit guarded action. Do not make the whole sentence a single legal link.

- [ ] **Step 6: Run focused tests and build**

```bash
swiftc May/May/Legal/LegalDocument.swift May/MayTests/LegalComplianceRulesTests.swift -o /tmp/legal-rules && /tmp/legal-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `LegalComplianceRulesTests passed` and `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add May/May/Legal May/May/Screens/LoginView.swift May/May/ContentView.swift May/MayTests/LegalComplianceRulesTests.swift
git commit -m "feat: require consent and show legal documents"
```

## Task 3: Real Authentication Session and Secure Token Storage

**Files:**
- Create: `May/May/Networking/AppAPIClient.swift`
- Create: `May/May/Models/AppSession.swift`
- Modify: `May/May/Screens/LoginView.swift`
- Modify: `May/May/ContentView.swift`
- Create: `May/May/PrivacyInfo.xcprivacy`

- [ ] **Step 1: Define request/response and transport contracts**

Create `APITransport` with `func data(for request: URLRequest) async throws -> (Data, URLResponse)`, make `URLSession` conform, and define `AppAPIClient` with a configured `baseURL`, transport, and JSON encoder/decoder. Add `sendSMS(phone:)`, `login(phone:code:)`, and authenticated `deleteAccount(confirmation:)`. Reject non-2xx responses with a typed `APIError.http(status:message:)`; never include tokens or verification codes in error descriptions.

- [ ] **Step 2: Add secure token storage**

Create `TokenStore` and a `KeychainTokenStore` implementation using Security generic-password items with service `AI-PC-Builder` and account `access-token`. `save`, `load`, and `delete` must use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Do not store the access token in `UserDefaults`.

- [ ] **Step 3: Implement AppSession**

```swift
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var accountID: String?

    private let api: AppAPIClient
    private let tokenStore: TokenStore

    var isAuthenticated: Bool { accessToken != nil }

    func login(phone: String, code: String) async throws {
        let response = try await api.login(phone: phone, code: code)
        try tokenStore.save(response.accessToken)
        accessToken = response.accessToken
        accountID = response.account.id
    }

    func logout() throws {
        try tokenStore.delete()
        accessToken = nil
        accountID = nil
    }
}
```

- [ ] **Step 4: Convert LoginView to a two-step flow**

“获取验证码” calls `sendSMS`; after success, change the primary button label to “登录” and call `AppSession.login`. Validate nonempty phone and 4–8 digit code, disable during requests, and expose server errors without logging response bodies. `ContentView` advances to onboarding only after `isAuthenticated` becomes true.

- [ ] **Step 5: Declare required-reason API usage**

Add `PrivacyInfo.xcprivacy` with `NSPrivacyTracking` false, an empty tracking-domain array, and `NSPrivacyAccessedAPITypes` containing `NSPrivacyAccessedAPICategoryUserDefaults` with approved reason `CA92.1` because the app stores only app-owned preferences.

- [ ] **Step 6: Verify**

```bash
plutil -lint May/May/PrivacyInfo.xcprivacy
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: plist OK and `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add May/May/Networking May/May/Models/AppSession.swift May/May/Screens/LoginView.swift May/May/ContentView.swift May/May/PrivacyInfo.xcprivacy
git commit -m "feat: connect consented login to authenticated session"
```

## Task 4: Backend Account Deletion

**Files:**
- Create: `backend/tests/test_account_deletion_api.py`
- Modify: `backend/app/auth/repository.py`
- Modify: `backend/app/api/auth.py`

- [ ] **Step 1: Write failing deletion tests**

Test that `DELETE /v1/auth/me` requires the JSON body `{"confirmation":"DELETE"}`, returns 204 for the current account, removes its profile, hardware, saved builds, posts, comments, reactions, and SMS codes for the account phone, leaves another account intact, and makes the old bearer token return 401. Also assert wrong confirmation returns 422 and missing auth returns 401. Safety-table cascade coverage is added in Task 5 after those tables exist.

- [ ] **Step 2: Run the tests to verify failure**

```bash
cd backend && ./.venv/bin/python -m pytest tests/test_account_deletion_api.py -q
```

Expected: FAIL with 405 because the endpoint does not exist.

- [ ] **Step 3: Implement transactional erasure**

Add `delete_account(session, account)` that deletes dependent rows in foreign-key order and commits once. Use SQLAlchemy `delete()` statements and the authenticated `Account` object; never accept an account ID from the request body. The API model is:

```python
class AccountDeletionRequest(BaseModel):
    confirmation: Literal["DELETE"]

@router.delete("/me", status_code=204)
def delete_me(
    request: AccountDeletionRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Response:
    delete_account(session, account)
    return Response(status_code=204)
```

- [ ] **Step 4: Run focused and auth regression tests**

```bash
cd backend && ./.venv/bin/python -m pytest tests/test_account_deletion_api.py tests/test_auth_profile_api.py tests/test_saved_builds_api.py tests/test_community_api.py -q
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/auth/repository.py backend/app/api/auth.py backend/tests/test_account_deletion_api.py
git commit -m "feat: add authenticated account deletion"
```

## Task 5: Community Safety Schema and Repository

**Files:**
- Create: `backend/app/community/safety_models.py`
- Create: `backend/app/community/safety_repository.py`
- Create: `backend/migrations/versions/20260621_0007_community_safety.py`
- Modify: `backend/app/auth/models.py`
- Modify: `backend/app/community/repository.py`
- Create: `backend/tests/test_community_safety_api.py`

- [ ] **Step 1: Write failing repository/API tests**

Cover one report per reporter/target, self-block rejection, idempotent block creation, blocked authors absent from feed, owner-only post/comment deletion, deleted content absent from detail/feed, database uniqueness enforcement, and deletion of report/block rows when either related account is deleted.

- [ ] **Step 2: Run tests to verify failure**

```bash
cd backend && ./.venv/bin/python -m pytest tests/test_community_safety_api.py -q
```

Expected: FAIL because safety models and endpoints do not exist.

- [ ] **Step 3: Add schema and migration**

Create `community_report` with reporter ID, target type (`post` or `comment`), target ID, reason, details, status, resolution note, created/updated timestamps, and a unique constraint on reporter/target. Create `community_block` with blocker ID, blocked ID, timestamp, and a unique pair constraint. Add `is_moderator BOOLEAN NOT NULL DEFAULT FALSE` to `account`. All account foreign keys use `ON DELETE CASCADE`; report target integrity is validated by the repository because the target is polymorphic.

- [ ] **Step 4: Implement focused repository methods**

Provide these exact operations:

```python
create_report(session, reporter_id, target_type, target_id, reason, details)
block_account(session, blocker_id, blocked_id)
unblock_account(session, blocker_id, blocked_id)
blocked_account_ids(session, blocker_id)
soft_delete_post(session, post_id, owner_id)
soft_delete_comment(session, comment_id, owner_id)
list_open_reports(session, limit, offset)
resolve_report(session, report_id, status, resolution_note)
```

Return `None` for missing/not-owned deletion targets so the API can use a non-enumerating 404. Feed queries accept `excluded_author_ids` and filter before pagination.

- [ ] **Step 5: Run migration and tests**

```bash
cd backend && ./.venv/bin/alembic upgrade head
cd backend && ./.venv/bin/python -m pytest tests/test_community_safety_api.py -q
```

Expected: migration succeeds and focused tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/auth/models.py backend/app/community backend/migrations/versions/20260621_0007_community_safety.py backend/tests/test_community_safety_api.py
git commit -m "feat: add community report and block persistence"
```

## Task 6: Community Safety and Moderation APIs

**Files:**
- Modify: `backend/app/api/community.py`
- Modify: `backend/app/auth/dependencies.py`
- Modify: `backend/tests/test_community_safety_api.py`

- [ ] **Step 1: Extend failing API tests**

Test authenticated `POST /v1/community/reports`, `POST` and `DELETE /v1/community/blocks/{account_id}`, owner `DELETE` routes for posts/comments, filtered authenticated feed, moderator-only `GET /v1/community/moderation/reports`, and moderator-only `PATCH /v1/community/moderation/reports/{report_id}`. Assert ordinary users receive 403 and duplicate reports return the existing report without creating another row.

- [ ] **Step 2: Add optional and moderator dependencies**

Implement `get_optional_current_account` so an absent Authorization header returns `None` while malformed/invalid supplied credentials return 401. Implement `require_moderator` using `Account.is_moderator`; do not authorize moderators by a client-supplied header.

- [ ] **Step 3: Add response identity needed by clients**

Add `id` to `CommunityAuthorResponse`, `author_id` and `is_owned_by_current_account` to post/comment responses, and pass the current optional account into response mappers. Do not expose phone numbers or Apple identifiers.

- [ ] **Step 4: Add safety endpoints**

Use constrained Pydantic models:

```python
class CommunityReportRequest(BaseModel):
    target_type: Literal["post", "comment"]
    target_id: str = Field(min_length=1, max_length=64)
    reason: Literal["illegal", "harassment", "privacy", "spam", "infringement", "other"]
    details: str = Field(default="", max_length=1000)

class ModerationDecisionRequest(BaseModel):
    status: Literal["resolved", "rejected"]
    resolution_note: str = Field(min_length=1, max_length=1000)
```

Apply the existing community write rate limiter to report and block mutations. Deleting content returns 204; unknown or non-owned content returns 404.

- [ ] **Step 5: Verify**

```bash
cd backend && ./.venv/bin/python -m pytest tests/test_community_safety_api.py tests/test_community_api.py tests/test_rate_limit.py -q
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/api/community.py backend/app/auth/dependencies.py backend/tests/test_community_safety_api.py
git commit -m "feat: expose community safety and moderation APIs"
```

## Task 7: iOS Account Controls and Legal Settings

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/AppSession.swift`
- Modify: `May/May/Screens/ProfileView.swift`
- Modify: `May/May/ContentView.swift`

- [ ] **Step 1: Add profile destinations**

Make all four legal entries available. Add “联系与投诉” using `mailto:youz66811@gmail.com` and “注销账号” as a destructive action. Keep operator data in one `LegalContact` constant:

```swift
enum LegalContact {
    static let operatorName = "孙裕凤"
    static let email = "youz66811@gmail.com"
}
```

- [ ] **Step 2: Implement deletion confirmation**

Show a first explanation sheet listing deleted data and lawful retention exceptions, then require the user to type `DELETE`. Call `AppAPIClient.deleteAccount(confirmation:"DELETE", token:)`; on 204 clear Keychain, local hardware profile `UserDefaults`, in-memory routes, and return to login. On failure keep the session and show a retryable error.

- [ ] **Step 3: Verify build and interaction rules**

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`; legal rows navigate, contact opens a mail URL, and deletion cannot submit before exact confirmation.

- [ ] **Step 4: Commit**

```bash
git add May/May/Networking/AppAPIClient.swift May/May/Models/AppSession.swift May/May/Screens/ProfileView.swift May/May/ContentView.swift
git commit -m "feat: add legal settings and account deletion"
```

## Task 8: iOS Community Safety and Publishing Controls

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/CommunityContent.swift`
- Modify: `May/May/Screens/CommunityView.swift`
- Modify: `May/May/Screens/CommunityDetailView.swift`
- Modify: `May/May/Screens/CommunityComposerView.swift`
- Modify: `May/MayTests/CommunityContentRulesTests.swift`

- [ ] **Step 1: Write failing action-rule tests**

Add assertions that an owned post exposes `.delete`, another user's post exposes `.report` and `.block`, report reasons map to the backend literals, and publishing is disabled until the community-guidelines acknowledgement is checked.

- [ ] **Step 2: Add typed client operations**

Implement authenticated `feed`, `createPost`, `deletePost`, `deleteComment`, `report`, `block`, and `unblock`. Encode report literals exactly as defined by the backend. Decode author IDs and ownership booleans; never infer ownership from nickname.

- [ ] **Step 3: Connect feed and safety menus**

Load the authenticated feed on appearance with loading, empty, and retry states. The ellipsis menu shows delete only for owned content; otherwise it shows report and block. Require confirmation for delete/block, optimistically remove deleted/blocked content, and restore it if the API fails.

- [ ] **Step 4: Make publishing truthful**

Show a link to `.communityGuidelines`, add an unchecked “我已阅读并遵守社区规范” control, disable publishing until checked and content is valid, and call `createPost`. Keep image selection/upload disabled with an explanatory message until the production object-storage provider is configured and disclosed; do not request photo permission for a nonworking upload.

- [ ] **Step 5: Run tests and build**

```bash
swiftc May/May/Models/AppNavigation.swift May/May/Models/CommunityContent.swift May/MayTests/CommunityContentRulesTests.swift -o /tmp/community-rules && /tmp/community-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `CommunityContentRulesTests passed` and `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add May/May/Networking/AppAPIClient.swift May/May/Models/CommunityContent.swift May/May/Screens/CommunityView.swift May/May/Screens/CommunityDetailView.swift May/May/Screens/CommunityComposerView.swift May/MayTests/CommunityContentRulesTests.swift
git commit -m "feat: connect community safety controls"
```

## Task 9: AI Notice, Progress Tracking, and Full Verification

**Files:**
- Modify: `May/May/Screens/AIBuildView.swift`
- Modify: `backend/progress.json`
- Modify: `docs/legal/release-compliance-checklist.md`

- [ ] **Step 1: Add the persistent AI notice**

Display `AIContentDisclosure.text` beside the generate action and on generated results. Use secondary text styling but do not hide it behind an info button. Confirm the existing backend payload sends budget, use case, preferences, notes, and candidate hardware only; add a regression assertion to `backend/tests/test_ai_provider.py` that phone/account fields are absent from the outgoing JSON.

- [ ] **Step 2: Update backend progress accurately**

Add a `user_privacy_community_safety` capability if none exists. Mark it complete only after migrations and all tests pass, set the completion date to the actual verification date, and update top-level `updated_at`/`current_phase` without changing unrelated progress entries.

- [ ] **Step 3: Run full backend verification**

```bash
cd backend && ./.venv/bin/python -m pytest -q
cd backend && ./.venv/bin/alembic heads
```

Expected: every backend test passes and exactly one Alembic head is printed: `20260621_0007`.

- [ ] **Step 4: Run full iOS verification**

```bash
swiftc May/May/Legal/LegalDocument.swift May/MayTests/LegalComplianceRulesTests.swift -o /tmp/legal-rules && /tmp/legal-rules
swiftc May/May/Models/AppNavigation.swift May/May/Models/CommunityContent.swift May/MayTests/CommunityContentRulesTests.swift -o /tmp/community-rules && /tmp/community-rules
plutil -lint May/May/PrivacyInfo.xcprivacy
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: both rule suites pass, plist lint passes, and `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Audit production blockers without falsely clearing them**

Re-read the final app packet, backend environment variable names, and legal files. Leave vendor selection, provider disclosure, App filing, image-object deletion, moderation staffing, and production data-region boxes unchecked until operator evidence exists. A passing test suite does not clear those operational blockers.

- [ ] **Step 6: Commit**

```bash
git add May/May/Screens/AIBuildView.swift backend/tests/test_ai_provider.py backend/progress.json docs/legal/release-compliance-checklist.md
git commit -m "chore: verify privacy compliance release controls"
```
