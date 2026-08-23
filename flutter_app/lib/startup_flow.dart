import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/uzbox_api.dart';
import 'app_theme.dart';
import 'main_shell.dart';

class StartupFlow extends StatefulWidget {
  const StartupFlow({super.key, this.api});

  final UzBoxAuthClient? api;

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController transitionController;
  bool showsSplash = true;
  bool showsMain = false;
  late final UzBoxAuthClient api = widget.api ?? UzBoxApi();

  @override
  void initState() {
    super.initState();
    transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void dispose() {
    transitionController.dispose();
    super.dispose();
  }

  Future<void> _enterMain() async {
    setState(() => showsMain = true);
    await transitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showsMain)
          const MainShell()
        else if (!showsSplash)
          LoginScreen(onLogin: _enterMain, api: api),
        if (showsSplash)
          AppSplashScreen(onFinish: () => setState(() => showsSplash = false)),
        if (showsMain && transitionController.value < 1)
          _HomeWordmarkTransition(animation: transitionController),
      ],
    );
  }
}

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  bool visible = false;
  bool exiting = false;
  bool didPrecacheHero = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (didPrecacheHero) return;
    didPrecacheHero = true;
    unawaited(
      precacheImage(
        const ResizeImage(
          AssetImage('assets/images/login_hardware_hero.png'),
          width: 1200,
        ),
        context,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => setState(() => visible = true));
    unawaited(_run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => exiting = true);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted) widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 730;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: exiting ? 0 : 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          child: AnimatedScale(
            scale: visible ? (exiting ? 1.035 : 1) : .88,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                Spacer(flex: compact ? 3 : 4),
                Text(
                  'Uz',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: compact ? 116 : 154,
                    height: .88,
                    fontWeight: FontWeight.w900,
                    letterSpacing: compact ? -12 : -16,
                  ),
                ),
                SizedBox(height: compact ? 18 : 28),
                Text(
                  'UzBox',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: compact ? 32 : 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 装机助手',
                  style: TextStyle(
                    color: const Color(0xFF474747),
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '智能推荐最佳配置方案，让装机更简单',
                  style: TextStyle(
                    color: const Color(0xFF9E9E9E),
                    fontSize: compact ? 12 : 14,
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin, this.api});

  final VoidCallback onLogin;
  final UzBoxAuthClient? api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool accepted = false;
  bool isAuthenticating = false;
  late final UzBoxAuthClient api = widget.api ?? UzBoxApi();

  Future<void> _login() async {
    if (!accepted || isAuthenticating) return;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIos) {
      // The iOS Apple Sign-In bridge remains a separate integration point.
      // Keep the existing transition until its native credential exchange is
      // configured; Android never takes this path.
      setState(() => isAuthenticating = true);
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (mounted) widget.onLogin();
      return;
    }

    setState(() => isAuthenticating = true);
    final authenticated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhoneLoginSheet(api: api),
    );
    if (!mounted) return;
    setState(() => isAuthenticating = false);
    if (authenticated == true) widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 730;
            final horizontal = (constraints.maxWidth * .075).clamp(24.0, 34.0);
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                compact ? 10 : 18,
                horizontal,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UzBox',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: compact ? 23 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 10),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Image.asset(
                        'assets/images/login_hardware_hero.png',
                        cacheWidth: 1200,
                        cacheHeight: 1000,
                        height: compact ? 245 : 310,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Text(
                    '更聪明地\n装好一台电脑',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: compact ? 33 : 36,
                      height: compact ? 1.06 : 1.13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  const Text(
                    '从需求到配置，UzBox 帮你做出更稳妥的选择',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: TextStyle(color: Color(0xFF858585), fontSize: 14),
                  ),
                  SizedBox(height: compact ? 42 : 58),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: SizedBox(
                        width: double.infinity,
                        height: compact ? 54 : 58,
                        child: FilledButton.icon(
                          onPressed: accepted ? _login : _showConsentReminder,
                          icon: isAuthenticating
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isIos
                                      ? Icons.apple_rounded
                                      : Icons.phone_iphone_rounded,
                                  size: isIos ? 24 : 22,
                                ),
                          label: Text(
                            isAuthenticating
                                ? '正在登录'
                                : isIos
                                ? '通过 Apple 登录'
                                : '本机号码一键登录',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  Center(
                    child: Text(
                      isIos ? '使用 Apple 账号安全登录' : '由运营商提供本机号码认证服务',
                      style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: InkWell(
                      onTap: () => setState(() => accepted = !accepted),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: accepted ? Colors.black : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accepted
                                      ? Colors.black
                                      : const Color(0xFFB9B9B9),
                                ),
                              ),
                              child: accepted
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              '我已阅读并同意《用户协议》和《隐私政策》',
                              style: TextStyle(
                                color: Color(0xFF737373),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showConsentReminder() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('请先阅读并同意'),
        content: const Text('请先阅读并同意用户协议和隐私政策。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _PhoneLoginSheet extends StatefulWidget {
  const _PhoneLoginSheet({required this.api});

  final UzBoxAuthClient api;

  @override
  State<_PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends State<_PhoneLoginSheet> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  Timer? countdownTimer;
  int countdown = 0;
  bool sending = false;
  bool loggingIn = false;
  bool codeSent = false;
  String? error;
  String? debugCode;

  @override
  void dispose() {
    countdownTimer?.cancel();
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => error = '请输入有效的中国大陆手机号码');
      return;
    }
    if (sending || countdown > 0) return;
    setState(() {
      sending = true;
      error = null;
      debugCode = null;
    });
    try {
      final result = await widget.api.sendSmsCode(phone);
      if (!mounted) return;
      setState(() {
        sending = false;
        codeSent = result.sent;
        // The backend only includes this field in explicit debug mode.  It is
        // useful for local simulator verification but is never generated by a
        // real provider response.
        debugCode = result.debugCode;
        if (!result.sent) error = '验证码发送失败，请稍后重试';
      });
      if (result.sent) _startCountdown();
    } on UzBoxApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        sending = false;
        error = exception.message;
      });
    }
  }

  Future<void> _login() async {
    final phone = phoneController.text.trim();
    final code = codeController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => error = '请输入有效的中国大陆手机号码');
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      setState(() => error = '请输入短信验证码');
      return;
    }
    if (loggingIn) return;
    setState(() {
      loggingIn = true;
      error = null;
    });
    try {
      await widget.api.loginWithSmsCode(phone: phone, code: code);
      if (mounted) Navigator.of(context).pop(true);
    } on UzBoxApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        loggingIn = false;
        error = exception.message;
      });
    }
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    setState(() => countdown = 60);
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (countdown <= 1) {
        timer.cancel();
        setState(() => countdown = 0);
      } else {
        setState(() => countdown -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * .92;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            key: const ValueKey('phone-login-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D4D4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '手机号登录',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                const Text(
                  '运营商一键登录 SDK 尚未配置，当前使用短信验证码登录。',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '手机号码',
                    hintText: '请输入中国大陆手机号码',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: '短信验证码',
                          hintText: '请输入验证码',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(15)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: sending || countdown > 0 ? null : _sendCode,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          sending
                              ? '发送中'
                              : countdown > 0
                              ? '${countdown}s'
                              : codeSent
                              ? '重新发送'
                              : '获取验证码',
                        ),
                      ),
                    ),
                  ],
                ),
                if (debugCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '开发环境验证码：$debugCode',
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFD14343),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: loggingIn ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: loggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '登录并继续',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidPhone(String value) =>
      RegExp(r'^1[3-9]\d{9}$').hasMatch(value) ||
      RegExp(r'^\+861[3-9]\d{9}$').hasMatch(value);
}

class _HomeWordmarkTransition extends StatelessWidget {
  const _HomeWordmarkTransition({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final safeTop = MediaQuery.paddingOf(context).top;
          final curved = Curves.easeInOutCubicEmphasized.transform(
            animation.value,
          );
          final left = Tween<double>(
            begin: size.width / 2 - 54,
            end: 22,
          ).transform(curved);
          final top = Tween<double>(
            begin: size.height / 2 - 24,
            end: safeTop + 12,
          ).transform(curved);
          final fontSize = Tween<double>(begin: 38, end: 28).transform(curved);
          final opacity = animation.value < .78
              ? 1.0
              : (1 - (animation.value - .78) / .22).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: (1 - curved) * .88),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    'UzBox',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
