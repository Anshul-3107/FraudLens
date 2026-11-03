import 'dart:ui';

import 'package:intl/intl.dart';

enum CurrencyMode { auto, manual }

class CurrencyInfo {
  final String code; // e.g. 'INR', 'USD', 'GBP', 'EUR'
  final String name; // e.g. 'Indian Rupee'
  final String symbol; // e.g. '₹', '$', '£', '€'
  final String locale; // e.g. 'en_IN', 'en_US', 'en_GB', 'en_IE'
  final double defaultRateFromUsd; // Pegged / fallback rate against 1 USD
  final String flagEmoji;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.locale,
    required this.defaultRateFromUsd,
    required this.flagEmoji,
  });
}

class ConvertedAmountDetails {
  final double originalAmount;
  final String originalCurrency;
  final double convertedAmount;
  final String targetCurrency;
  final double rate;
  final DateTime timestamp;

  ConvertedAmountDetails({
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedAmount,
    required this.targetCurrency,
    required this.rate,
    required this.timestamp,
  });

  String get originalFormatted => CurrencyService.formatAmount(
    originalAmount,
    currencyCode: originalCurrency,
    isSourceUsd: false,
  );

  String get convertedFormatted => CurrencyService.formatAmount(
    convertedAmount,
    currencyCode: targetCurrency,
    isSourceUsd: false,
  );

  String get rateDescription =>
      '1 $originalCurrency = ${rate.toStringAsFixed(2)} $targetCurrency';
}

class CurrencyService {
  static const String baseCurrency = 'USD';

  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'INR': CurrencyInfo(
      code: 'INR',
      name: 'Indian Rupee',
      symbol: '₹',
      locale: 'en_IN',
      defaultRateFromUsd: 86.50,
      flagEmoji: '🇮🇳',
    ),
    'USD': CurrencyInfo(
      code: 'USD',
      name: 'US Dollar',
      symbol: '\$',
      locale: 'en_US',
      defaultRateFromUsd: 1.0,
      flagEmoji: '🇺🇸',
    ),
    'GBP': CurrencyInfo(
      code: 'GBP',
      name: 'British Pound',
      symbol: '£',
      locale: 'en_GB',
      defaultRateFromUsd: 0.79,
      flagEmoji: '🇬🇧',
    ),
    'EUR': CurrencyInfo(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      locale: 'en_IE',
      defaultRateFromUsd: 0.92,
      flagEmoji: '🇪🇺',
    ),
  };

  static const Map<String, String> _countryToCurrency = {
    'IN': 'INR',
    'US': 'USD',
    'GB': 'GBP',
    'UK': 'GBP',
    // Eurozone countries
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'BE': 'EUR',
    'AT': 'EUR',
    'IE': 'EUR',
    'PT': 'EUR',
    'FI': 'EUR',
    'GR': 'EUR',
    'LU': 'EUR',
    'CY': 'EUR',
    'MT': 'EUR',
    'SK': 'EUR',
    'SI': 'EUR',
    'EE': 'EUR',
    'LV': 'EUR',
    'LT': 'EUR',
  };

  /// Detects the regional currency from device locale.
  static String detectCurrencyFromLocale([Locale? locale]) {
    final effectiveLocale = locale ?? PlatformDispatcher.instance.locale;
    final countryCode = effectiveLocale.countryCode?.toUpperCase();
    if (countryCode != null && _countryToCurrency.containsKey(countryCode)) {
      return _countryToCurrency[countryCode]!;
    }
    // Check language code as fallback
    if (effectiveLocale.languageCode.toLowerCase() == 'hi') {
      return 'INR';
    }
    return baseCurrency;
  }

  /// Converts a USD-denominated amount into target currency.
  static double convertFromUsd(
    double usdAmount,
    String targetCurrencyCode, [
    Map<String, double>? rates,
  ]) {
    if (targetCurrencyCode == baseCurrency) return usdAmount;
    final rate =
        rates?[targetCurrencyCode] ??
        supportedCurrencies[targetCurrencyCode]?.defaultRateFromUsd ??
        1.0;
    return usdAmount * rate;
  }

  /// Converts an amount from given currency back to USD.
  static double convertToUsd(
    double amount,
    String sourceCurrencyCode, [
    Map<String, double>? rates,
  ]) {
    if (sourceCurrencyCode == baseCurrency) return amount;
    final rate =
        rates?[sourceCurrencyCode] ??
        supportedCurrencies[sourceCurrencyCode]?.defaultRateFromUsd ??
        1.0;
    if (rate == 0) return amount;
    return amount / rate;
  }

  /// Formats an amount using locale-aware formatting (e.g. ₹14,84,000.00 vs $14,840.00).
  static String formatAmount(
    double amount, {
    required String currencyCode,
    bool isSourceUsd = true,
    int? decimalDigits,
    Map<String, double>? customRates,
  }) {
    final info =
        supportedCurrencies[currencyCode] ?? supportedCurrencies[baseCurrency]!;
    final double displayAmount = isSourceUsd
        ? convertFromUsd(amount, currencyCode, customRates)
        : amount;

    try {
      final formatter = NumberFormat.currency(
        locale: info.locale,
        symbol: info.symbol,
        decimalDigits: decimalDigits ?? 2,
      );
      return formatter.format(displayAmount);
    } catch (_) {
      // Fallback
      return '${info.symbol}${displayAmount.toStringAsFixed(decimalDigits ?? 2)}';
    }
  }

  /// Formats large amounts in a compact representation (e.g. $14.8K, ₹14.8L, €12M).
  static String formatCompactAmount(
    double amount, {
    required String currencyCode,
    bool isSourceUsd = true,
    Map<String, double>? customRates,
  }) {
    final info =
        supportedCurrencies[currencyCode] ?? supportedCurrencies[baseCurrency]!;
    final double displayAmount = isSourceUsd
        ? convertFromUsd(amount, currencyCode, customRates)
        : amount;

    try {
      final formatter = NumberFormat.compactCurrency(
        locale: info.locale,
        symbol: info.symbol,
      );
      return formatter.format(displayAmount);
    } catch (_) {
      return formatAmount(
        displayAmount,
        currencyCode: currencyCode,
        isSourceUsd: false,
        decimalDigits: 0,
      );
    }
  }

  /// Returns detailed conversion information between USD and target currency.
  static ConvertedAmountDetails getConversionDetails(
    double usdAmount,
    String targetCurrencyCode, [
    Map<String, double>? customRates,
  ]) {
    final rate =
        customRates?[targetCurrencyCode] ??
        supportedCurrencies[targetCurrencyCode]?.defaultRateFromUsd ??
        1.0;
    final converted = convertFromUsd(
      usdAmount,
      targetCurrencyCode,
      customRates,
    );

    return ConvertedAmountDetails(
      originalAmount: usdAmount,
      originalCurrency: baseCurrency,
      convertedAmount: converted,
      targetCurrency: targetCurrencyCode,
      rate: rate,
      timestamp: DateTime.now(),
    );
  }
}
