// lib/stub/ads_stub.dart
// Web stub — google_mobile_ads (not supported on web)

class MobileAds {
  static MobileAds get instance => _instance;
  static final MobileAds _instance = MobileAds._();
  MobileAds._();
  Future<void> initialize() async {}
}

class AdRequest {
  final List<String>? keywords;
  final String? contentUrl;
  const AdRequest({this.keywords, this.contentUrl});
}

class AdError {
  final int code;
  final String domain;
  final String message;
  const AdError({required this.code, required this.domain, required this.message});
}

class LoadAdError extends AdError {
  const LoadAdError({required super.code, required super.domain, required super.message});
}

// ── FullScreenContentCallback ────────────────────────────
class FullScreenContentCallback<T> {
  final void Function(T ad)? onAdShowedFullScreenContent;
  final void Function(T ad)? onAdDismissedFullScreenContent;
  final void Function(T ad, AdError error)? onAdFailedToShowFullScreenContent;
  final void Function(T ad)? onAdClicked;
  final void Function(T ad)? onAdImpression;
  const FullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
    this.onAdClicked,
    this.onAdImpression,
  });
}

// ── InterstitialAd ───────────────────────────────────────
class InterstitialAd {
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;

  static void load({
    required String adUnitId,
    required AdRequest request,
    required InterstitialAdLoadCallback adLoadCallback,
  }) {}

  Future<void> show() async {}
  void dispose() {}
}

class InterstitialAdLoadCallback {
  final void Function(InterstitialAd ad)? onAdLoaded;
  final void Function(LoadAdError error)? onAdFailedToLoad;
  const InterstitialAdLoadCallback({this.onAdLoaded, this.onAdFailedToLoad});
}
