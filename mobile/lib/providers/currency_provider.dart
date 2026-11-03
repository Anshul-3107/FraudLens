import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _kCurrencyModeKey = 'fraudlens_currency_mode';
  static const String _kCurrencyCodeKey = 'fraudlens_currency_code';
  static const String _kExchangeRatesKey = 'fraudlens_exchange_rates';

  CurrencyMode _mode = CurrencyMode.auto;
  String _detectedCurrency = 'USD';
  String _selectedCurrency = 'USD';
  Map<String, double> _exchangeRates = {};
  bool _initialized = false;

  CurrencyProvider() {
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();
    _selectedCurrency = _detectedCurrency;
  }

  bool get isInitialized => _initialized;
  CurrencyMode get mode => _mode;
  bool get isAutoMode => _mode == CurrencyMode.auto;
  bool get isAuto => isAutoMode;
  String get detectedCurrency => _detectedCurrency;
  String get activeCurrency => _selectedCurrency;

  CurrencyInfo get activeCurrencyInfo =>
      CurrencyService.supportedCurrencies[_selectedCurrency] ??
      CurrencyService.supportedCurrencies['USD']!;

  bool get isConvertedFromUsd => _selectedCurrency != 'USD';

  double get activeRateFromUsd {
    if (_selectedCurrency == 'USD') return 1.0;
    return _exchangeRates[_selectedCurrency] ??
        activeCurrencyInfo.defaultRateFromUsd;
  }

  /// Initialize and load saved currency preferences.
  Future<void> initialize() async {
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedMode = prefs.getString(_kCurrencyModeKey);
      final savedCode = prefs.getString(_kCurrencyCodeKey);
      final savedRates = prefs.getString(_kExchangeRatesKey);

      if (savedRates != null) {
        try {
          final decoded = jsonDecode(savedRates) as Map<String, dynamic>;
          _exchangeRates = decoded.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );
        } catch (_) {}
      }

      if (savedMode == 'manual' &&
          savedCode != null &&
          CurrencyService.supportedCurrencies.containsKey(savedCode)) {
        _mode = CurrencyMode.manual;
        _selectedCurrency = savedCode;
      } else {
        _mode = CurrencyMode.auto;
        _selectedCurrency = _detectedCurrency;
      }
    } catch (_) {
      _mode = CurrencyMode.auto;
      _selectedCurrency = _detectedCurrency;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Switch back to automatic regional detection.
  Future<void> setAutoMode() async {
    _mode = CurrencyMode.auto;
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();
    _selectedCurrency = _detectedCurrency;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCurrencyModeKey, 'auto');
      await prefs.remove(_kCurrencyCodeKey);
    } catch (_) {}
  }

  /// Switch mode explicitly.
  Future<void> setMode(CurrencyMode mode) async {
    if (mode == CurrencyMode.auto) {
      await setAutoMode();
    } else {
      await setManualCurrency(_selectedCurrency);
    }
  }

  /// Manually select an override currency.
  Future<void> setManualCurrency(String code) async {
    if (!CurrencyService.supportedCurrencies.containsKey(code)) return;

    _mode = CurrencyMode.manual;
    _selectedCurrency = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCurrencyModeKey, 'manual');
      await prefs.setString(_kCurrencyCodeKey, code);
    } catch (_) {}
  }

  /// Formats amount in active currency.
  String format(double amount, {bool isSourceUsd = true, int? decimalDigits}) {
    return CurrencyService.formatAmount(
      amount,
      currencyCode: _selectedCurrency,
      isSourceUsd: isSourceUsd,
      decimalDigits: decimalDigits,
      customRates: _exchangeRates,
    );
  }

  /// Compact formatting (e.g. for charts).
  String formatCompact(double amount, {bool isSourceUsd = true}) {
    return CurrencyService.formatCompactAmount(
      amount,
      currencyCode: _selectedCurrency,
      isSourceUsd: isSourceUsd,
      customRates: _exchangeRates,
    );
  }

  /// Converts USD to display currency value (numerical).
  double convertFromUsd(double usdAmount) {
    return CurrencyService.convertFromUsd(
      usdAmount,
      _selectedCurrency,
      _exchangeRates,
    );
  }

  /// Converts display currency value to USD (numerical).
  double convertToUsd(double displayAmount) {
    return CurrencyService.convertToUsd(
      displayAmount,
      _selectedCurrency,
      _exchangeRates,
    );
  }

  /// Full details of conversion (useful for detail screen audit trails).
  ConvertedAmountDetails getDetails(double usdAmount) {
    return CurrencyService.getConversionDetails(
      usdAmount,
      _selectedCurrency,
      _exchangeRates,
    );
  }
}
