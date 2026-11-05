import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _kCurrencyModeKey = 'fraudlens_currency_mode';
  static const String _kCurrencyCodeKey = 'fraudlens_currency_code';
  static const String _kRegionCodeKey = 'fraudlens_region_code';
  static const String _kExchangeRatesKey = 'fraudlens_exchange_rates';
  static const String _kRatesLastUpdatedKey = 'fraudlens_exchange_rates_updated';

  CurrencyMode _mode = CurrencyMode.auto;
  String _detectedCurrency = 'USD';
  String _selectedCurrency = 'USD';
  String _selectedRegion = 'US';
  Map<String, double> _exchangeRates = {};
  String? _ratesLastUpdated;
  bool _isSyncingRates = false;
  bool _initialized = false;

  CurrencyProvider() {
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();
    _selectedCurrency = _detectedCurrency;
    _selectedRegion = _currencyToRegionCode(_selectedCurrency);
  }

  bool get isInitialized => _initialized;
  CurrencyMode get mode => _mode;
  bool get isAutoMode => _mode == CurrencyMode.auto;
  bool get isAuto => isAutoMode;
  String get detectedCurrency => _detectedCurrency;
  String get activeCurrency => _selectedCurrency;
  String get activeRegionCode => _selectedRegion;
  String? get ratesLastUpdated => _ratesLastUpdated;
  bool get isSyncingRates => _isSyncingRates;

  CurrencyInfo get activeCurrencyInfo =>
      CurrencyService.supportedCurrencies[_selectedCurrency] ??
      CurrencyService.supportedCurrencies['USD']!;

  RegionInfo get activeRegionInfo =>
      CurrencyService.supportedRegions.firstWhere(
        (r) => r.countryCode == _selectedRegion,
        orElse: () => CurrencyService.supportedRegions.firstWhere(
          (r) => r.currencyCode == _selectedCurrency,
          orElse: () => CurrencyService.supportedRegions[0],
        ),
      );

  bool get isConvertedFromUsd => _selectedCurrency != 'USD';

  double get activeRateFromUsd {
    if (_selectedCurrency == 'USD') return 1.0;
    return _exchangeRates[_selectedCurrency] ??
        activeCurrencyInfo.defaultRateFromUsd;
  }

  static String _currencyToRegionCode(String curr) {
    for (final reg in CurrencyService.supportedRegions) {
      if (reg.currencyCode == curr) return reg.countryCode;
    }
    return 'US';
  }

  /// Initialize and load saved currency & regional preferences.
  Future<void> initialize() async {
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedMode = prefs.getString(_kCurrencyModeKey);
      final savedCode = prefs.getString(_kCurrencyCodeKey);
      final savedRegion = prefs.getString(_kRegionCodeKey);
      final savedRates = prefs.getString(_kExchangeRatesKey);
      _ratesLastUpdated = prefs.getString(_kRatesLastUpdatedKey);

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
        _selectedRegion = savedRegion ?? _currencyToRegionCode(savedCode);
      } else {
        _mode = CurrencyMode.auto;
        _selectedCurrency = _detectedCurrency;
        _selectedRegion = _currencyToRegionCode(_detectedCurrency);
      }
    } catch (_) {
      _mode = CurrencyMode.auto;
      _selectedCurrency = _detectedCurrency;
      _selectedRegion = _currencyToRegionCode(_detectedCurrency);
    } finally {
      _initialized = true;
      notifyListeners();
    }

    // Attempt background live rate sync from backend and IP location verification
    syncRatesFromBackend();
    _verifyNetworkLocation();
  }

  void _verifyNetworkLocation() {
    CurrencyService.detectCurrencyFromNetwork().then((netCurrency) {
      if (netCurrency != null && _mode == CurrencyMode.auto) {
        _detectedCurrency = netCurrency;
        if (_selectedCurrency != netCurrency) {
          _selectedCurrency = netCurrency;
          _selectedRegion = _currencyToRegionCode(netCurrency);
          notifyListeners();
        }
      }
    });
  }

  /// Background sync with Django /api/exchange-rates/ endpoint
  Future<void> syncRatesFromBackend() async {
    if (_isSyncingRates) return;
    _isSyncingRates = true;

    try {
      final freshRates = await CurrencyService.fetchRatesFromBackend();
      if (freshRates != null && freshRates.isNotEmpty) {
        _exchangeRates = freshRates;
        _ratesLastUpdated = DateTime.now().toLocal().toString().substring(11, 16);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kExchangeRatesKey, jsonEncode(_exchangeRates));
        await prefs.setString(_kRatesLastUpdatedKey, _ratesLastUpdated!);
      }
    } catch (_) {
      // Retain existing cached or fallback rates
    } finally {
      _isSyncingRates = false;
      notifyListeners();
    }
  }

  /// Select a region (e.g. 'IN', 'US', 'GB', 'EU'). Automatically updates currency.
  Future<void> selectRegion(String countryCode) async {
    final region = CurrencyService.supportedRegions.firstWhere(
      (r) => r.countryCode == countryCode,
      orElse: () => CurrencyService.supportedRegions[0],
    );

    _mode = CurrencyMode.manual;
    _selectedRegion = region.countryCode;
    _selectedCurrency = region.currencyCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCurrencyModeKey, 'manual');
      await prefs.setString(_kCurrencyCodeKey, _selectedCurrency);
      await prefs.setString(_kRegionCodeKey, _selectedRegion);
    } catch (_) {}
  }

  /// Switch back to automatic regional detection.
  Future<void> setAutoMode() async {
    _mode = CurrencyMode.auto;
    _detectedCurrency = CurrencyService.detectCurrencyFromLocale();
    _selectedCurrency = _detectedCurrency;
    _selectedRegion = _currencyToRegionCode(_detectedCurrency);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCurrencyModeKey, 'auto');
      await prefs.remove(_kCurrencyCodeKey);
      await prefs.remove(_kRegionCodeKey);
    } catch (_) {}

    _verifyNetworkLocation();
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
