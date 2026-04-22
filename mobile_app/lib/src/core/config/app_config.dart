class AppConfig {
  static String _baseUrl = 'http://10.0.2.2';

  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) {
    var formatted = value.trim();
    if (formatted.isEmpty) return;
    formatted = formatted.replaceAll('http;//', 'http://');
    formatted = formatted.replaceAll('https;//', 'https://');
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }

    final uri = Uri.tryParse(formatted);
    if (uri == null || uri.host.isEmpty) return;

    // Guardamos solo scheme + host para evitar puertos duplicados.
    _baseUrl = '${uri.scheme}://${uri.host}';
  }

  static String _serviceUrl(int port) {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return 'http://10.0.2.2:$port';
    }
    return '${uri.scheme}://${uri.host}:$port';
  }

  static String get authUrl => _serviceUrl(8030);
  static String get orchestratorUrl => _serviceUrl(8010);
  static String get simupayUrl => _serviceUrl(8020);
  static String get simupayWebUrl => _serviceUrl(5174);
  static String get vendingUrl => _serviceUrl(8040);
  static String get iotUrl => _serviceUrl(8050);
}
