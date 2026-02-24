class CurrencyHelper {
  static const Map<String, CurrencyInfo> currencies = {
    'USD': CurrencyInfo('USD', '\$', 'US Dollar', 'en_US'),
    'EUR': CurrencyInfo('EUR', '€', 'Euro', 'de_DE'),
    'GBP': CurrencyInfo('GBP', '£', 'British Pound', 'en_GB'),
    'CAD': CurrencyInfo('CAD', 'CA\$', 'Canadian Dollar', 'en_CA'),
    'AUD': CurrencyInfo('AUD', 'A\$', 'Australian Dollar', 'en_AU'),
  };

  static String defaultCurrency = 'USD';

  static const CurrencyInfo _defaultInfo = CurrencyInfo('USD', '\$', 'US Dollar', 'en_US');

  static String format(double amount, {String? currency}) {
    final curr = currency ?? defaultCurrency;
    final info = currencies[curr] ?? _defaultInfo;
    
    if (amount == 0) {
      return 'Free';
    }
    
    return '${info.symbol}${amount.toStringAsFixed(2)}';
  }

  static String formatWithCode(double amount, {String? currency}) {
    final curr = currency ?? defaultCurrency;
    final info = currencies[curr] ?? _defaultInfo;
    
    if (amount == 0) {
      return 'Free';
    }
    
    return '${info.symbol}${amount.toStringAsFixed(2)} $curr';
  }

  static CurrencyInfo getInfo(String code) {
    return currencies[code] ?? _defaultInfo;
  }

  static List<String> getSupportedCodes() {
    return currencies.keys.toList();
  }
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String locale;

  const CurrencyInfo(this.code, this.symbol, this.name, this.locale);
}