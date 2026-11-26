import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
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

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkBank() async {
    final acc = _accountController.text.trim();
    if (acc.isEmpty || acc.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your account or card number (at least 4 digits)',
          ),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final cardProvider = context.read<CardProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.linkBankAccount(
      bankName: _selectedBank,
      accountNumber: acc,
    );
    if (!mounted) return;

    if (success) {
      await cardProvider.loadCards();
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('$_selectedBank linked successfully')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to link bank account'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Link Bank Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.primaryBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_outlined,
                          color: colors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connect an Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Only the last 4 digits are stored to match your incoming payment alerts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedBank,
                      decoration: const InputDecoration(
                        labelText: 'Bank',
                        prefixIcon: Icon(
                          Icons.account_balance_outlined,
                          size: 20,
                        ),
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _accountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Account or Card Number',
                        hintText: 'Last 4+ digits (e.g. 9719)',
                        prefixIcon: Icon(Icons.credit_card_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleLinkBank,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Link Account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
