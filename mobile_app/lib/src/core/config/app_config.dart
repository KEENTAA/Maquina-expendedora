class AppConfig {
  static String _baseUrl = '';

  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) {
    var formatted = value.trim();
    if (formatted.isEmpty) return;
    formatted = formatted.replaceAll('http;//', 'http://');
    formatted = formatted.replaceAll('https;//', 'https://');
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      if (formatted.contains('ngrok') || formatted.contains('cloudflare')) {
        formatted = 'https://$formatted';
      } else {
        formatted = 'http://$formatted';
      }
    }

    final uri = Uri.tryParse(formatted);
    if (uri == null || uri.host.isEmpty) return;

    var scheme = uri.scheme;
    if ((uri.host.contains('ngrok') || uri.host.contains('cloudflare')) && scheme == 'http') {
      scheme = 'https';
    }

    // Guardamos solo scheme + host para evitar puertos duplicados.
    _baseUrl = '$scheme://${uri.host}';
  }

  static String serviceUrl(int port) {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return 'http://10.0.2.2:$port';
    }

    // Si es un túnel (ngrok, Cloudflare) o dominio público HTTPS sin soporte directo de puertos
    if (uri.scheme == 'https' ||
        uri.host.contains('ngrok') ||
        uri.host.contains('trycloudflare.com') ||
        uri.host.contains('cloudflare')) {
      return '${uri.scheme}://${uri.host}/p/$port';
    }

    // Comportamiento local tradicional por IP (172.18.x.x:PORT o 10.0.2.2:PORT)
    return '${uri.scheme}://${uri.host}:$port';
  }

  static String get authUrl => serviceUrl(8030);
  static String get orchestratorUrl => serviceUrl(8010);
  static String get simupayUrl => serviceUrl(8020);
  static String get simupayWebUrl => serviceUrl(5174);
  static String get vendingUrl => serviceUrl(8040);
  static String get iotUrl => serviceUrl(8050);
  static String get notificationUrl => serviceUrl(8070);
  static String get auditUrl => serviceUrl(8080);
}
