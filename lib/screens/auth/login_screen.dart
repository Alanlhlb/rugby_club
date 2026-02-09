import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/event_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../models/app_user.dart' show UserRole;
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _isLogin = true;
  bool _rememberMe = false;
  bool _obscurePass = true;
  UserRole _selectedRole = UserRole.player;

  static const _storage = FlutterSecureStorage();
  static const _keyEmail = 'saved_email';
  static const _keyPass = 'saved_pass';
  static const _keyRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final remember = await _storage.read(key: _keyRemember);
    if (remember == 'true') {
      final email = await _storage.read(key: _keyEmail) ?? '';
      final pass = await _storage.read(key: _keyPass) ?? '';
      if (mounted) {
        setState(() {
          _rememberMe = true;
          _email.text = email;
          _pass.text = pass;
        });
      }
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: _keyRemember, value: 'true');
      await _storage.write(key: _keyEmail, value: _email.text.trim());
      await _storage.write(key: _keyPass, value: _pass.text);
    } else {
      await _storage.delete(key: _keyRemember);
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPass);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = _isLogin
        ? await auth.signIn(_email.text.trim(), _pass.text)
        : await auth.signUp(
            _email.text.trim(),
            _pass.text,
            _name.text.trim(),
            role: _selectedRole,
          );
    if (!mounted) return;
    if (ok) {
      await _saveCredentials();
      if (!mounted) return;
      final user = auth.currentUser;
      if (user?.teamId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        // Load team first, then fire-and-forget players/events
        final teamId = user!.teamId!;
        final tp = context.read<TeamProvider>();
        final pp = context.read<PlayerProvider>();
        final ep = context.read<EventProvider>();
        await tp.loadTeam(teamId);
        if (!mounted) return;
        final seasonId = tp.currentSeason?.id;
        // ignore: unawaited_futures
        pp.loadPlayers(teamId, seasonId: seasonId);
        // ignore: unawaited_futures
        ep.loadEvents(teamId, seasonId: seasonId);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error ?? '登入失敗，請重試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingLg),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.sports_rugby,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RUGBY CLUB',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (!_isLogin) ...[
                    // ─── Role selector ───
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.admin,
                          label: Text('管理員'),
                          icon: Icon(Icons.admin_panel_settings, size: 16),
                        ),
                        ButtonSegment(
                          value: UserRole.coach,
                          label: Text('教練'),
                          icon: Icon(Icons.sports, size: 16),
                        ),
                        ButtonSegment(
                          value: UserRole.player,
                          label: Text('球員'),
                          icon: Icon(Icons.person, size: 16),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (s) =>
                          setState(() => _selectedRole = s.first),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: '姓名',
                        prefixIcon: Icon(Icons.person, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '請輸入姓名' : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: '電子郵件',
                      prefixIcon: Icon(Icons.email, size: 20),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '請輸入電子郵件';
                      if (!v.contains('@')) return '請輸入有效的電子郵件';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass,
                    decoration: InputDecoration(
                      labelText: '密碼',
                      prefixIcon: const Icon(Icons.lock, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    obscureText: _obscurePass,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '請輸入密碼';
                      if (v.length < 6) return '密碼至少需要 6 個字元';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: const Text(
                          '記住帳號密碼',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Consumer<AuthProvider>(
                    builder: (ctx, auth, _) => SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(_isLogin ? '登入' : '註冊'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? '沒有帳號？前往註冊' : '已有帳號？前往登入'),
                  ),
                  if (_isLogin)
                    TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text(
                        '忘記密碼？',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword() {
    final resetEmail = TextEditingController(text: _email.text.trim());
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('重設密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('輸入您的電子郵件，我們將發送重設密碼的連結。'),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: TextField(
                controller: resetEmail,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  prefixIcon: Icon(Icons.email, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final email = resetEmail.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('請輸入有效的電子郵件')));
                return;
              }
              final scaffold = ScaffoldMessenger.of(context);
              try {
                await context.read<AuthProvider>().resetPassword(email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  scaffold.showSnackBar(
                    const SnackBar(content: Text('重設密碼郵件已發送，請查看您的信箱')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('發送失敗，請確認電子郵件是否正確')),
                  );
                }
              }
            },
            child: const Text('發送'),
          ),
        ],
      ),
    );
  }
}
