import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String name;
  const OtpScreen({super.key, required this.phone, required this.name});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _userId;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verify() {
    final otp = _otpController.text.trim();
    if (otp != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Use 123456 for demo.')),
      );
      return;
    }

    setState(() => _loading = true);
    ApiService.login(widget.phone, widget.name).then((res) {
      if (res['success'] == true) {
        final user = res['user'];
        _userId = user['id'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(userId: user['id'], phone: widget.phone, name: widget.name),
          ),
        );
      } else {
        throw Exception('Login failed');
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: SheRideTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('🔐', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              const Text('Verify OTP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('OTP sent to ${widget.phone}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: SheRideTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Demo OTP: 123456', style: TextStyle(color: SheRideTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const Spacer(),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & Continue'),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
