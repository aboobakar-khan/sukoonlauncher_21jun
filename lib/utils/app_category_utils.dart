// App Category Utils — Package-name heuristic categorization engine
//
// Maps installed apps to curated categories using keyword matching
// on package names. Designed for speed — pure Dart, no I/O.

class AppCategory {
  final String name;
  final List<String> _keywords;

  const AppCategory._(this.name, this._keywords);

  /// Check if a package name matches this category
  bool matches(String packageName) {
    final pkg = packageName.toLowerCase();
    return _keywords.any((kw) => pkg.contains(kw));
  }
}

/// All built-in categories with their package-name keywords.
/// Order matters — first match wins. More specific categories
/// should appear before generic ones.
class AppCategories {
  AppCategories._();

  static const islamic = AppCategory._('Islamic', [
    'quran', 'muslim', 'islamic', 'prayer', 'adhan', 'azan',
    'mecca', 'hadith', 'dua', 'hijri', 'salah', 'sukoon',
    'sunnah', 'ramadan', 'tafsir', 'dhikr', 'masjid', 'halal',
    'athan', 'mosque', 'islam', 'kaaba', 'zakat', 'hajj',
    'umrah', 'muezzin', 'qibla', 'surah', 'ayah', 'fajr',
    'deen', 'iman', 'taqwa',
  ]);

  static const social = AppCategory._('Social', [
    'whatsapp', 'instagram', 'telegram', 'snapchat', 'twitter',
    'facebook', 'messenger', 'discord', 'signal', 'threads',
    'reddit', 'linkedin', 'wechat', 'viber', 'line.me',
    'com.line.', 'pinterest', 'tumblr', 'mastodon', 'bluesky',
    'com.x.', 'tweetdeck', 'slack', 'teams',
  ]);

  static const media = AppCategory._('Media', [
    'spotify', 'youtube', 'netflix', 'primevideo', 'vlc',
    'music', 'video', 'player', 'camera', 'gallery', 'photos',
    'tiktok', 'podcast', 'audible', 'kindle', 'plex',
    'hotstar', 'jiocinema', 'sonyliv', 'hulu', 'disney',
    'twitch', 'soundcloud', 'shazam', 'wynk', 'gaana',
    'jiosaavn', 'hungama', 'snapseed', 'lightroom', 'vsco',
    'photo', 'editor', 'filmora', 'capcut', 'inshot',
  ]);

  static const ai = AppCategory._('AI', [
    'openai', 'chatgpt', 'gemini', 'copilot', 'claude',
    'perplexity', 'midjourney', 'bard', 'deepseek',
    'character.ai', 'replika', 'bing.chat', 'grok',
    'anthropic', 'mistral', 'llama', 'huggingface',
  ]);

  static const productivity = AppCategory._('Productivity', [
    'docs', 'sheets', 'slides', 'notion', 'todoist', 'trello',
    'calendar', 'drive', 'office', 'notes', 'evernote',
    'obsidian', 'onenote', 'asana', 'clickup', 'monday',
    'airtable', 'coda', 'dropbox', 'onedrive', 'icloud',
    'scanner', 'camscanner', 'adobe.scan', 'pdf', 'reader',
    'document', 'translate', 'grammarly', 'canva',
  ]);

  static const finance = AppCategory._('Finance', [
    'bank', 'pay', 'wallet', 'money', 'upi', 'paytm',
    'gpay', 'phonepe', 'finance', 'trading', 'stock',
    'crypto', 'zerodha', 'groww', 'cred', 'slice',
    'mobikwik', 'freecharge', 'kotak', 'hdfc', 'icici',
    'sbi', 'axis', 'bajaj', 'razorpay', 'bhim',
    'navi', 'upstox', 'paisa', 'kite', 'coin',
  ]);

  static const shopping = AppCategory._('Shopping', [
    'amazon', 'flipkart', 'myntra', 'shop', 'store',
    'meesho', 'swiggy', 'zomato', 'blinkit', 'zepto',
    'ajio', 'nykaa', 'tatacliq', 'dunzo', 'bigbasket',
    'grofers', 'jiomart', 'croma', 'ebay', 'alibaba',
    'olx', 'quikr', 'cart', 'delivery', 'food',
    'uber.eats', 'doordash', 'instacart',
  ]);

  static const health = AppCategory._('Health', [
    'health', 'fit', 'workout', 'meditation', 'calm',
    'sleep', 'step', 'running', 'yoga', 'headspace',
    'strava', 'myfitnesspal', 'noom', 'flo', 'period',
    'doctor', 'pharma', 'medical', 'practo', 'netmeds',
    'oneplus.health', 'samsung.health', 'google.fit',
    'breathe', 'mindful', 'wellness',
  ]);

  static const gaming = AppCategory._('Gaming', [
    'game', 'play.games', 'chess', 'puzzle', 'candy',
    'clash', 'pubg', 'cod', 'roblox', 'minecraft',
    'fortnite', 'genshin', 'ludo', 'wordle', 'sudoku',
    'among.us', 'garena', 'freefire', 'bgmi',
    'mobilelegends', 'brawl', 'supercell', 'gameloft',
    'ea.', 'zynga', 'king.com', 'rovio',
  ]);

  static const tools = AppCategory._('Tools', [
    'calculator', 'clock', 'weather', 'file', 'manager',
    'browser', 'chrome', 'firefox', 'vpn', 'keyboard',
    'launcher', 'compass', 'flashlight', 'recorder',
    'cleaner', 'booster', 'antivirus', 'backup',
    'contacts', 'dialer', 'phone', 'messages', 'sms',
    'email', 'mail', 'maps', 'navigation', 'gboard',
    'swiftkey', 'opera', 'brave', 'edge', 'samsung.browser',
    'settings', 'system',
  ]);

  /// Ordered list of all default categories.
  /// Order determines priority — first match wins.
  static const List<AppCategory> defaults = [
    islamic,
    social,
    media,
    ai,
    productivity,
    finance,
    shopping,
    health,
    gaming,
    tools,
  ];

  /// All default category names
  static List<String> get defaultNames =>
      defaults.map((c) => c.name).toList();

  /// Categorize a single app. Returns the category name or null if uncategorized.
  static String? categorize(String packageName) {
    for (final cat in defaults) {
      if (cat.matches(packageName)) return cat.name;
    }
    return null;
  }

  /// Categorize all apps into a map of { categoryName: [packageNames] }.
  /// Only includes categories that have at least one matching app.
  static Map<String, List<String>> categorizeAll(List<String> packageNames) {
    final result = <String, List<String>>{};
    for (final pkg in packageNames) {
      final cat = categorize(pkg);
      if (cat != null) {
        result.putIfAbsent(cat, () => []).add(pkg);
      }
    }
    return result;
  }
}
