/// Centralized environment and third-party API configuration for CodecM,
/// loaded from `--dart-define` at build time with buildathon defaults.
class AppEnv {
  AppEnv._();

  static const String podcastIndexApiKey = String.fromEnvironment(
    'PODCAST_INDEX_API_KEY',
    defaultValue: 'GJNMHDZ35CNYGBFUWK3L',
  );

  static const String podcastIndexApiSecret = String.fromEnvironment(
    'PODCAST_INDEX_API_SECRET',
    defaultValue: 'KGmdWuuQ8fPANPt#yVAxNJzCScaw\$Ae8k6wrGSx#',
  );

  static const String jamendoClientId = String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: '79650c43',
  );

  static const String audiusApiKey = String.fromEnvironment(
    'AUDIUS_API_KEY',
    defaultValue: '',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '342021022528-s4kg615kul5cumiho68ftbaelhe4nvs6.apps.googleusercontent.com',
  );

  static const String meilisearchUrl = String.fromEnvironment(
    'MEILISEARCH_URL',
    defaultValue: 'https://getillustrations.com/meili',
  );

  static const String meilisearchMasterKey = String.fromEnvironment(
    'MEILISEARCH_MASTER_KEY',
    defaultValue: 'gi_free_f94a299439f2a8acdc633abbbae60a22050aaf5332fd5e0af59057dca3be6b78',
  );
}
