import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/hadith_dua_models.dart';

/// Service for fetching Hadith and Dua — powered by hadithapi.com
class HadithDuaService {
  // ── hadithapi.com configuration ──
  static const String _baseUrl = 'https://hadithapi.com/api';
  // API key stored as constant to avoid dotenv $-sign interpolation issues
  static const String _apiKey = r'$2y$10$bBYkOiuMdXrRm3td9KtzWuBt3XM6WX0FOUuvXxSxJ7hXyKwoHmai';

  // ── In-memory caches ──
  final Map<String, List<Hadith>> _hadithCache = {};
  final Map<String, List<HadithChapter>> _chaptersCache = {};
  final Map<String, Map<String, String>> _sectionsCache = {};

  // ═══════════════════════════════════════════════════════════════════
  //  HTTP helper – single attempt + one retry
  // ═══════════════════════════════════════════════════════════════════

  Future<http.Response?> _get(String url) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) return response;
        debugPrint('HadithDuaService: HTTP ${response.statusCode} on attempt $attempt for $url');
      } catch (e) {
        debugPrint('HadithDuaService: attempt $attempt failed for $url → $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return null;
  }

  String _url(String path, [Map<String, String>? queryParams]) {
    // Build query string manually — do NOT percent-encode the apiKey because
    // bcrypt keys contain '$' which Uri.encodeComponent would turn into %24.
    final buffer = StringBuffer('$_baseUrl$path?apiKey=$_apiKey');
    queryParams?.forEach((k, v) {
      buffer.write('&$k=${Uri.encodeQueryComponent(v)}');
    });
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Chapters (Kitabs) for a book
  // ═══════════════════════════════════════════════════════════════════

  /// Fetch chapters/kitabs for a given collection.
  Future<List<HadithChapter>> getChapters(HadithCollection collection) async {
    if (_chaptersCache.containsKey(collection.bookSlug)) {
      return _chaptersCache[collection.bookSlug]!;
    }

    final url = _url('/${collection.bookSlug}/chapters');
    final response = await _get(url);
    if (response == null) return [];

    try {
      final body = json.decode(response.body);
      final chaptersRaw = body['chapters'] as List<dynamic>? ?? [];
      final chapters = chaptersRaw
          .map((c) => HadithChapter.fromJson(c as Map<String, dynamic>))
          .toList();
      _chaptersCache[collection.bookSlug] = chapters;

      // Also populate legacy _sectionsCache for backward compat
      final sectionMap = <String, String>{};
      for (final ch in chapters) {
        sectionMap[ch.chapterNumber.toString()] = ch.chapterEnglish;
      }
      _sectionsCache[collection.id] = sectionMap;

      return chapters;
    } catch (e) {
      debugPrint('HadithDuaService: Error parsing chapters: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Hadiths – paginated from hadithapi.com
  // ═══════════════════════════════════════════════════════════════════

  /// Fetch hadiths for a collection, optionally filtered by chapter.
  /// hadithapi.com returns paginated results; we fetch up to [maxPages] pages.
  Future<List<Hadith>> fetchHadiths(
    HadithCollection collection, {
    int? chapterId,
    int maxPages = 1,
    String language = 'eng',
  }) async {
    // Cache key includes language so switching language fetches fresh data
    final cacheKey = '${collection.bookSlug}_${chapterId ?? 'all'}_$language';
    if (_hadithCache.containsKey(cacheKey)) {
      return _hadithCache[cacheKey]!;
    }

    final allHadiths = <Hadith>[];
    int page = 1;

    while (page <= maxPages) {
      final params = <String, String>{
        'book': collection.bookSlug,
        'page': page.toString(),
        'paginate': '50',   // fetch 50 per page (API max) for efficiency
        'language': language,
      };
      if (chapterId != null) params['chapter'] = chapterId.toString();

      final url = _url('/hadiths', params);
      final response = await _get(url);
      if (response == null) break;

      try {
        final body = json.decode(response.body);
        final data = body['hadiths']?['data'] as List<dynamic>? ?? [];
        if (data.isEmpty) break;

        for (final h in data) {
          try {
            var hadith = Hadith.fromJson(
              h as Map<String, dynamic>,
              collection: collection.name,
            );
            if (hadith.grade == HadithGrade.unknown &&
                collection.defaultGrade != HadithGrade.unknown) {
              hadith = hadith.copyWith(grade: collection.defaultGrade);
            }
            allHadiths.add(hadith);
          } catch (e) {
            continue;
          }
        }

        final lastPage = body['hadiths']?['last_page'] as int? ?? page;
        if (page >= lastPage) break;
        page++;
      } catch (e) {
        debugPrint('HadithDuaService: Error parsing hadiths page $page: $e');
        break;
      }
    }

    if (allHadiths.isNotEmpty) {
      _hadithCache[cacheKey] = allHadiths;
    }
    return allHadiths;
  }

  /// Download ALL hadiths for offline storage (fetches every page).
  Future<List<Hadith>> downloadHadithsForOffline(
    HadithCollection collection, {
    Function(int, int)? onProgress,
  }) async {
    debugPrint('HadithDuaService: Starting FULL download for ${collection.name}...');

    final allHadiths = <Hadith>[];
    int page = 1;
    int totalPages = 1;

    while (page <= totalPages) {
      final params = <String, String>{
        'book': collection.bookSlug,
        'page': page.toString(),
        'paginate': '50',
      };
      final url = _url('/hadiths', params);
      final response = await _get(url);
      if (response == null) break;

      try {
        final body = json.decode(response.body);
        totalPages = body['hadiths']?['last_page'] as int? ?? 1;
        final data = body['hadiths']?['data'] as List<dynamic>? ?? [];
        if (data.isEmpty) break;

        for (final h in data) {
          try {
            var hadith = Hadith.fromJson(
              h as Map<String, dynamic>,
              collection: collection.name,
            );
            if (hadith.grade == HadithGrade.unknown &&
                collection.defaultGrade != HadithGrade.unknown) {
              hadith = hadith.copyWith(grade: collection.defaultGrade);
            }
            allHadiths.add(hadith);
          } catch (e) {
            continue;
          }
        }

        onProgress?.call(page, totalPages);
        page++;
      } catch (e) {
        debugPrint('HadithDuaService: Error on page $page: $e');
        break;
      }
    }

    if (allHadiths.isNotEmpty) {
      _hadithCache['${collection.bookSlug}_all'] = allHadiths;
    }

    debugPrint('HadithDuaService: ✓ Downloaded ${allHadiths.length} hadiths from ${collection.name}');
    return allHadiths;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Legacy compatibility helpers
  // ═══════════════════════════════════════════════════════════════════

  /// Get cached sections for a collection (book number → chapter name).
  Map<String, String>? getSections(String collectionId) {
    return _sectionsCache[collectionId];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Random hadith
  // ═══════════════════════════════════════════════════════════════════

  Future<Hadith?> getRandomHadith({String? collectionId}) async {
    final collection = collectionId != null
        ? HadithCollection.fromId(collectionId)
        : HadithCollection.collections[Random().nextInt(HadithCollection.collections.length)];

    final cacheKey = '${collection.bookSlug}_all';
    if (_hadithCache.containsKey(cacheKey) && _hadithCache[cacheKey]!.isNotEmpty) {
      final hadiths = _hadithCache[cacheKey]!;
      return hadiths[Random().nextInt(hadiths.length)];
    }

    final random = Random();
    final randomPage = random.nextInt(10) + 1;
    final params = <String, String>{'book': collection.bookSlug, 'page': randomPage.toString()};
    final url = _url('/hadiths', params);
    final response = await _get(url);
    if (response == null) return null;

    try {
      final body = json.decode(response.body);
      final data = body['hadiths']?['data'] as List<dynamic>? ?? [];
      if (data.isEmpty) return null;
      var hadith = Hadith.fromJson(data[random.nextInt(data.length)] as Map<String, dynamic>, collection: collection.name);
      if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
        hadith = hadith.copyWith(grade: collection.defaultGrade);
      }
      return hadith;
    } catch (e) {
      debugPrint('HadithDuaService: Error getting random hadith: $e');
      return null;
    }
  }

  Future<List<Hadith>> getMultipleRandomHadiths({
    String? collectionId, int count = 5, List<int>? excludeNumbers,
  }) async {
    final collection = collectionId != null
        ? HadithCollection.fromId(collectionId)
        : HadithCollection.collections[Random().nextInt(HadithCollection.collections.length)];
    final results = <Hadith>[];
    final random = Random();
    int attempts = 0;
    while (results.length < count && attempts < 5) {
      attempts++;
      final params = <String, String>{'book': collection.bookSlug, 'page': (random.nextInt(10) + 1).toString()};
      final url = _url('/hadiths', params);
      final response = await _get(url);
      if (response == null) continue;
      try {
        final body = json.decode(response.body);
        final data = body['hadiths']?['data'] as List<dynamic>? ?? [];
        for (final h in data) {
          if (results.length >= count) break;
          try {
            var hadith = Hadith.fromJson(h as Map<String, dynamic>, collection: collection.name);
            if (excludeNumbers?.contains(hadith.hadithNumber) ?? false) continue;
            if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
              hadith = hadith.copyWith(grade: collection.defaultGrade);
            }
            results.add(hadith);
          } catch (e) { continue; }
        }
      } catch (e) { continue; }
    }
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Category & Search
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Hadith>> getHadithsByCategory({
    required HadithCategory category, String? collectionId, int limit = 20,
  }) async {
    final collections = collectionId != null
        ? [HadithCollection.fromId(collectionId)]
        : HadithCollection.collections;
    final results = <Hadith>[];
    for (final collection in collections) {
      final hadiths = await fetchHadiths(collection);
      results.addAll(hadiths.where((h) => h.categories.contains(category)));
      if (results.length >= limit) break;
    }
    return results.take(limit).toList();
  }

  /// Search hadiths — uses hadithapi.com server-side search.
  Future<List<Hadith>> searchHadiths(
    String query, {
    String? collectionId, HadithGrade? gradeFilter, HadithCategory? categoryFilter,
  }) async {
    if (query.trim().isEmpty) return [];
    final params = <String, String>{'hadithEnglish': query};
    if (collectionId != null) {
      params['book'] = HadithCollection.fromId(collectionId).bookSlug;
    }
    final url = _url('/hadiths', params);
    final response = await _get(url);
    if (response == null) return [];
    try {
      final body = json.decode(response.body);
      final data = body['hadiths']?['data'] as List<dynamic>? ?? [];
      var results = <Hadith>[];
      for (final h in data) {
        try {
          results.add(Hadith.fromJson(h as Map<String, dynamic>, collection: collectionId ?? ''));
        } catch (e) { continue; }
      }
      if (gradeFilter != null) results = results.where((h) => h.grade == gradeFilter).toList();
      if (categoryFilter != null) results = results.where((h) => h.categories.contains(categoryFilter)).toList();
      return results.take(50).toList();
    } catch (e) {
      debugPrint('HadithDuaService: Search error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Dua methods — fully preserved, local data only
  // ═══════════════════════════════════════════════════════════════════

  /// Get curated duas (embedded since API might not be reliable)
  List<Dua> getCuratedDuas() {
    return _curatedDuas;
  }

  /// Get a random dua
  Dua getRandomDua() {
    return _curatedDuas[Random().nextInt(_curatedDuas.length)];
  }

  /// Search duas
  List<Dua> searchDuas(String query) {
    final queryLower = query.toLowerCase();
    return _curatedDuas.where((d) =>
      d.title.toLowerCase().contains(queryLower) ||
      d.translation.toLowerCase().contains(queryLower) ||
      d.transliteration.toLowerCase().contains(queryLower) ||
      (d.category?.toLowerCase().contains(queryLower) ?? false)
    ).toList();
  }

  static final List<Dua> _curatedDuas = [
    // Morning & Evening
    Dua(
      id: 'morning_1',
      title: 'Morning Remembrance',
      arabicText: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ',
      transliteration: "Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la shareeka lah",
      translation: "We have reached the morning and at this very time the whole kingdom belongs to Allah. All praise is due to Allah. None has the right to be worshipped except Allah alone, without any partner.",
      category: 'Morning & Evening',
      source: 'Muslim',
    ),
    Dua(
      id: 'evening_1',
      title: 'Evening Remembrance',
      arabicText: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ',
      transliteration: "Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la shareeka lah",
      translation: "We have reached the evening and at this very time the whole kingdom belongs to Allah. All praise is due to Allah. None has the right to be worshipped except Allah alone, without any partner.",
      category: 'Morning & Evening',
      source: 'Muslim',
    ),
    Dua(
      id: 'morning_protection',
      title: 'Seeking Protection (Morning)',
      arabicText: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
      transliteration: "Allahumma bika asbahna, wa bika amsayna, wa bika nahya, wa bika namootu, wa ilaykan-nushoor",
      translation: "O Allah, by You we enter the morning, by You we enter the evening, by You we live, by You we die, and to You is the resurrection.",
      category: 'Morning & Evening',
      source: 'Tirmidhi',
    ),
    
    // Protection
    Dua(
      id: 'protection_1',
      title: 'Seeking Refuge',
      arabicText: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
      transliteration: "A'udhu bikalimatillahit-tammati min sharri ma khalaq",
      translation: "I seek refuge in the perfect words of Allah from the evil of what He has created.",
      category: 'Protection',
      source: 'Muslim',
    ),
    Dua(
      id: 'protection_2',
      title: 'Protection from Evil',
      arabicText: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      transliteration: "Bismillahil-ladhi la yadurru ma'as-mihi shay'un fil-ardi wa la fis-sama'i, wa Huwas-Sami'ul-'Alim",
      translation: "In the name of Allah, with whose name nothing in the earth or the sky can cause harm, and He is the All-Hearing, the All-Knowing.",
      category: 'Protection',
      source: 'Abu Dawud, Tirmidhi',
    ),
    
    // Before Sleep
    Dua(
      id: 'sleep_1',
      title: 'Before Sleeping',
      arabicText: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
      transliteration: "Bismika Allahumma amootu wa ahya",
      translation: "In Your name, O Allah, I die and I live.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    Dua(
      id: 'sleep_2',
      title: 'Sleeping Dua',
      arabicText: 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا',
      transliteration: "Allahumma bismika amootu wa ahya",
      translation: "O Allah, in Your name I die and I live.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    Dua(
      id: 'wakeup_1',
      title: 'Upon Waking Up',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      transliteration: "Alhamdu lillahil-ladhi ahyana ba'da ma amatana, wa ilayhin-nushoor",
      translation: "All praise is due to Allah, who gave us life after causing us to die, and unto Him is the resurrection.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    
    // Eating & Drinking
    Dua(
      id: 'eating_1',
      title: 'Before Eating',
      arabicText: 'بِسْمِ اللَّهِ',
      transliteration: "Bismillah",
      translation: "In the name of Allah.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'eating_2',
      title: 'After Eating',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلاَ قُوَّةٍ',
      transliteration: "Alhamdu lillahil-ladhi at'amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah",
      translation: "All praise is due to Allah who fed me this and provided it for me without any might or strength on my part.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'eating_3',
      title: 'When Forgetting Bismillah',
      arabicText: 'بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ',
      transliteration: "Bismillahi awwalahu wa akhirah",
      translation: "In the name of Allah at the beginning and at the end of it.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'drinking_1',
      title: 'After Drinking Water',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي سَقَانَا عَذْبًا فُرَاتًا بِرَحْمَتِهِ وَلَمْ يَجْعَلْهُ مِلْحًا أُجَاجًا بِذُنُوبِنَا',
      transliteration: "Alhamdu lillahil-ladhi saqana 'adhban furatan bi rahmatih, wa lam yaj'alhu milhan ujajan bi dhunubina",
      translation: "All praise is due to Allah who gave us sweet, fresh water by His mercy and did not make it salty and bitter due to our sins.",
      category: 'Food & Drink',
      source: 'Tabarani',
    ),
    
    // Travel
    Dua(
      id: 'travel_1',
      title: 'Starting a Journey',
      arabicText: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنْقَلِبُونَ',
      transliteration: "Subhanal-ladhi sakhkhara lana hadha wama kunna lahu muqrinin, wa inna ila Rabbina lamunqaliboon",
      translation: "Glory be to Him who has subjected this for us, and we would not have been able to subdue it. And indeed, to our Lord we will return.",
      category: 'Travel',
      source: 'Muslim',
    ),
    Dua(
      id: 'travel_2',
      title: 'Returning from Travel',
      arabicText: 'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ',
      transliteration: "Ayibuna, ta'ibuna, 'abiduna, li Rabbina hamidun",
      translation: "We return, repenting, worshipping, and praising our Lord.",
      category: 'Travel',
      source: 'Muslim',
    ),
    Dua(
      id: 'travel_3',
      title: 'Entering a Town or City',
      arabicText: 'اللَّهُمَّ رَبَّ السَّمَاوَاتِ السَّبْعِ وَمَا أَظْلَلْنَ، وَرَبَّ الْأَرَضِينَ السَّبْعِ وَمَا أَقْلَلْنَ، أَسْأَلُكَ خَيْرَ هَٰذِهِ الْقَرْيَةِ وَخَيْرَ أَهْلِهَا',
      transliteration: "Allahumma Rabbas-samawatis-sab'i wa ma azlalna, wa Rabbal-aradinas-sab'i wa ma aqlalna, as'aluka khayra hadhihil-qaryati wa khayra ahliha",
      translation: "O Allah, Lord of the seven heavens and all they shade, Lord of the seven earths and all they bear, I ask You for the good of this town and the good of its people.",
      category: 'Travel',
      source: 'Ibn Hibban',
    ),
    
    // Forgiveness
    Dua(
      id: 'forgiveness_1',
      title: 'Seeking Forgiveness (Sayyidul Istighfar)',
      arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      transliteration: "Allahumma anta Rabbi, la ilaha illa anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mastata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bini'matika 'alayya, wa abu'u bidhanbi, faghfir li, fa innahu la yaghfirudh-dhunuba illa anta",
      translation: "O Allah, You are my Lord, there is no god but You. You created me and I am Your servant, and I hold to Your covenant and promise as much as I can. I seek refuge in You from the evil I have done. I acknowledge Your blessings upon me, and I acknowledge my sins. So forgive me, for none forgives sins but You.",
      category: 'Forgiveness',
      source: 'Bukhari',
    ),
    Dua(
      id: 'forgiveness_2',
      title: 'Simple Istighfar',
      arabicText: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
      transliteration: "Astaghfirullaha wa atubu ilayh",
      translation: "I seek the forgiveness of Allah and repent to Him.",
      category: 'Forgiveness',
      source: 'Bukhari, Muslim',
    ),
    
    // Anxiety & Distress
    Dua(
      id: 'anxiety_1',
      title: 'For Anxiety and Sorrow',
      arabicText: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
      transliteration: "Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabatir-rijal",
      translation: "O Allah, I seek refuge in You from anxiety and grief, from weakness and laziness, from miserliness and cowardice, from being overwhelmed by debt and from being overpowered by men.",
      category: 'Distress',
      source: 'Bukhari',
    ),
    Dua(
      id: 'distress_1',
      title: 'In Times of Distress',
      arabicText: 'لَا إِلَٰهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ',
      transliteration: "La ilaha illallahul-'Azimul-Halim, la ilaha illallahu Rabbul-'Arshil-'Azim, la ilaha illallahu Rabbus-samawati wa Rabbul-ardi wa Rabbul-'Arshil-Karim",
      translation: "There is no god but Allah, the Mighty, the Forbearing. There is no god but Allah, Lord of the Magnificent Throne. There is no god but Allah, Lord of the heavens and Lord of the earth, and Lord of the Noble Throne.",
      category: 'Distress',
      source: 'Bukhari, Muslim',
    ),
    
    // Guidance
    Dua(
      id: 'guidance_1',
      title: 'For Guidance',
      arabicText: 'اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي',
      transliteration: "Allahumma'hdini wa saddidni",
      translation: "O Allah, guide me and keep me on the right path.",
      category: 'Guidance',
      source: 'Muslim',
    ),
    Dua(
      id: 'guidance_2',
      title: 'Istikhara (Seeking Guidance)',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ',
      transliteration: "Allahumma inni astakhiruka bi'ilmika, wa astaqdiruka biqudratika, wa as'aluka min fadlikal-'azim",
      translation: "O Allah, I seek Your guidance by virtue of Your knowledge, and I seek ability by virtue of Your power, and I ask You of Your great bounty.",
      category: 'Guidance',
      source: 'Bukhari',
    ),
    
    // Gratitude
    Dua(
      id: 'gratitude_1',
      title: 'Expressing Gratitude',
      arabicText: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
      transliteration: "Allahumma a'inni 'ala dhikrika wa shukrika wa husni 'ibadatik",
      translation: "O Allah, help me to remember You, to thank You, and to worship You well.",
      category: 'Gratitude',
      source: 'Abu Dawud, Nasai',
    ),
    Dua(
      id: 'gratitude_2',
      title: 'When Seeing Someone in Trial',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي مِمَّا ابْتَلَاكَ بِهِ، وَفَضَّلَنِي عَلَى كَثِيرٍ مِمَّنْ خَلَقَ تَفْضِيلًا',
      transliteration: "Alhamdu lillahil-ladhi 'afani mimmabtilaka bihi, wa faddalani 'ala kathirin mimman khalaqa tafdila",
      translation: "All praise is due to Allah who has saved me from what He has tested you with, and has favored me greatly over many of His creation.",
      category: 'Gratitude',
      source: 'Tirmidhi',
    ),
    Dua(
      id: 'gratitude_3',
      title: 'Upon Receiving Good News',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ',
      transliteration: "Alhamdu lillahil-ladhi bi ni'matihi tatimmus-salihat",
      translation: "All praise is due to Allah by whose blessing all good things are completed.",
      category: 'Gratitude',
      source: 'Ibn Majah',
    ),
    
    // Health
    Dua(
      id: 'health_1',
      title: 'For Good Health',
      arabicText: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي',
      transliteration: "Allahumma 'afini fi badani, Allahumma 'afini fi sam'i, Allahumma 'afini fi basari",
      translation: "O Allah, grant me health in my body. O Allah, grant me health in my hearing. O Allah, grant me health in my sight.",
      category: 'Health',
      source: 'Abu Dawud',
    ),
    Dua(
      id: 'health_2',
      title: 'For Healing',
      arabicText: 'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا',
      transliteration: "Allahumma Rabban-nas, adhibil-ba's, ishfi antash-Shafi, la shifa'a illa shifa'uka, shifa'an la yughadiru saqama",
      translation: "O Allah, Lord of mankind, remove the illness. Cure it, for You are the Healer. There is no cure except Your cure — a cure that leaves no illness behind.",
      category: 'Health',
      source: 'Bukhari, Muslim',
    ),
    Dua(
      id: 'health_3',
      title: 'Visiting the Sick',
      arabicText: 'لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ',
      transliteration: "La ba'sa, tahoorun in sha Allah",
      translation: "No worry, it is a purification, if Allah wills.",
      category: 'Health',
      source: 'Bukhari',
    ),
    
    // Knowledge
    Dua(
      id: 'knowledge_1',
      title: 'Seeking Beneficial Knowledge',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا',
      transliteration: "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan tayyiban, wa 'amalan mutaqabbalan",
      translation: "O Allah, I ask You for beneficial knowledge, goodly provision, and accepted deeds.",
      category: 'Knowledge',
      source: 'Ibn Majah',
    ),
    Dua(
      id: 'knowledge_2',
      title: 'Increase in Knowledge',
      arabicText: 'رَبِّ زِدْنِي عِلْمًا',
      transliteration: "Rabbi zidni 'ilma",
      translation: "My Lord, increase me in knowledge.",
      category: 'Knowledge',
      source: 'Quran 20:114',
    ),
    Dua(
      id: 'knowledge_3',
      title: 'Before Studying',
      arabicText: 'اللَّهُمَّ انْفَعْنِي بِمَا عَلَّمْتَنِي، وَعَلِّمْنِي مَا يَنْفَعُنِي، وَزِدْنِي عِلْمًا',
      transliteration: "Allahumma-nfa'ni bima 'allamtani, wa 'allimni ma yanfa'uni, wa zidni 'ilma",
      translation: "O Allah, benefit me with what You have taught me, teach me that which will benefit me, and increase me in knowledge.",
      category: 'Knowledge',
      source: 'Tirmidhi',
    ),
    
    // Ramadan - Fasting, Suhoor, Iftar, Laylatul Qadr
    Dua(
      id: 'ramadan_suhoor',
      title: 'Dua for Suhoor',
      arabicText: 'نَوَيْتُ صَوْمَ غَدٍ عَنْ أَدَاءِ فَرْضِ شَهْرِ رَمَضَانَ هَذِهِ السَّنَةِ لِلَّهِ تَعَالَى',
      transliteration: "Nawaitu sauma ghadin 'an adaa'i fardi shahri Ramadana hadhihis-sanati lillahi ta'ala",
      translation: "I intend to keep the fast for tomorrow in the month of Ramadan this year for Allah, the Most High.",
      category: 'Ramadan',
      source: 'Traditional',
    ),
    Dua(
      id: 'ramadan_iftar',
      title: 'Dua for Breaking Fast (Iftar)',
      arabicText: 'اللَّهُمَّ إِنِّي لَكَ صُمْتُ وَبِكَ آمَنْتُ وَعَلَيْكَ تَوَكَّلْتُ وَعَلَى رِزْقِكَ أَفْطَرْتُ',
      transliteration: "Allahumma inni laka sumtu wa bika amantu wa 'alayka tawakkaltu wa 'ala rizqika aftartu",
      translation: "O Allah, I fasted for You and I believe in You, and I put my trust in You, and I break my fast with Your sustenance.",
      category: 'Ramadan',
      source: 'Abu Dawud',
    ),
    Dua(
      id: 'ramadan_iftar_short',
      title: 'Short Iftar Dua',
      arabicText: 'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
      transliteration: "Dhahaba al-zama'u, wabtallatil-'uruqu, wa thabatal-ajru in sha Allah",
      translation: "Thirst has gone, the veins are moistened, and the reward is confirmed, if Allah wills.",
      category: 'Ramadan',
      source: 'Abu Dawud',
    ),
    Dua(
      id: 'ramadan_before_iftar',
      title: 'Before Breaking Fast',
      arabicText: 'اللَّهُمَّ لَكَ صُمْتُ وَعَلَى رِزْقِكَ أَفْطَرْتُ',
      transliteration: "Allahumma laka sumtu wa 'ala rizqika aftartu",
      translation: "O Allah, for You I have fasted and with Your provision I break my fast.",
      category: 'Ramadan',
      source: 'Abu Dawud',
    ),
    Dua(
      id: 'ramadan_laylatul_qadr_1',
      title: 'Laylatul Qadr - Best Dua',
      arabicText: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي',
      transliteration: "Allahumma innaka 'afuwwun tuhibbul-'afwa fa'fu 'anni",
      translation: "O Allah, You are Forgiving and love forgiveness, so forgive me.",
      category: 'Ramadan',
      source: 'Tirmidhi, Ibn Majah',
    ),
    Dua(
      id: 'ramadan_general_1',
      title: 'During Ramadan',
      arabicText: 'اللَّهُمَّ بَلِّغْنَا رَمَضَانَ',
      transliteration: "Allahumma ballighna Ramadan",
      translation: "O Allah, allow us to reach Ramadan.",
      category: 'Ramadan',
      source: 'Traditional',
    ),
    Dua(
      id: 'ramadan_acceptance',
      title: 'For Accepted Fasting',
      arabicText: 'اللَّهُمَّ تَقَبَّلْ مِنَّا صِيَامَنَا وَقِيَامَنَا',
      transliteration: "Allahumma taqabbal minna siyamana wa qiyamana",
      translation: "O Allah, accept from us our fasting and our standing in prayer.",
      category: 'Ramadan',
      source: 'Traditional',
    ),
    Dua(
      id: 'ramadan_taraweeh',
      title: 'After Taraweeh Prayer',
      arabicText: 'سُبْحَانَ ذِي الْمُلْكِ وَالْمَلَكُوتِ، سُبْحَانَ ذِي الْعِزَّةِ وَالْعَظَمَةِ وَالْهَيْبَةِ وَالْقُدْرَةِ وَالْكِبْرِيَاءِ وَالْجَبَرُوتِ',
      transliteration: "Subhana dhil-mulki wal-malakut, subhana dhil-'izzati wal-'azamati wal-haybati wal-qudratti wal-kibriya'i wal-jabarut",
      translation: "Glory be to the Possessor of the dominion and sovereignty. Glory be to the Possessor of might, greatness, magnificence, power, pride, and majesty.",
      category: 'Ramadan',
      source: 'Nasai',
    ),
    Dua(
      id: 'ramadan_forgiveness',
      title: 'Seeking Forgiveness in Ramadan',
      arabicText: 'اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ، وَأَوَّلَهُ وَآخِرَهُ، وَعَلَانِيَتَهُ وَسِرَّهُ',
      transliteration: "Allahummaghfir li dhanbi kullahu, diqqahu wa jillahu, wa awwalahu wa akhirahu, wa 'alaniyatahu wa sirrahu",
      translation: "O Allah, forgive all my sins, the small and the great, the first and the last, the open and the secret.",
      category: 'Ramadan',
      source: 'Muslim',
    ),
    Dua(
      id: 'ramadan_last_ten_nights',
      title: 'Last Ten Nights of Ramadan',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ خَيْرِ هَذِهِ اللَّيْلَةِ وَأَعُوذُ بِكَ مِنْ شَرِّهَا',
      transliteration: "Allahumma inni as'aluka min khayri hadhihil-laylati wa a'udhu bika min sharriha",
      translation: "O Allah, I ask You for the good of this night and seek refuge in You from its evil.",
      category: 'Ramadan',
      source: 'Traditional',
    ),
    
    // Parents
    Dua(
      id: 'parents_1',
      title: 'For Parents',
      arabicText: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
      transliteration: "Rabbir-hamhuma kama rabbayani saghira",
      translation: "My Lord, have mercy upon them as they brought me up when I was small.",
      category: 'Family',
      source: 'Quran 17:24',
    ),
    Dua(
      id: 'family_2',
      title: 'For Spouse and Children',
      arabicText: 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
      transliteration: "Rabbana hab lana min azwajina wa dhurriyyatina qurrata a'yunin waj'alna lil-muttaqina imama",
      translation: "Our Lord, grant us from our spouses and offspring comfort to our eyes, and make us leaders for the righteous.",
      category: 'Family',
      source: 'Quran 25:74',
    ),
    Dua(
      id: 'family_3',
      title: 'For Righteous Offspring',
      arabicText: 'رَبِّ هَبْ لِي مِنَ الصَّالِحِينَ',
      transliteration: "Rabbi hab li minas-salihin",
      translation: "My Lord, grant me righteous offspring.",
      category: 'Family',
      source: 'Quran 37:100',
    ),
    
    // General
    Dua(
      id: 'general_1',
      title: 'Comprehensive Dua',
      arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      transliteration: "Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan waqina 'adhaban-nar",
      translation: "Our Lord, give us good in this world and in the Hereafter, and protect us from the punishment of the Fire.",
      category: 'General',
      source: 'Quran 2:201',
    ),
    Dua(
      id: 'general_2',
      title: 'For All Good',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنَ الْخَيْرِ كُلِّهِ عَاجِلِهِ وَآجِلِهِ، مَا عَلِمْتُ مِنْهُ وَمَا لَمْ أَعْلَمْ',
      transliteration: "Allahumma inni as'aluka minal-khayri kullihi, 'ajilihi wa ajilihi, ma 'alimtu minhu wa ma lam a'lam",
      translation: "O Allah, I ask You for all that is good, in this world and in the Hereafter, what I know and what I do not know.",
      category: 'General',
      source: 'Ibn Majah',
    ),
    Dua(
      id: 'general_3',
      title: 'For Steadfastness',
      arabicText: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
      transliteration: "Ya Muqallibal-qulub, thabbit qalbi 'ala dinik",
      translation: "O Turner of the hearts, make my heart firm upon Your religion.",
      category: 'General',
      source: 'Tirmidhi',
    ),
    Dua(
      id: 'general_4',
      title: 'Entering the Masjid',
      arabicText: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      transliteration: "Allahumma-ftah li abwaba rahmatik",
      translation: "O Allah, open for me the doors of Your mercy.",
      category: 'General',
      source: 'Muslim',
    ),
    Dua(
      id: 'general_5',
      title: 'Leaving the Masjid',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
      transliteration: "Allahumma inni as'aluka min fadlik",
      translation: "O Allah, I ask You from Your bounty.",
      category: 'General',
      source: 'Muslim',
    ),
    
    // After Salah (Fard) - To be recited after every obligatory prayer
    Dua(
      id: 'after_salah_1',
      title: 'Takbir after Tasleem',
      arabicText: 'اللَّهُ أَكْبَـرُ',
      transliteration: "Allah-hu Akbar",
      translation: "Allah is the greatest.",
      category: 'After Salah',
      source: 'Al-Bukhari, Muslim 3/1685 At Trimidi 2/1038 & Ahmed 5/218',
      repeatCount: 1,
    ),
    Dua(
      id: 'after_salah_2',
      title: 'Istighfar (3 times)',
      arabicText: 'أَسْتَغْفِرُ اللَّهَ',
      transliteration: "Astaghfirullah",
      translation: "I seek forgiveness from Allah.",
      category: 'After Salah',
      source: 'Muslim',
      repeatCount: 3,
    ),
    Dua(
      id: 'after_salah_3',
      title: 'Peace and Glory',
      arabicText: 'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
      transliteration: "Allahumma antas-salam wa minkas-salam, tabarakta ya dhal-jalali wal-ikram",
      translation: "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor.",
      category: 'After Salah',
      source: 'Muslim',
    ),
    Dua(
      id: 'after_salah_4',
      title: 'Tawheed Declaration',
      arabicText: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      transliteration: "La ilaha illallahu wahdahu la shareeka lahu, lahul-mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadeer",
      translation: "There is no god but Allah alone, without any partner. To Him belongs the dominion, and to Him belongs all praise, and He has power over all things.",
      category: 'After Salah',
      source: 'Muslim',
    ),
    Dua(
      id: 'after_salah_5',
      title: 'Nullifying Dua',
      arabicText: 'اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ',
      transliteration: "Allahumma la mani'a lima a'tayta, wa la mu'tiya lima mana'ta, wa la yanfa'u dhal-jaddi minkal-jadd",
      translation: "O Allah, there is no preventer of what You give, and no giver of what You prevent. And the might of the mighty person cannot benefit him against You.",
      category: 'After Salah',
      source: 'Bukhari, Muslim',
    ),
    Dua(
      id: 'after_salah_6',
      title: 'Seeking Forgiveness and Help',
      arabicText: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَلَا نَعْبُدُ إِلَّا إِيَّاهُ، لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الْحَسَنُ، لَا إِلَٰهَ إِلَّا اللَّهُ مُخْلِصِينَ لَهُ الدِّينَ وَلَوْ كَرِهَ الْكَافِرُونَ',
      transliteration: "La ilaha illallahu wahdahu la shareeka lahu, lahul-mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadeer. La hawla wa la quwwata illa billah. La ilaha illallahu wa la na'budu illa iyyah. Lahun-ni'matu wa lahul-fadlu wa lahuth-thana'ul-hasan. La ilaha illallahu mukhliseena lahud-deena wa law karihal-kafiroon",
      translation: "There is no god but Allah alone, without partner. To Him belongs the dominion and to Him belongs all praise, and He has power over all things. There is no power and no might except with Allah. There is no god but Allah, and we worship none except Him. To Him belong blessings and grace and fine praise. There is no god but Allah - we are sincere in making our religious devotion to Him, even though the disbelievers may detest it.",
      category: 'After Salah',
      source: 'Muslim',
    ),
    Dua(
      id: 'after_salah_7',
      title: 'Subhanallah (33 times)',
      arabicText: 'سُبْحَانَ اللَّهِ',
      transliteration: "SubhanAllah",
      translation: "Glory be to Allah.",
      category: 'After Salah',
      source: 'Muslim',
      repeatCount: 33,
    ),
    Dua(
      id: 'after_salah_8',
      title: 'Alhamdulillah (33 times)',
      arabicText: 'الْحَمْدُ لِلَّهِ',
      transliteration: "Alhamdulillah",
      translation: "All praise is due to Allah.",
      category: 'After Salah',
      source: 'Muslim',
      repeatCount: 33,
    ),
    Dua(
      id: 'after_salah_9',
      title: 'Allahu Akbar (33 times)',
      arabicText: 'اللَّهُ أَكْبَرُ',
      transliteration: "Allahu Akbar",
      translation: "Allah is the Greatest.",
      category: 'After Salah',
      source: 'Muslim',
      repeatCount: 33,
    ),
    Dua(
      id: 'after_salah_10',
      title: 'Completing to 100',
      arabicText: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      transliteration: "La ilaha illallahu wahdahu la shareeka lahu, lahul-mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadeer",
      translation: "There is no god but Allah alone, without any partner. To Him belongs the dominion and to Him belongs all praise, and He has power over all things.",
      category: 'After Salah',
      source: 'Muslim',
      repeatCount: 1,
      benefit: "Whoever says these after every Fard Salah, his sins will be forgiven even if they are like the foam of the sea.",
    ),
    Dua(
      id: 'after_salah_11',
      title: 'Ayatul Kursi',
      arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      transliteration: "Allahu la ilaha illa huwal-hayyul-qayyum, la ta'khudhuhu sinatun wa la nawm, lahu ma fis-samawati wa ma fil-ard, man dhal-ladhi yashfa'u 'indahu illa bi-idhnih, ya'lamu ma bayna aydeehim wa ma khalfahum, wa la yuheetoona bi-shay'in min 'ilmihi illa bima sha'a, wasi'a kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifdhuhuma, wa huwal-'aliyyul-'adheem",
      translation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
      category: 'After Salah',
      source: 'Quran 2:255',
      benefit: "Whoever recites this after every Fard Salah, nothing prevents him from entering Paradise except death.",
    ),
    
    // Darood & Salawat - Special category with count functionality
    Dua(
      id: 'darood_1',
      title: 'Darood Ibrahim',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ، اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ',
      transliteration: "Allahumma salli 'ala Muhammadin wa 'ala ali Muhammad, kama sallayta 'ala Ibrahima wa 'ala ali Ibrahim, innaka Hamidun Majid. Allahumma barik 'ala Muhammadin wa 'ala ali Muhammad, kama barakta 'ala Ibrahima wa 'ala ali Ibrahim, innaka Hamidun Majid",
      translation: "O Allah, send prayers upon Muhammad and the family of Muhammad, as You sent prayers upon Ibrahim and the family of Ibrahim; You are indeed Worthy of Praise, Full of Glory. O Allah, send blessings upon Muhammad and the family of Muhammad, as You sent blessings upon Ibrahim and the family of Ibrahim; You are indeed Worthy of Praise, Full of Glory.",
      category: 'Darood & Salawat',
      source: 'Bukhari, Muslim',
      benefit: "Sending blessings upon the Prophet ﷺ brings immense reward. The Prophet ﷺ said: 'Whoever sends blessings upon me once, Allah will send blessings upon him ten times.'",
    ),
    Dua(
      id: 'darood_2',
      title: 'Simple Salawat',
      arabicText: 'صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      transliteration: "Sallallahu 'alayhi wa sallam",
      translation: "May Allah's peace and blessings be upon him.",
      category: 'Darood & Salawat',
      source: 'Traditional',
      benefit: "The shortest and most common form of sending blessings. Allah commanded us to send blessings upon the Prophet ﷺ.",
    ),
    Dua(
      id: 'darood_3',
      title: 'Darood Lakhi (100,000 rewards)',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ عَبْدِكَ وَنَبِيِّكَ وَرَسُولِكَ النَّبِيِّ الْأُمِّيِّ وَعَلَى آلِهِ وَصَحْبِهِ وَسَلِّمْ تَسْلِيمًا',
      transliteration: "Allahumma salli 'ala Muhammadin 'abdika wa nabiyyika wa rasulikan-nabiyyil-ummiyyi wa 'ala alihi wa sahbihi wa sallim taslima",
      translation: "O Allah, send blessings upon Muhammad, Your servant, Your Prophet, Your Messenger, the unlettered Prophet, and upon his family and companions, and send abundant peace.",
      category: 'Darood & Salawat',
      source: 'Tirmidhi',
      benefit: "Reciting this once equals the reward of reciting regular Durood 100,000 times. Especially beneficial on Friday.",
    ),
    Dua(
      id: 'darood_4',
      title: 'Durood Tunajjina (Dua of Safety)',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ صَلَاةً تُنْجِينَا بِهَا مِنْ جَمِيعِ الْأَهْوَالِ وَالْآفَاتِ، وَتَقْضِي لَنَا بِهَا جَمِيعَ الْحَاجَاتِ، وَتُطَهِّرُنَا بِهَا مِنْ جَمِيعِ السَّيِّئَاتِ، وَتَرْفَعُنَا بِهَا عِنْدَكَ أَعْلَى الدَّرَجَاتِ، وَتُبَلِّغُنَا بِهَا أَقْصَى الْغَايَاتِ مِنْ جَمِيعِ الْخَيْرَاتِ فِي الْحَيَاةِ وَبَعْدَ الْمَمَاتِ',
      transliteration: "Allahumma salli 'ala sayyidina Muhammadin salatan tunajjina biha min jami'il-ahwali wal-afat, wa taqdi lana biha jami'al-hajat, wa tutahhiruna biha min jami'is-sayyi'at, wa tarfa'una biha 'indaka a'lad-darajat, wa tuballighuna biha aqsal-ghayati min jami'il-khayrati fil-hayati wa ba'dal-mamat",
      translation: "O Allah, send blessings upon our master Muhammad, a prayer by means of which You will rescue us from all fears and calamities, fulfill all our needs, purify us from all evils, raise us to the highest ranks in Your presence, and cause us to reach the ultimate goal of all goodness in this life and after death.",
      category: 'Darood & Salawat',
      source: 'Traditional',
      benefit: "A comprehensive Durood that encompasses protection, fulfillment of needs, purification, and high ranks. Recite 10 times daily for maximum benefit.",
      repeatCount: 10,
    ),
    Dua(
      id: 'darood_5',
      title: 'Durood Nariya (Dua of Light)',
      arabicText: 'اللَّهُمَّ صَلِّ صَلَاةً كَامِلَةً وَسَلِّمْ سَلَامًا تَامًّا عَلَى سَيِّدِنَا مُحَمَّدٍ الَّذِي تَنْحَلُّ بِهِ الْعُقَدُ وَتَنْفَرِجُ بِهِ الْكُرَبُ وَتُقْضَى بِهِ الْحَوَائِجُ وَتُنَالُ بِهِ الرَّغَائِبُ وَحُسْنُ الْخَوَاتِمِ وَيُسْتَسْقَى الْغَمَامُ بِوَجْهِهِ الْكَرِيمِ وَعَلَى آلِهِ وَصَحْبِهِ فِي كُلِّ لَمْحَةٍ وَنَفَسٍ بِعَدَدِ كُلِّ مَعْلُومٍ لَكَ',
      transliteration: "Allahumma salli salatan kamilatan wa sallim salaman tamman 'ala sayyidina Muhammadil-ladhi tanhullu bihil-'uqadu wa tanfariju bihil-kurabu wa tuqda bihil-hawa'iju wa tunalu bihir-ragha'ibu wa husnul-khawatimi wa yustasqal-ghamamu bi-wajhihil-karimi wa 'ala alihi wa sahbihi fi kulli lamhatin wa nafasin bi-'adadi kulli ma'lumin lak",
      translation: "O Allah, send complete blessings and perfect peace upon our master Muhammad, by whom difficulties are solved, anxieties are removed, needs are fulfilled, and desires are attained, and through whom good endings are granted and rain is sought by virtue of his noble countenance, and upon his family and companions, in every moment and breath, by the number of all that is known to You.",
      category: 'Darood & Salawat',
      source: "Traditional (from Dala'il al-Khayrat)",
      benefit: "Known as the 'Durood of Light' - extremely powerful for removing difficulties and fulfilling needs. Recite 4444 times for opening of closed matters, or 11 times daily for general blessings.",
      repeatCount: 11,
    ),
    Dua(
      id: 'darood_6',
      title: 'Friday Special Darood',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ',
      transliteration: "Allahumma salli 'ala Muhammadin wa 'ala ali Muhammad",
      translation: "O Allah, send blessings upon Muhammad and the family of Muhammad.",
      category: 'Darood & Salawat',
      source: 'Abu Dawud, Nasai',
      benefit: "The Prophet ﷺ said: 'Send abundant blessings upon me on Friday, for it is witnessed by the angels.' Sending Durood on Friday is especially meritorious. Recommended: 80-100 times on Friday.",
      repeatCount: 80,
    ),
    Dua(
      id: 'darood_7',
      title: 'Morning & Evening Darood',
      arabicText: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
      transliteration: "Allahumma salli wa sallim 'ala nabiyyina Muhammad",
      translation: "O Allah, send blessings and peace upon our Prophet Muhammad.",
      category: 'Darood & Salawat',
      source: 'Abu Dawud',
      benefit: "The Prophet ﷺ said: 'Whoever sends blessings upon me ten times in the morning and ten times in the evening will attain my intercession on the Day of Resurrection.'",
      repeatCount: 10,
    ),
  ];
}
