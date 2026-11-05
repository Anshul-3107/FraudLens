import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';
import '../navigation/app_shell.dart';

class PhoneOnboardingScreen extends StatefulWidget {
  const PhoneOnboardingScreen({super.key});

  @override
  State<PhoneOnboardingScreen> createState() => _PhoneOnboardingScreenState();
}

enum OnboardingStep { enterPhone, enterOtp, linkBank }

class _PhoneOnboardingScreenState extends State<PhoneOnboardingScreen> {
  OnboardingStep _step = OnboardingStep.enterPhone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _accountController = TextEditingController();
  String _selectedBank = 'HDFC Bank';

  static const List<String> kPopularBanks = [
    'HDFC Bank',
    'State Bank of India (SBI)',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab National Bank (PNB)',
    'Bank of Baroda',
    'Canara Bank',
    'Union Bank of India',
    'Federal Bank',
  ];

  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _accountController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    final formattedPhone = rawPhone.startsWith('+') ? rawPhone : '+91$rawPhone';
    final auth = context.read<AuthProvider>();

    final success = await auth.sendOtp(formattedPhone);
    if (!mounted) return;

    if (success) {
      _startResendTimer();
      setState(() => _step = OnboardingStep.enterOtp);
      if (auth.devOtp != null && auth.devOtp!.isNotEmpty) {
        _otpController.text = auth.devOtp!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test Mode OTP: ${auth.devOtp} (Logged to console)'),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code sent to $formattedPhone')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Failed to send verification code')),
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit verification code')),
      );
      return;
    }

    final rawPhone = _phoneController.text.trim();
    final formattedPhone = rawPhone.startsWith('+') ? rawPhone : '+91$rawPhone';
    final auth = context.read<AuthProvider>();

    final success = await auth.verifyOtp(formattedPhone, code);
    if (!mounted) return;

    if (success) {
      setState(() => _step = OnboardingStep.linkBank);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Verification failed')),
      );
    }
  }

  Future<void> _handleLinkBank() async {
    final acc = _accountController.text.trim();
    if (acc.isEmpty || acc.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your account or card number (at least 4 digits)')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final cardProvider = context.read<CardProvider>();

    final success = await auth.linkBankAccount(
      bankName: _selectedBank,
      accountNumber: acc,
    );
    if (!mounted) return;

    if (success) {
      // Refresh cards in CardProvider
      await cardProvider.loadCards();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Failed to link bank account')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Bank Account'),
        leading: _step != OnboardingStep.enterPhone
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_step == OnboardingStep.enterOtp) {
                    setState(() => _step = OnboardingStep.enterPhone);
                  } else if (_step == OnboardingStep.linkBank) {
                    setState(() => _step = OnboardingStep.enterOtp);
                  }
                },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon & Title
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _step == OnboardingStep.enterPhone
                        ? Icons.phone_android_rounded
                        : _step == OnboardingStep.enterOtp
                            ? Icons.mark_email_read_rounded
                            : Icons.account_balance_rounded,
                    color: colors.primary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                _step == OnboardingStep.enterPhone
                    ? 'Verify Mobile Number'
                    : _step == OnboardingStep.enterOtp
                        ? 'Enter Verification Code'
                        : 'Link Primary Bank Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                _step == OnboardingStep.enterPhone
                    ? 'Enter your registered mobile number to connect your bank account and receive instant fraud alerts.'
                    : _step == OnboardingStep.enterOtp
                        ? 'We sent a 6-digit code to ${_phoneController.text.trim()}. Enter it below to authenticate.'
                        : 'Connect your primary bank or card. Transactions will begin monitoring from #1.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 28),

              // Step 1: Phone input
              if (_step == OnboardingStep.enterPhone) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '9876543210',
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 18,
                            color: colors.border,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Verification Code'),
                ),
              ],

              // Step 2: OTP input
              if (_step == OnboardingStep.enterOtp) ...[
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 16,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-Digit OTP',
                    hintText: '••••••',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _resendCountdown > 0
                          ? 'Resend code in ${_resendCountdown}s'
                          : "Didn't receive code?",
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    if (_resendCountdown == 0)
                      TextButton(
                        onPressed: auth.isLoading ? null : _handleSendOtp,
                        child: const Text('Resend Code'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify & Continue'),
                ),
              ],

              // Step 3: Link Bank Account
              if (_step == OnboardingStep.linkBank) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Select Bank',
                    prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                  ),
                  items: kPopularBanks.map((b) {
                    return DropdownMenuItem<String>(
                      value: b,
                      child: Text(b, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBank = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bank Account Number / Card Number',
                    hintText: 'e.g. 50100492819719',
                    prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only the last 4 digits are stored securely to match incoming Google Pay / PhonePe UPI notifications.',
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: auth.isLoading ? null : _handleLinkBank,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Link Account & Start Monitoring'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
