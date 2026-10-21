enum AppEnvironment { development, staging, production }

class EnvironmentError implements Exception {
  final String message;
  const EnvironmentError(this.message);
  @override
  String toString() => message;
}

class Env {
  Env._();

  static const releaseBuild = bool.fromEnvironment('dart.vm.product');

  static const _name = String.fromEnvironment('APP_ENV');
  static const _url = String.fromEnvironment('API_BASE_URL');

  static const stagingUrl = 'https://staging.schedio.live/api/v1/';
  static const productionUrl = 'https://schedio.live/api/v1/';

  static AppEnvironment get current => switch (_name) {
    'development' || 'dev' => AppEnvironment.development,
    'staging' => AppEnvironment.staging,
    'production' || 'prod' => AppEnvironment.production,
    _ => _url.isNotEmpty && !releaseBuild && isPrivateHost(Uri.tryParse(_url)?.host ?? '')
        ? AppEnvironment.development
        : AppEnvironment.production,
  };

  static String get apiBaseUrl {
    final url = _url.isNotEmpty
        ? _url
        : switch (current) {
            AppEnvironment.staging => stagingUrl,
            AppEnvironment.production => productionUrl,
            AppEnvironment.development => '',
          };
    return url.endsWith('/') ? url : '$url/';
  }

  static bool isPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.localhost') || h == '::1') {
      return true;
    }
    final parts = h.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 127 ||
        a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 169 && b == 254) ||
        a == 0;
  }

  static Uri validate(String url, {AppEnvironment? environment, bool? release}) {
    final env = environment ?? current;
    final isRelease = release ?? releaseBuild;
    if (url.isEmpty || url == '/') {
      throw const EnvironmentError(
        'No server address configured. Build with --dart-define=API_BASE_URL=... for development.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw EnvironmentError('The server address "$url" is not a valid URL.');
    }
    if (!uri.path.endsWith('/api/v1/')) {
      throw const EnvironmentError('The server address must end with /api/v1/.');
    }
    final strict = isRelease || env != AppEnvironment.development;
    if (strict) {
      if (uri.scheme != 'https') {
        throw const EnvironmentError('The server address must use HTTPS.');
      }
      if (isPrivateHost(uri.host)) {
        throw const EnvironmentError(
          'Staging and production builds cannot use local or private network addresses.',
        );
      }
    } else if (!['http', 'https'].contains(uri.scheme)) {
      throw const EnvironmentError('The server address must use HTTP or HTTPS.');
    }
    return uri;
  }

  static String get label => switch (current) {
    AppEnvironment.development => 'Development',
    AppEnvironment.staging => 'Staging',
    AppEnvironment.production => 'Production',
  };
}
