import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';

enum CurrencyMode { auto, manual }

class RegionInfo {
  final String countryCode; // e.g. 'IN', 'US', 'GB', 'DE', 'CA', 'AU', 'JP'
  final String name; // e.g. 'India', 'United States'
  final String currencyCode; // e.g. 'INR', 'USD'
  final String flagEmoji; // e.g. '🇮🇳'

  const RegionInfo({
    required this.countryCode,
    required this.name,
    required this.currencyCode,
    required this.flagEmoji,
  });
}

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

  static const List<RegionInfo> supportedRegions = [
    RegionInfo(
      countryCode: 'IN',
      name: 'India',
      currencyCode: 'INR',
      flagEmoji: '🇮🇳',
    ),
    RegionInfo(
      countryCode: 'US',
      name: 'United States',
      currencyCode: 'USD',
      flagEmoji: '🇺🇸',
    ),
    RegionInfo(
      countryCode: 'GB',
      name: 'United Kingdom',
      currencyCode: 'GBP',
      flagEmoji: '🇬🇧',
    ),
    RegionInfo(
      countryCode: 'EU',
      name: 'European Union',
      currencyCode: 'EUR',
      flagEmoji: '🇪🇺',
    ),
    RegionInfo(
      countryCode: 'CA',
      name: 'Canada',
      currencyCode: 'CAD',
      flagEmoji: '🇨🇦',
    ),
    RegionInfo(
      countryCode: 'AU',
      name: 'Australia',
      currencyCode: 'AUD',
      flagEmoji: '🇦🇺',
    ),
    RegionInfo(
      countryCode: 'JP',
      name: 'Japan',
      currencyCode: 'JPY',
      flagEmoji: '🇯🇵',
    ),
  ];

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
    'CAD': CurrencyInfo(
      code: 'CAD',
      name: 'Canadian Dollar',
      symbol: 'CA\$',
      locale: 'en_CA',
      defaultRateFromUsd: 1.38,
      flagEmoji: '🇨🇦',
    ),
    'AUD': CurrencyInfo(
      code: 'AUD',
      name: 'Australian Dollar',
      symbol: 'A\$',
      locale: 'en_AU',
      defaultRateFromUsd: 1.54,
      flagEmoji: '🇦🇺',
    ),
    'JPY': CurrencyInfo(
      code: 'JPY',
      name: 'Japanese Yen',
      symbol: '¥',
      locale: 'ja_JP',
      defaultRateFromUsd: 152.0,
      flagEmoji: '🇯🇵',
    ),
  };

  static const Map<String, String> _countryToCurrency = {
    'IN': 'INR',
    'US': 'USD',
    'GB': 'GBP',
    'UK': 'GBP',
    'CA': 'CAD',
    'AU': 'AUD',
    'JP': 'JPY',
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

  /// Fetches cached exchange rates from the Django backend (/api/exchange-rates/).
  static Future<Map<String, double>?> fetchRatesFromBackend() async {
    try {
      final uri = Uri.parse(ApiConfig.exchangeRatesUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>?;
        if (rawRates != null) {
          return rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }
      }
    } catch (_) {
      // Graceful fallback to cached or default rates
    }
    return null;
  }

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
