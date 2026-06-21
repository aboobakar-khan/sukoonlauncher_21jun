import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Warm Reading Palette ──
const Color _creamBg = Color(0xFFFDF6EC);
const Color _warmSand = Color(0xFFF5E6C8);
const Color _richBrown = Color(0xFF2C1810);
const Color _warmBrown = Color(0xFF5C4033);
const Color _goldAccent = Color(0xFFC2A366);
const Color _islamicGreen = Color(0xFF2E7D32);

/// Minimalist Duas Screen - 40 Essential Duas
/// Warm cream reading experience with generous typography
class MinimalistDuasScreen extends StatefulWidget {
  const MinimalistDuasScreen({super.key});

  @override
  State<MinimalistDuasScreen> createState() => _MinimalistDuasScreenState();
}

class _MinimalistDuasScreenState extends State<MinimalistDuasScreen> {
  int? _expandedIndex;

  // 40 Essential Duas
  static const List<Map<String, String>> _duas = [
    // Morning & Evening
    {'category': 'morning', 'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ', 'translation': 'We have reached the morning and at this time the kingdom belongs to Allah.', 'transliteration': 'Asbahna wa asbahal mulku lillah'},
    {'category': 'evening', 'arabic': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ', 'translation': 'We have reached the evening and at this time the kingdom belongs to Allah.', 'transliteration': 'Amsayna wa amsal mulku lillah'},
    {'category': 'protection', 'arabic': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ', 'translation': 'In the name of Allah, with whose name nothing can harm.', 'transliteration': 'Bismillahil-ladhi la yadurru ma\'asmihi shay\'un'},
    
    // Waking & Sleeping
    {'category': 'waking', 'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا', 'translation': 'All praise is for Allah who gave us life after death.', 'transliteration': 'Alhamdulillahil-ladhi ahyana ba\'da ma amatana'},
    {'category': 'sleeping', 'arabic': 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا', 'translation': 'In Your name, O Allah, I die and I live.', 'transliteration': 'Bismika Allahumma amutu wa ahya'},
    {'category': 'sleeping', 'arabic': 'اللَّهُمَّ بِاسْمِكَ أَحْيَا وَبِاسْمِكَ أَمُوتُ', 'translation': 'O Allah, in Your name I live and in Your name I die.', 'transliteration': 'Allahumma bismika ahya wa bismika amut'},
    
    // Eating & Drinking
    {'category': 'before eating', 'arabic': 'بِسْمِ اللَّهِ وَعَلَى بَرَكَةِ اللَّهِ', 'translation': 'In the name of Allah and with the blessings of Allah.', 'transliteration': 'Bismillahi wa \'ala barakatillah'},
    {'category': 'after eating', 'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا', 'translation': 'Praise be to Allah who fed us and gave us drink.', 'transliteration': 'Alhamdulillahil-ladhi at\'amana wa saqana'},
    
    // Prayer Related
    {'category': 'entering mosque', 'arabic': 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ', 'translation': 'O Allah, open for me the doors of Your mercy.', 'transliteration': 'Allahummaf-tah li abwaba rahmatik'},
    {'category': 'leaving mosque', 'arabic': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ', 'translation': 'O Allah, I ask You from Your bounty.', 'transliteration': 'Allahumma inni as\'aluka min fadlik'},
    {'category': 'before prayer', 'arabic': 'اللَّهُمَّ بَاعِدْ بَيْنِي وَبَيْنَ خَطَايَايَ', 'translation': 'O Allah, distance me from my sins.', 'transliteration': 'Allahumma ba\'id bayni wa bayna khatayaya'},
    {'category': 'after prayer', 'arabic': 'أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ', 'translation': 'I seek forgiveness from Allah (3 times).', 'transliteration': 'Astaghfirullah (3x)'},
    
    // Travel
    {'category': 'travel', 'arabic': 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا', 'translation': 'Glory be to Him who has subjected this to us.', 'transliteration': 'Subhanal-ladhi sakhkhara lana hadha'},
    {'category': 'travel', 'arabic': 'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى', 'translation': 'O Allah, we ask You for righteousness and piety in this journey.', 'transliteration': 'Allahumma inna nas\'aluka fi safarina hadhal birra wat-taqwa'},
    {'category': 'returning', 'arabic': 'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ', 'translation': 'Returning, repenting, worshipping, and praising our Lord.', 'transliteration': 'Ayibuna ta\'ibuna \'abiduna lirabbina hamidun'},
    
    // Home
    {'category': 'entering home', 'arabic': 'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا', 'translation': 'In the name of Allah we enter, in the name of Allah we leave.', 'transliteration': 'Bismillahi walajna, wa bismillahi kharajna'},
    {'category': 'leaving home', 'arabic': 'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ', 'translation': 'In the name of Allah, I place my trust in Allah.', 'transliteration': 'Bismillahi tawakkaltu \'alallah'},
    
    // Bathroom
    {'category': 'entering bathroom', 'arabic': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبْثِ وَالْخَبَائِثِ', 'translation': 'O Allah, I seek refuge in You from evil.', 'transliteration': 'Allahumma inni a\'udhu bika minal khubthi wal khaba\'ith'},
    {'category': 'leaving bathroom', 'arabic': 'غُفْرَانَكَ', 'translation': 'I seek Your forgiveness.', 'transliteration': 'Ghufranaka'},
    
    // Distress & Relief
    {'category': 'distress', 'arabic': 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ', 'translation': 'There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.', 'transliteration': 'La ilaha illa anta subhanaka inni kuntu minaz-zalimin'},
    {'category': 'anxiety', 'arabic': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ', 'translation': 'O Allah, I seek refuge in You from worry and grief.', 'transliteration': 'Allahumma inni a\'udhu bika minal-hammi wal-hazan'},
    {'category': 'difficulty', 'arabic': 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'translation': 'Allah is sufficient for us, and He is the best disposer of affairs.', 'transliteration': 'Hasbunallahu wa ni\'mal wakil'},
    {'category': 'relief', 'arabic': 'الْحَمْدُ لِلَّهِ عَلَى كُلِّ حَالٍ', 'translation': 'Praise be to Allah in all circumstances.', 'transliteration': 'Alhamdulillahi \'ala kulli hal'},
    
    // Forgiveness
    {'category': 'forgiveness', 'arabic': 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ', 'translation': 'My Lord, forgive me and accept my repentance.', 'transliteration': 'Rabbighfir li wa tub \'alayya'},
    {'category': 'forgiveness', 'arabic': 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ', 'translation': 'O Allah, You are my Lord, there is no deity except You.', 'transliteration': 'Allahumma anta rabbi la ilaha illa anta'},
    {'category': 'sayyidul istighfar', 'arabic': 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ', 'translation': 'O Allah, You are my Lord. None has the right to be worshipped except You. You created me and I am Your slave.', 'transliteration': 'Allahumma anta rabbi la ilaha illa anta khalaqtani wa ana \'abduk'},
    
    // Guidance & Knowledge
    {'category': 'guidance', 'arabic': 'رَبِّ زِدْنِي عِلْمًا', 'translation': 'My Lord, increase me in knowledge.', 'transliteration': 'Rabbi zidni \'ilma'},
    {'category': 'guidance', 'arabic': 'اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي', 'translation': 'O Allah, guide me and keep me on the right path.', 'transliteration': 'Allahummah-dini wa saddidni'},
    {'category': 'istikhara', 'arabic': 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ', 'translation': 'O Allah, I seek Your guidance by virtue of Your knowledge.', 'transliteration': 'Allahumma inni astakhiruka bi\'ilmik'},
    
    // Health
    {'category': 'visiting sick', 'arabic': 'لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ', 'translation': 'No worry, it is a purification, if Allah wills.', 'transliteration': 'La ba\'sa tahur in sha Allah'},
    {'category': 'healing', 'arabic': 'اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَاسَ اشْفِهِ', 'translation': 'O Allah, Lord of mankind, remove the harm and heal.', 'transliteration': 'Allahumma rabban-nas adhhibil-ba\'s ishfihi'},
    
    // Gratitude
    {'category': 'gratitude', 'arabic': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ', 'translation': 'O Allah, help me to remember You and thank You.', 'transliteration': 'Allahumma a\'inni \'ala dhikrika wa shukrik'},
    {'category': 'blessing', 'arabic': 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا', 'translation': 'O Allah, bless us in what You have provided.', 'transliteration': 'Allahumma barik lana fima razaqtana'},
    
    // Protection
    {'category': 'protection', 'arabic': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ', 'translation': 'I seek refuge in the perfect words of Allah from the evil of what He has created.', 'transliteration': 'A\'udhu bi kalimatillahit-tammati min sharri ma khalaq'},
    {'category': 'evil eye', 'arabic': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ', 'translation': 'I seek refuge in the words of Allah from every devil and harmful creature.', 'transliteration': 'A\'udhu bi kalimatillahi min kulli shaytanin wa hammah'},
    
    // Parents
    {'category': 'parents', 'arabic': 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا', 'translation': 'My Lord, have mercy upon them as they raised me when I was small.', 'transliteration': 'Rabbir-hamhuma kama rabbayani saghira'},
    {'category': 'family', 'arabic': 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ', 'translation': 'Our Lord, grant us from our spouses and offspring the comfort of our eyes.', 'transliteration': 'Rabbana hablana min azwajina wa dhurriyyatina qurrata a\'yun'},
    
    // Death
    {'category': 'deceased', 'arabic': 'اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ', 'translation': 'O Allah, forgive him and have mercy on him.', 'transliteration': 'Allahummaghfir lahu warhamhu'},
    {'category': 'patience', 'arabic': 'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ', 'translation': 'Indeed, we belong to Allah and to Him we shall return.', 'transliteration': 'Inna lillahi wa inna ilayhi raji\'un'},
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _creamBg,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _creamBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _creamBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _duas.length,
                  itemBuilder: (context, index) => _buildDuaCard(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: _richBrown.withValues(alpha: 0.6), size: 22),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('40 Duas',
                style: TextStyle(color: _richBrown.withValues(alpha: 0.85), fontSize: 20, fontWeight: FontWeight.w500)),
              Text('Essential supplications',
                style: TextStyle(color: _warmBrown.withValues(alpha: 0.4), fontSize: 12)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _islamicGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${_duas.length}',
              style: TextStyle(color: _islamicGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDuaCard(int index) {
    final dua = _duas[index];
    final isExpanded = _expandedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() => _expandedIndex = isExpanded ? null : index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isExpanded ? _warmSand.withValues(alpha: 0.5) : _warmSand.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? _goldAccent.withValues(alpha: 0.2) : _warmSand.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category + number row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _islamicGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(dua['category']!.toUpperCase(),
                  style: TextStyle(color: _islamicGreen.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              ),
              const Spacer(),
              Text('#${index + 1}',
                style: TextStyle(color: _warmBrown.withValues(alpha: 0.2), fontSize: 11)),
            ]),
            
            const SizedBox(height: 16),
            
            // Arabic in warm container
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isExpanded ? 20 : 14),
              decoration: BoxDecoration(
                color: isExpanded ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dua['arabic']!,
                style: TextStyle(
                  color: _richBrown,
                  fontSize: isExpanded ? 26 : 21,
                  height: 1.9,
                  fontFamily: 'Amiri',
                ),
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            ),
            
            // Expanded content
            if (isExpanded) ...[
              const SizedBox(height: 18),
              
              // Ornamental divider
              Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 30, height: 0.5, color: _goldAccent.withValues(alpha: 0.2)),
                const SizedBox(width: 8),
                Text('✦', style: TextStyle(fontSize: 8, color: _goldAccent.withValues(alpha: 0.3))),
                const SizedBox(width: 8),
                Container(width: 30, height: 0.5, color: _goldAccent.withValues(alpha: 0.2)),
              ])),
              
              const SizedBox(height: 16),
              
              // Transliteration
              Text(dua['transliteration']!,
                style: TextStyle(
                  color: _warmBrown.withValues(alpha: 0.55),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Translation
              Text(dua['translation']!,
                style: TextStyle(
                  color: _richBrown.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Copy action — minimal
              Center(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text: '${dua['arabic']}\n\n${dua['transliteration']}\n\n${dua['translation']}'));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Dua copied', style: TextStyle(color: Colors.white)),
                      backgroundColor: _goldAccent,
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy_rounded, color: _warmBrown.withValues(alpha: 0.3), size: 14),
                    const SizedBox(width: 6),
                    Text('Copy', style: TextStyle(color: _warmBrown.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('tap to read',
                style: TextStyle(color: _warmBrown.withValues(alpha: 0.15), fontSize: 10),
                textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
