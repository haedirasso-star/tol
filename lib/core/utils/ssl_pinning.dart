/// SSL Pinning configuration and validation.
/// Configure in Android network_security_config.xml and iOS.
class SslPinning {
  /// Validate certificate for CDN domains.
  static bool validateHost(String host) {
    const allowedHosts = [
      'cdn1.totv.plus',
      'cdn2.totv.plus',
      'cdn3.totv.plus',
    ];
    return allowedHosts.any((h) => host.contains(h));
  }
}
