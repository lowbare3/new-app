import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/socket_service.dart';

void main() {
  runApp(const SheRideApp());
}

class SheRideApp extends StatelessWidget {
  const SheRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheRide',
      theme: SheRideTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
