import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Driver',
      debugShowCheckedModeBanner: false,
      // Follows the device language; falls back to English for anything else.
      supportedLocales: Strings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.instance.authState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.hasData ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
