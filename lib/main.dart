import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'pages/auth_page.dart';
import 'pages/main_navigation_page.dart';
import 'pages/reset_password_page.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  // Khởi tạo tùy chọn Theme và Ngôn ngữ đã lưu của người dùng
  await ThemeController.instance.initialize();
  await LocaleController.instance.initialize();

  runApp(const WashCareApp());
}

class WashCareApp extends StatelessWidget {
  const WashCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance;
    final localeController = LocaleController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'WashCare',
          debugShowCheckedModeBanner: false,

          // Cấu hình Theme Sáng / Tối
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,

          // Cấu hình Đa ngôn ngữ (VI / EN)
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        supabase.auth.onAuthStateChange.listen((authState) {
          if (!mounted) return;

        if (authState.event == AuthChangeEvent.passwordRecovery) {
          setState(() {
            _isPasswordRecovery = true;
          });
        } else if (authState.event == AuthChangeEvent.signedOut) {
          setState(() {
            _isPasswordRecovery = false;
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Không thể cập nhật phiên đăng nhập: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecovery) {
      return const ResetPasswordPage();
    }

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (supabase.auth.currentSession != null) {
          return const MainNavigationPage();
        }

        return const AuthPage();
      },
    );
  }
}
