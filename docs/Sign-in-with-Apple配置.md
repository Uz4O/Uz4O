# Sign in with Apple 配置与验证

## 已接入的登录链路

1. iOS 使用系统 `SignInWithAppleButton` 发起授权。
2. App 为每次授权生成随机 raw nonce，并把它的 SHA-256 值放进 Apple 授权请求。
3. App 把 Apple 返回的 identity token、authorization code 和 raw nonce 发送到 `POST /v1/auth/apple/login`。
4. 后端通过 Apple JWKS 校验 identity token 的签名、issuer、audience、有效期和 nonce，再按稳定的 `sub` 创建或复用账号。
5. 后端签发 UzBox access token，iOS 继续用现有 Keychain 保存并在后续启动时恢复会话。

邮箱不是账号主键。用户可能选择“隐藏我的邮箱”，后端始终以 Apple token 中稳定的 `sub` 关联账号。

## Apple Developer 与 Xcode

1. 在 Apple Developer 的 Identifiers 中打开 App ID `top.uzbox.app`。
2. 为该 App ID 启用 **Sign in with Apple**，并保持其为 Primary App ID（除非团队已有明确的分组方案）。
3. 重新生成或刷新包含该 capability 的开发与发布 provisioning profile。Xcode 使用 Automatic Signing 时通常会自动处理。
4. Xcode target `May` 已加入 **Sign in with Apple** capability；仓库内的 `May/May/May.entitlements` 声明了 `com.apple.developer.applesignin = Default`。
5. 用真实 Apple Developer Team 签名。真机需登录可用于测试的 Apple ID；Simulator 也必须具备可用 Apple ID 登录状态。

原生 iOS 登录不需要 Web Service ID、回调 URL 或 Apple client secret。这里校验的 audience 是 App 的 bundle identifier。

## 后端配置

生产环境必须至少配置：

```dotenv
APP_APPLE_LOGIN_CLIENT_ID=top.uzbox.app
APP_AUTH_TOKEN_SECRET=<随机且足够长的生产密钥>
```

`APP_APPLE_LOGIN_CLIENT_ID` 必须与 Xcode 的 `PRODUCT_BUNDLE_IDENTIFIER` 完全一致。修改服务器环境后重启当前 `ai-builder-api.service`，不要使用仓库中已过期的 `backend/scripts/deploy.sh`。

配置状态可通过健康检查确认：

```bash
curl https://api.uzbox.top/health
```

返回中的 `security.apple_login` 应为 `configured`，且 `production.blocking_items` 不应再包含 `apple_login_not_configured`。健康检查只说明服务端配置存在；完整登录仍需一次真实 Apple 授权验证。

## 接口契约

```json
{
  "identity_token": "<Apple JWT>",
  "authorization_code": "<Apple authorization code，可选>",
  "nonce": "<本次授权的 raw nonce>"
}
```

服务端不会接受缺少 nonce、nonce 与 JWT claim 不匹配、签名无效、issuer/audience 不匹配或已过期的 token。不要把 identity token、authorization code、raw nonce 或 UzBox access token 写入日志。

## 上线前人工验收

1. 在真机安装使用发布签名的构建，勾选协议后点击系统 Apple 登录按钮。
2. 首次授权分别验证“共享邮箱”和“隐藏我的邮箱”；两种选择都应登录成功。
3. 退出并再次用同一 Apple ID 登录，确认复用同一账号。
4. 杀掉 App 后重新打开，确认 Keychain 会话恢复且不重复弹出登录页。
5. 在 Apple ID 设置中停止使用 UzBox 后重新授权，确认仍能安全完成授权；不要假设 Apple 每次都会返回姓名或邮箱。
6. 删除账号后确认本地 Keychain token 被清除，App 回到登录页。
