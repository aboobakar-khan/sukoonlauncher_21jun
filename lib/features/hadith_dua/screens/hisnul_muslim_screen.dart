import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/islamic_theme_provider.dart';

// ──────────────────────────────────────────────────────────────────────
//  DATA — All 102 Hisnul Muslim entries
// ──────────────────────────────────────────────────────────────────────
class HisnulEntry {
  final int id;
  final String type; // "Adhkar" or "Dua"
  final String category;
  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String reference;
  final int? count;
  final String? reward;

  const HisnulEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
    this.count,
    this.reward,
  });

  String get shareableText {
    final buf = StringBuffer();
    buf.writeln('📿 $title');
    buf.writeln();
    buf.writeln(arabic);
    buf.writeln();
    buf.writeln(transliteration);
    buf.writeln();
    buf.writeln(translation);
    if (count != null) {
      buf.writeln();
      buf.writeln('🔢 Repeat: $count time${count! > 1 ? "s" : ""}');
    }
    if (reward != null) {
      buf.writeln();
      buf.writeln('⭐ $reward');
    }
    buf.writeln();
    buf.writeln('📖 $reference');
    buf.writeln();
    buf.writeln('— Hisnul Muslim (حِصْنُ الْمُسْلِم)');
    buf.writeln('https://play.google.com/store/apps/details?id=com.sukoon.launcher');
    return buf.toString();
  }
}

const List<HisnulEntry> _allEntries = [
  HisnulEntry(id:1,type:"Adhkar",category:"Morning Adhkar",title:"Opening morning remembrance",arabic:"أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ",transliteration:"Asbahna wa asbahal mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah, lahul mulku walahul hamdu wahuwa 'ala kulli shay'in qadir, rabbi as'aluka khayra ma fi hadhal yawmi wa khayra ma ba'dahu, wa a'udhu bika min sharri ma fi hadhal yawmi wa sharri ma ba'dahu",translation:"We have reached the morning and at this very time all sovereignty belongs to Allah. All praise is for Allah. None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and praise, and He is over all things omnipotent. My Lord, I ask You for the good of this day and the good of what follows it, and I take refuge in You from the evil of this day and the evil of what follows it.",count:1,reference:"Muslim 4/2088, Hisnul Muslim No. 78",reward:"The Prophet ﷺ would never begin his day without this remembrance. Saying it connects the Muslim to his Lord at the first moment of the day, ensuring Allah's sovereignty is acknowledged — a deed that earns His pleasure and sets a blessed tone for all that follows. (Muslim 4/2088)"),
  HisnulEntry(id:2,type:"Adhkar",category:"Morning Adhkar",title:"Morning tawhid and gratitude",arabic:"اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ",transliteration:"Allahumma bika asbahna, wa bika amsayna, wa bika nahya, wa bika namutu, wa ilaykan-nushur",translation:"O Allah, by You we have entered the morning and by You we have entered the evening, by You we live and by You we die, and to You is the resurrection.",count:1,reference:"At-Tirmidhi 5/466, Hisnul Muslim No. 75",reward:"The Prophet ﷺ taught this supplication to his companions as the morning opener. Beginning and ending the day with full reliance upon Allah — acknowledging that life, death, and resurrection are all in His hands — is a form of complete tawakkul that earns Allah's care and protection. (At-Tirmidhi 5/466)"),
  HisnulEntry(id:3,type:"Adhkar",category:"Morning Adhkar",title:"Sayyid al-Istighfar – Master supplication for forgiveness",arabic:"اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ",transliteration:"Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana 'abduk, wa ana 'ala 'ahdika wa wa'dika mastata't, a'udhu bika min sharri ma sana't, abu'u laka bini'matika 'alay, wa abu'u bidhanbī faghfir li fa'innahu la yaghfirudh-dhunuba illa ant",translation:"O Allah, You are my Lord. None has the right to be worshipped except You. You created me and I am Your slave. I keep Your covenant and my pledge to You as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for none forgives sins except You.",count:1,reference:"Al-Bukhari 7/150, Hisnul Muslim No. 68",reward:"Whoever says this with firm conviction in the morning and dies before evening will be among the people of Paradise; and whoever says it with firm conviction in the evening and dies before morning will be among the people of Paradise. (Al-Bukhari 7/150)"),
  HisnulEntry(id:4,type:"Adhkar",category:"Morning Adhkar",title:"Morning testimony of faith (x4)",arabic:"اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لاَ إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيكَ لَكَ، وَأَنَّ مُحَمَّداً عَبْدُكَ وَرَسُولُكَ",transliteration:"Allahumma inni asbahtu ushhiduka, wa ushhidu hamalata 'arshik, wa mala'ikatak, wa jami'a khalqik, annaka antallahu la ilaha illa anta wahdaka la sharika lak, wa anna Muhammadan 'abduka wa rasuluk",translation:"O Allah, I have entered the morning, and I call You to witness, and I call the bearers of Your throne, Your angels, and all Your creation to witness, that You are Allah — none has the right to be worshipped except You, alone, without partner, and that Muhammad is Your slave and messenger.",count:4,reference:"Abu Dawud 4/317, Hisnul Muslim No. 80",reward:"Whoever says this four times in the morning, Allah will grant him freedom from Hellfire four times that day; and whoever says it four times in the evening, the same reward is given. (Abu Dawud 4/317, authenticated by Al-Albani)"),
  HisnulEntry(id:5,type:"Adhkar",category:"Morning Adhkar",title:"Morning gratitude for blessings",arabic:"اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لاَ شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ",transliteration:"Allahumma ma asbaha bi min ni'matin aw bi'ahadin min khalqika faminka wahdaka la sharika lak, falakal hamdu wa lakash-shukr",translation:"O Allah, whatever blessing I or any of Your creation have risen upon, it is from You alone, without partner. So for You is all praise and unto You all thanks.",count:1,reference:"Abu Dawud 4/318, Hisnul Muslim No. 84",reward:"Whoever says this in the morning has given thanks for that day's blessings; whoever says it in the evening has given thanks for that night's blessings. (Abu Dawud 4/318, authenticated by Ibn Hibban)"),
  HisnulEntry(id:6,type:"Adhkar",category:"Morning Adhkar",title:"Morning surahs of protection (x3)",arabic:"بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ﴿قُلْ هُوَ اللَّهُ أَحَدٌ…﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ…﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ…﴾",transliteration:"Bismillahir-rahmanir-rahim: Qul huwallahu ahad… | Qul a'udhu birabbil-falaq… | Qul a'udhu birabbin-nas…",translation:"Recite Surah Al-Ikhlas, Surah Al-Falaq, and Surah An-Nas — three times each in the morning and evening.",count:3,reference:"Abu Dawud 4/322, Hisnul Muslim No. 100",reward:"They will suffice you against everything — reciting them three times in the morning and evening provides complete protection for the day and night. (Abu Dawud, At-Tirmidhi)"),
  HisnulEntry(id:7,type:"Adhkar",category:"Morning Adhkar",title:"Contentment with Allah, Islam, and the Prophet",arabic:"رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلاَمِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا",transliteration:"Raditu billahi rabba, wa bil-islami dina, wa bi-Muhammadin sallallahu 'alayhi wa sallama nabiya",translation:"I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad (peace be upon him) as my Prophet.",count:3,reference:"Abu Dawud 4/318, Hisnul Muslim No. 85",reward:"It is a right upon Allah to please whoever says it three times. (Abu Dawud 4/318)"),
  HisnulEntry(id:8,type:"Adhkar",category:"Evening Adhkar",title:"Opening evening remembrance",arabic:"أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا",transliteration:"Amsayna wa amsal mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah, lahul mulku walahul hamdu wahuwa 'ala kulli shay'in qadir, rabbi as'aluka khayra ma fi hadhihil laylati wa khayra ma ba'daha",translation:"We have entered the evening and at this very time all sovereignty belongs to Allah. All praise is for Allah. None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and praise, and He is over all things omnipotent. My Lord, I ask You for the good of this night and the good of what follows it.",count:1,reference:"Muslim 4/2088, Hisnul Muslim No. 79",reward:"The Prophet ﷺ would never begin his evening without this remembrance. Acknowledging Allah's dominion at the close of day is a means of earning His forgiveness for the day's shortcomings and entering the night under His protection and care. (Muslim 4/2088)"),
  HisnulEntry(id:9,type:"Adhkar",category:"Evening Adhkar",title:"Evening tawhid and gratitude",arabic:"اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ",transliteration:"Allahumma bika amsayna, wa bika asbahna, wa bika nahya, wa bika namutu, wa ilaykal-masir",translation:"O Allah, by You we have entered the evening and by You we have entered the morning, by You we live and by You we die, and to You is our return.",count:1,reference:"At-Tirmidhi 5/466, Hisnul Muslim No. 76",reward:"The Prophet ﷺ taught this as the evening counterpart to the morning dua. Ending the day affirming that everything — life, death, and return — belongs to Allah is among the most complete acts of 'uboodiyyah (servitude), earning His love and protection through the night. (At-Tirmidhi 5/466)"),
  HisnulEntry(id:10,type:"Adhkar",category:"Evening Adhkar",title:"Protection in the name of Allah (x3)",arabic:"بِسْمِ اللَّهِ الَّذِي لاَ يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلاَ فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ",transliteration:"Bismillahil-ladhi la yadurru ma'asmihi shay'un fil-ardi wa la fis-sama'i wa huwas-sami'ul-'alim",translation:"In the name of Allah with whose name nothing on earth or in heaven can cause harm, and He is the All-Hearing, the All-Knowing.",count:3,reference:"Abu Dawud 4/323, Hisnul Muslim No. 98",reward:"Whoever says this three times in the morning and evening will not be harmed by anything. (Abu Dawud 4/323, At-Tirmidhi 5/465)"),
  HisnulEntry(id:11,type:"Adhkar",category:"Evening Adhkar",title:"Evening testimony of faith (x4)",arabic:"اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لاَ إِلَهَ إِلاَّ أَنْتَ وَحْدَكَ لاَ شَرِيكَ لَكَ، وَأَنَّ مُحَمَّداً عَبْدُكَ وَرَسُولُكَ",transliteration:"Allahumma inni amsaytu ushhiduka, wa ushhidu hamalata 'arshik, wa mala'ikatak, wa jami'a khalqik, annaka antallahu la ilaha illa anta wahdaka la sharika lak, wa anna Muhammadan 'abduka wa rasuluk",translation:"O Allah, I have entered the evening, and I call You to witness, and I call the bearers of Your throne, Your angels, and all Your creation to witness, that You are Allah — none has the right to be worshipped except You, alone, without partner, and that Muhammad is Your slave and messenger.",count:4,reference:"Abu Dawud 4/317, Hisnul Muslim No. 81",reward:"Whoever says this four times in the evening, Allah will grant him freedom from Hellfire four times that night. (Abu Dawud 4/317, authenticated by Al-Albani)"),
  HisnulEntry(id:12,type:"Adhkar",category:"Evening Adhkar",title:"Seeking refuge from evil of creation (x3)",arabic:"أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",transliteration:"A'udhu bikalimatillahit-tammati min sharri ma khalaq",translation:"I seek refuge in the perfect words of Allah from the evil of what He has created.",count:3,reference:"Muslim 4/2080, Hisnul Muslim No. 99",reward:"Whoever says this three times when he enters the evening, nothing will harm him that night. (Muslim 4/2080)"),
  HisnulEntry(id:13,type:"Adhkar",category:"Evening Adhkar",title:"Evening Sayyid al-Istighfar",arabic:"اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ",transliteration:"Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana 'abduk, wa ana 'ala 'ahdika wa wa'dika mastata't, a'udhu bika min sharri ma sana't, abu'u laka bini'matika 'alay, wa abu'u bidhanbī faghfir li fa'innahu la yaghfirudh-dhunuba illa ant",translation:"O Allah, You are my Lord. None has the right to be worshipped except You. You created me and I am Your slave. I keep Your covenant and my pledge to You as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for none forgives sins except You. (Recited in the evening.)",count:1,reference:"Al-Bukhari 7/150, Hisnul Muslim No. 68",reward:"Whoever says this with firm conviction in the evening and dies before morning will be among the people of Paradise. (Al-Bukhari 7/150)"),
  HisnulEntry(id:14,type:"Adhkar",category:"Evening Adhkar",title:"Evening surahs of protection (x3)",arabic:"بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ﴿قُلْ هُوَ اللَّهُ أَحَدٌ…﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ…﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ…﴾",transliteration:"Bismillahir-rahmanir-rahim: Qul huwallahu ahad… | Qul a'udhu birabbil-falaq… | Qul a'udhu birabbin-nas…",translation:"Recite Surah Al-Ikhlas, Surah Al-Falaq, and Surah An-Nas — three times each in the evening.",count:3,reference:"Abu Dawud 4/322, Hisnul Muslim No. 100",reward:"They will suffice you against everything — reciting them three times in the morning and evening provides complete protection for the day and night. (Abu Dawud, At-Tirmidhi)"),
  HisnulEntry(id:15,type:"Adhkar",category:"After Salah Adhkar",title:"Seeking forgiveness and salutation of peace",arabic:"أَسْتَغْفِرُ اللَّهَ — (ثَلاَثاً) — اللَّهُمَّ أَنْتَ السَّلاَمُ، وَمِنْكَ السَّلاَمُ، تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ",transliteration:"Astaghfirullah — (three times) — Allahumma antas-salam, wa minkas-salam, tabarakta ya dhal-jalali wal-ikram",translation:"I seek the forgiveness of Allah — (three times) — O Allah, You are As-Salam (Peace), and from You comes peace. Blessed are You, O Possessor of glory and honour.",count:3,reference:"Muslim 1/414, Hisnul Muslim No. 58",reward:"The three Astaghfirullahs expiate the shortcomings of the prayer just completed. The Prophet ﷺ never left this after any prayer. (Muslim 1/414)"),
  HisnulEntry(id:16,type:"Adhkar",category:"After Salah Adhkar",title:"Tahlil after salah",arabic:"لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لاَ مَانِعَ لِمَا أَعْطَيْتَ، وَلاَ مُعْطِيَ لِمَا مَنَعْتَ، وَلاَ يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ",transliteration:"La ilaha illallahu wahdahu la sharika lah, lahul mulku walahul hamdu wahuwa 'ala kulli shay'in qadir, Allahumma la mani'a lima a'tayt, wa la mu'tiya lima mana't, wa la yanfa'u dhal-jaddi minkal-jadd",translation:"None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and praise and He is over all things omnipotent. O Allah, none can withhold what You give, and none can give what You withhold, and no wealth or majesty can benefit anyone, as from You is all wealth and majesty.",count:1,reference:"Al-Bukhari 1/255, Hisnul Muslim No. 60",reward:"Whoever recites this after every obligatory prayer will be in the protection of Allah until the next prayer. (Al-Bukhari 1/255, Muslim 1/415)"),
  HisnulEntry(id:17,type:"Adhkar",category:"After Salah Adhkar",title:"Post-salah tasbeeh, tahmid, and takbir",arabic:"سُبْحَانَ اللَّهِ — (ثَلاَثاً وَثَلاَثِينَ) — الْحَمْدُ لِلَّهِ — (ثَلاَثاً وَثَلاَثِينَ) — اللَّهُ أَكْبَرُ — (أَرْبَعاً وَثَلاَثِينَ)",transliteration:"SubhanAllah — (33 times) — Alhamdu lillah — (33 times) — Allahu Akbar — (34 times)",translation:"Glory be to Allah — 33 times. All praise is for Allah — 33 times. Allah is the Greatest — 34 times. (Together they total 100.)",count:33,reference:"Muslim 1/418, Hisnul Muslim No. 63",reward:"All his sins will be forgiven even if they are like the foam of the sea. (Muslim 1/418)"),
  HisnulEntry(id:18,type:"Adhkar",category:"After Salah Adhkar",title:"Ayat al-Kursi after every obligatory salah",arabic:"اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ، لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ، لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ، مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ، يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ، وَلاَ يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلاَّ بِمَا شَاءَ، وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ، وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ",transliteration:"Allahu la ilaha illa huwal-hayyul-qayyum, la ta'khudhuhu sinatun wa la nawm, lahu ma fis-samawati wa ma fil-ard, man dhalladhi yashfa'u 'indahu illa bi'idhnih, ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhitunabishay'in min 'ilmihi illa bima sha', wasi'a kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma wa huwal-'aliyyul-'azim",translation:"Allah — there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His throne extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",count:1,reference:"An-Nasa'i / Al-Bukhari 6/325, Hisnul Muslim No. 56",reward:"Nothing will stand between the one who recites it after every obligatory prayer and entering Paradise except death. (An-Nasa'i, authenticated by Al-Albani)"),
  HisnulEntry(id:19,type:"Adhkar",category:"After Salah Adhkar",title:"Surahs after Fajr and Maghrib (x3)",arabic:"﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ﴾",transliteration:"Qul huwallahu ahad | Qul a'udhu birabbil-falaq | Qul a'udhu birabbin-nas",translation:"Recite Surah Al-Ikhlas, Surah Al-Falaq, and Surah An-Nas three times each after Fajr and Maghrib prayers.",count:3,reference:"Abu Dawud 2/86, Hisnul Muslim No. 57",reward:"They will suffice you against all things — reciting them three times after Fajr and Maghrib provides complete protection until the next prayer. (Abu Dawud, At-Tirmidhi, authenticated by Al-Albani)"),
  HisnulEntry(id:20,type:"Dua",category:"After Salah Adhkar",title:"Supplication for help in worship",arabic:"اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ",transliteration:"Allahumma a'inni 'ala dhikrika, wa shukrika, wa husni 'ibadatik",translation:"O Allah, help me to remember You, to give thanks to You, and to worship You in the best manner.",reference:"Abu Dawud 2/86, Hisnul Muslim No. 54",reward:"The Prophet ﷺ took Mu'adh ibn Jabal's hand and said: 'O Mu'adh, by Allah I love you! I advise you: never forget to say this after every prayer.' (Abu Dawud 2/86, authenticated as Hasan)"),
  HisnulEntry(id:21,type:"Dua",category:"After Salah Adhkar",title:"Protection from cowardice, miserliness, and the grave",arabic:"اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْجُبْنِ، وَأَعُوذُ بِكَ أَنْ أُرَدَّ إِلَى أَرْذَلِ الْعُمُرِ، وَأَعُوذُ بِكَ مِنْ فِتْنَةِ الدُّنْيَا، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ",transliteration:"Allahumma inni a'udhu bika minal-jubn, wa a'udhu bika an uradda ila ardhalil-'umur, wa a'udhu bika min fitnatid-dunya, wa a'udhu bika min 'adhabul-qabr",translation:"O Allah, I seek refuge in You from cowardice, and I seek refuge in You from being returned to a decrepit old age, and I seek refuge in You from the trials of this world, and I seek refuge in You from the punishment of the grave.",reference:"Al-Bukhari 7/158, Hisnul Muslim No. 64",reward:"The Prophet ﷺ used to regularly recite this dua — seeking refuge from six spiritual and worldly diseases. (Al-Bukhari 7/158)"),
  HisnulEntry(id:22,type:"Dua",category:"Waking Up & Sleeping",title:"Upon waking from sleep",arabic:"الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",transliteration:"Alhamdu lillahil-ladhi ahyana ba'da ma amatana wa ilayhin-nushur",translation:"All praise is for Allah who gave us life after having taken it from us and unto Him is the resurrection.",reference:"Al-Bukhari 11/113, Hisnul Muslim No. 27",reward:"Sleep is described in the Quran as a minor death (39:42). Waking up and immediately praising Allah for returning your soul is an act of shukr that earns tremendous reward. (Al-Bukhari 11/113)"),
  HisnulEntry(id:23,type:"Dua",category:"Waking Up & Sleeping",title:"Before going to sleep",arabic:"بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا",transliteration:"Bismika Allahumma amutu wa ahya",translation:"In Your name, O Allah, I die and I live.",reference:"Al-Bukhari 11/113, Hisnul Muslim No. 32",reward:"The Prophet ﷺ commanded this before sleeping. Entrusting your life (and death) to Allah by name before sleep is a form of tawakkul. (Al-Bukhari 11/113)"),
  HisnulEntry(id:24,type:"Adhkar",category:"Waking Up & Sleeping",title:"Protection from punishment before sleep (x3)",arabic:"اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ",transliteration:"Allahumma qini 'adhabaka yawma tab'athu 'ibadak",translation:"O Allah, protect me from Your punishment on the Day You resurrect Your servants.",count:3,reference:"Abu Dawud 4/311, Hisnul Muslim No. 37",reward:"The Prophet ﷺ instructed Al-Bara' ibn 'Azib to recite this three times before sleeping. (Abu Dawud 4/311)"),
  HisnulEntry(id:25,type:"Adhkar",category:"Waking Up & Sleeping",title:"Tasbeeh, Tahmid, and Takbir before sleep",arabic:"سُبْحَانَ اللَّهِ — (ثَلاَثاً وَثَلاَثِينَ) — الْحَمْدُ لِلَّهِ — (ثَلاَثاً وَثَلاَثِينَ) — اللَّهُ أَكْبَرُ — (أَرْبَعاً وَثَلاَثِينَ)",transliteration:"SubhanAllah (33) — Alhamdu lillah (33) — Allahu Akbar (34)",translation:"Glory be to Allah — 33 times. All praise is for Allah — 33 times. Allah is the Greatest — 34 times. (Recited before sleeping — better than a servant for this world.)",count:33,reference:"Al-Bukhari 7/71, Hisnul Muslim No. 35",reward:"This is better for you than a servant. (Al-Bukhari 7/71, Muslim 4/2091)"),
  HisnulEntry(id:26,type:"Adhkar",category:"Waking Up & Sleeping",title:"Three surahs before sleep (x3)",arabic:"﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ﴾ وَ ﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ﴾",transliteration:"Qul huwallahu ahad | Qul a'udhu birabbil-falaq | Qul a'udhu birabbin-nas",translation:"Recite Surah Al-Ikhlas, Al-Falaq, and An-Nas three times each before sleeping. Blow into the hands and wipe over the body.",count:3,reference:"Al-Bukhari 7/158, Hisnul Muslim No. 34",reward:"The Prophet ﷺ would recite these into his palms, blow into them, and wipe his entire body — three times. (Al-Bukhari 7/158)"),
  HisnulEntry(id:27,type:"Dua",category:"Waking Up & Sleeping",title:"Ayat al-Kursi before sleeping",arabic:"اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ… (آية الكرسي كاملة)",transliteration:"Allahu la ilaha illa huwal-hayyul-qayyum… (full Ayat al-Kursi)",translation:"Recite the verse of the Throne (Al-Baqarah 2:255) before sleeping. Whoever recites it, a guardian from Allah will protect him and no devil will come near him until morning.",reference:"Al-Bukhari 6/325, Hisnul Muslim No. 33",reward:"A guardian from Allah will protect you and no devil will come near you until morning. (Al-Bukhari 6/325)"),
  HisnulEntry(id:28,type:"Dua",category:"Waking Up & Sleeping",title:"Glorification before sleep",arabic:"سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ، لاَ إِلَهَ إِلاَّ أَنْتَ، أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ",transliteration:"Subhanakallahumma wa bihamdik, la ilaha illa ant, astaghfiruka wa atubu ilayk",translation:"Glory be to You, O Allah, and praise. None has the right to be worshipped except You. I seek Your forgiveness and turn to You in repentance.",reference:"At-Tirmidhi / Al-Bukhari (Adab al-Mufrad), Hisnul Muslim No. 44",reward:"Whoever says this before sleeping, Allah will forgive him. It seals the day on a note of purification. (Al-Bukhari, Adab al-Mufrad, authenticated by Al-Albani)"),
  HisnulEntry(id:29,type:"Dua",category:"Home & Family",title:"Upon entering the home",arabic:"بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا",transliteration:"Bismillahi walajna, wa bismillahi kharajna, wa 'alallahi rabbina tawakkalna",translation:"In the name of Allah we enter, in the name of Allah we leave, and upon our Lord Allah we place our trust.",reference:"Abu Dawud 4/325, Hisnul Muslim No. 24",reward:"When a person enters his home and mentions Allah's name, the devil says to his companions: 'You have no place to stay the night and no supper here.' (Muslim 3/1599)"),
  HisnulEntry(id:30,type:"Dua",category:"Home & Family",title:"Upon leaving the home",arabic:"بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللَّهِ",transliteration:"Bismillah, tawakkaltu 'alallah, wa la hawla wa la quwwata illa billah",translation:"In the name of Allah, I place my trust in Allah, and there is no might nor power except with Allah.",reference:"Abu Dawud 4/325, Hisnul Muslim No. 25",reward:"You will be told: 'You have been guided, defended, and protected.' The devil will step aside. (Abu Dawud 4/325, At-Tirmidhi 5/490)"),
  HisnulEntry(id:31,type:"Dua",category:"Home & Family",title:"Protection of family and children",arabic:"أُعِيذُكُمَا بِكَلِمَاتِ اللَّهِ التَّامَّةِ، مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لاَمَّةٍ",transliteration:"U'idhukuma bikalimatillahit-tammah, min kulli shaytanin wa hammah, wa min kulli 'aynin lammah",translation:"I seek protection for you both in the perfect words of Allah from every devil and every poisonous creature, and from every evil eye.",reference:"Al-Bukhari 4/119, Hisnul Muslim No. 172",reward:"The Prophet ﷺ used to seek Allah's protection for Al-Hasan and Al-Husayn with these very words. (Al-Bukhari 4/119)"),
  HisnulEntry(id:32,type:"Dua",category:"Home & Family",title:"Before marital relations",arabic:"بِسْمِ اللَّهِ، اللَّهُمَّ جَنِّبْنَا الشَّيْطَانَ وَجَنِّبِ الشَّيْطَانَ مَا رَزَقْتَنَا",transliteration:"Bismillah, Allahumma jannibnash-shaytana wa jannibish-shaytana ma razaqtana",translation:"In the name of Allah. O Allah, keep the devil away from us and keep the devil away from what You bestow upon us.",reference:"Al-Bukhari 7/43, Hisnul Muslim No. 205",reward:"If a child is destined to be conceived from that union, Shaytan will never be able to harm that child. (Al-Bukhari 7/43)"),
  HisnulEntry(id:33,type:"Dua",category:"Home & Family",title:"Entering home greeting",arabic:"اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ وَخَيْرَ الْمَخْرَجِ، بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا",transliteration:"Allahumma inni as'aluka khayral-mawlaji wa khayral-makhraj, bismillahi walajna wa bismillahi kharajna wa 'alallahi rabbina tawakkalna",translation:"O Allah, I ask You for the best of entering and the best of leaving. In the name of Allah we enter and in the name of Allah we leave, and upon our Lord Allah we place our trust.",reference:"Abu Dawud 4/325, Hisnul Muslim No. 24",reward:"When a person mentions Allah upon entering, the devil says to his companions: 'There is no lodging for you here tonight.' (Muslim 3/1599)"),
  HisnulEntry(id:34,type:"Dua",category:"Dress & Appearance",title:"Upon wearing new or any clothing",arabic:"الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلاَ قُوَّةٍ",transliteration:"Alhamdu lillahil-ladhi kasani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah",translation:"All praise is for Allah who has clothed me with this garment and provided it for me, with no power or might from myself.",reference:"Abu Dawud 4/41, Hisnul Muslim No. 214",reward:"Whoever wears a new garment and says this dua will be in the care and protection of Allah. (At-Tirmidhi 5/557)"),
  HisnulEntry(id:35,type:"Dua",category:"Dress & Appearance",title:"Congratulating someone on new clothing",arabic:"تُبْلِي وَيُخْلِفُ اللَّهُ تَعَالَى",transliteration:"Tubli wa yukhliful-lahu ta'ala",translation:"May you wear it out and may Allah replace it (with something better).",reference:"Abu Dawud 4/41, Hisnul Muslim No. 216",reward:"This is the exact Sunnah expression of congratulation for new clothing. (Abu Dawud, authenticated by Al-Albani)"),
  HisnulEntry(id:36,type:"Dua",category:"Dress & Appearance",title:"Asking good from a new garment",arabic:"اللَّهُمَّ لَكَ الْحَمْدُ أَنْتَ كَسَوْتَنِيهِ، أَسْأَلُكَ مِنْ خَيْرِهِ وَخَيْرِ مَا صُنِعَ لَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّهِ وَشَرِّ مَا صُنِعَ لَهُ",transliteration:"Allahumma lakal-hamdu anta kasawtanihi, as'aluka min khayrihi wa khayri ma suni'a lah, wa a'udhu bika min sharrihi wa sharri ma suni'a lah",translation:"O Allah, all praise is for You. You have clothed me with this garment. I ask You for the good of it and the good of what it was made for, and I seek refuge in You from the evil of it and the evil of what it was made for.",reference:"Abu Dawud 4/41, Hisnul Muslim No. 215",reward:"Combines hamd (praise), tawakkul (reliance), and isti'adhah (seeking refuge) in one breath. (Abu Dawud, authenticated by Al-Albani)"),
  HisnulEntry(id:37,type:"Dua",category:"Dress & Appearance",title:"Dua when looking in the mirror",arabic:"اللَّهُمَّ أَنْتَ حَسَّنْتَ خَلْقِي فَحَسِّنْ خُلُقِي",transliteration:"Allahumma anta hassanta khalqi fahassin khuluqi",translation:"O Allah, just as You have made my external features beautiful, make my character beautiful as well.",reference:"Ahmad 1/403, Hisnul Muslim No. 213",reward:"The Prophet ﷺ would say this when looking in the mirror. (Ahmad 1/403, authenticated by Al-Albani)"),
  HisnulEntry(id:38,type:"Dua",category:"Toilet & Cleanliness",title:"Before entering the toilet",arabic:"بِسْمِ اللَّهِ، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ",transliteration:"Bismillah, Allahumma inni a'udhu bika minal-khubuthi wal-khaba'ith",translation:"In the name of Allah. O Allah, I seek refuge in You from male and female evil spirits (jinn).",reference:"Al-Bukhari 1/45, Hisnul Muslim No. 6",reward:"Saying Bismillah before entering creates a veil between the jinn and the private parts. (Ibn Majah 1/109)"),
  HisnulEntry(id:39,type:"Dua",category:"Toilet & Cleanliness",title:"Upon exiting the toilet",arabic:"غُفْرَانَكَ",transliteration:"Ghufranaka",translation:"I seek Your forgiveness.",reference:"Abu Dawud 1/4, Hisnul Muslim No. 7",reward:"Aisha (ra) said the Prophet ﷺ used to say 'Ghufranaka' upon leaving the toilet. (Abu Dawud 1/4, At-Tirmidhi 1/8)"),
  HisnulEntry(id:40,type:"Dua",category:"Toilet & Cleanliness",title:"Before performing wudu",arabic:"بِسْمِ اللَّهِ",transliteration:"Bismillah",translation:"In the name of Allah.",reference:"Abu Dawud 1/23, Hisnul Muslim No. 8",reward:"The Prophet ﷺ said: 'There is no wudu for one who does not mention the name of Allah over it.' (Abu Dawud 1/23, Ibn Majah 1/140)"),
  HisnulEntry(id:41,type:"Dua",category:"Food & Drink",title:"Before eating",arabic:"بِسْمِ اللَّهِ",transliteration:"Bismillah",translation:"In the name of Allah.",reference:"Abu Dawud 3/347, Hisnul Muslim No. 193",reward:"Saying Bismillah before eating keeps Shaytan away from your food and your home. (Muslim 3/1599)"),
  HisnulEntry(id:42,type:"Dua",category:"Food & Drink",title:"When forgetting to say Bismillah at the start",arabic:"بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ",transliteration:"Bismillahi awwalahu wa akhirah",translation:"In the name of Allah, at its beginning and at its end.",reference:"Abu Dawud 3/347, Hisnul Muslim No. 194",reward:"Saying this causes Shaytan to vomit out all that he had eaten of your food. (Abu Dawud 3/347)"),
  HisnulEntry(id:43,type:"Dua",category:"Food & Drink",title:"After eating",arabic:"الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلاَ قُوَّةٍ",transliteration:"Alhamdu lillahil-ladhi at'amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah",translation:"All praise is for Allah who fed me this and provided it for me, without any power or might from myself.",reference:"Abu Dawud 4/41, Hisnul Muslim No. 196",reward:"Whoever eats food and says this, his past sins will be forgiven. (At-Tirmidhi 5/507)"),
  HisnulEntry(id:44,type:"Dua",category:"Food & Drink",title:"When breaking the fast",arabic:"ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الأَجْرُ إِنْ شَاءَ اللَّهُ",transliteration:"Dhahabaz-zama'u wabtallatil-'uruqu wa thaabatal-ajru insha'allah",translation:"The thirst is gone, the veins are moistened, and the reward is confirmed, if Allah wills.",reference:"Abu Dawud 2/306, Hisnul Muslim No. 202",reward:"The fasting person has a supplication at the time of breaking his fast that is not rejected. (Ibn Majah 1/557)"),
  HisnulEntry(id:45,type:"Dua",category:"Food & Drink",title:"Supplication for the host who feeds you",arabic:"اللَّهُمَّ اغْفِرْ لَهُمْ وَارْحَمْهُمْ وَبَارِكْ لَهُمْ فِيمَا رَزَقْتَهُمْ",transliteration:"Allahummaghfir lahum warhamhum wa barik lahum fima razaqtahum",translation:"O Allah, forgive them, have mercy on them, and bless them in what You have provided them.",reference:"Muslim 3/1615, Hisnul Muslim No. 204",reward:"The Prophet ﷺ would make this dua for the host. (Muslim 3/1615)"),
  HisnulEntry(id:46,type:"Dua",category:"Mosque & Prayer",title:"Upon entering the mosque",arabic:"أَعُوذُ بِاللَّهِ الْعَظِيمِ وَبِوَجْهِهِ الْكَرِيمِ وَسُلْطَانِهِ الْقَدِيمِ مِنَ الشَّيْطَانِ الرَّجِيمِ. بِسْمِ اللَّهِ وَالصَّلاَةُ وَالسَّلاَمُ عَلَى رَسُولِ اللَّهِ، اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ",transliteration:"A'udhu billahil-'azim wa biwajhihil-karim wa sultanihil-qadim minash-shaytanir-rajim. Bismillahi was-salatu was-salamu 'ala rasulillah, Allahummaftah li abwaba rahmatik",translation:"I seek refuge in Allah the Magnificent, by His noble face and His eternal authority, from the accursed devil. In the name of Allah, and prayers and peace be upon the Messenger of Allah. O Allah, open the gates of Your mercy for me.",reference:"Abu Dawud 1/126, Hisnul Muslim No. 47",reward:"Shaytan will say: 'He is protected from me all day.' (Abu Dawud 1/126)"),
  HisnulEntry(id:47,type:"Dua",category:"Mosque & Prayer",title:"Upon leaving the mosque",arabic:"بِسْمِ اللَّهِ وَالصَّلاَةُ وَالسَّلاَمُ عَلَى رَسُولِ اللَّهِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ",transliteration:"Bismillahi was-salatu was-salamu 'ala rasulillah, Allahumma inni as'aluka min fadlik",translation:"In the name of Allah, and prayers and peace be upon the Messenger of Allah. O Allah, I ask You from Your bounty.",reference:"Muslim 1/494, Hisnul Muslim No. 48",reward:"Whoever says this, Allah will grant him from His bounty. (Muslim 1/494)"),
  HisnulEntry(id:48,type:"Dua",category:"Mosque & Prayer",title:"After hearing the adhan",arabic:"اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ وَالصَّلاَةِ الْقَائِمَةِ، آتِ مُحَمَّداً الْوَسِيلَةَ وَالْفَضِيلَةَ وَابْعَثْهُ مَقَاماً مَحْمُوداً الَّذِي وَعَدْتَهُ",transliteration:"Allahumma rabba hadhihid-da'watit-tammati was-salatil-qa'imah, ati Muhammadanil-wasilata wal-fadilah, wab'athu maqamam-mahmudan alladhi wa'adtah",translation:"O Allah, Lord of this perfect call and established prayer, grant Muhammad the privilege of intercession and excellence, and raise him to the praiseworthy station You have promised him.",reference:"Al-Bukhari 1/152, Hisnul Muslim No. 18",reward:"Whoever says this after the adhan will be granted the Prophet's ﷺ intercession on the Day of Resurrection. (Al-Bukhari 1/152)"),
  HisnulEntry(id:49,type:"Dua",category:"Mosque & Prayer",title:"Opening supplication of prayer (Istiftah)",arabic:"سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ، وَتَبَارَكَ اسْمُكَ، وَتَعَالَى جَدُّكَ، وَلاَ إِلَهَ غَيْرُكَ",transliteration:"Subhanakallahumma wa bihamdik, wa tabarakasmuk, wa ta'ala jadduk, wa la ilaha ghayruk",translation:"Glory be to You, O Allah, and praise. Blessed is Your name, exalted is Your majesty, and none has the right to be worshipped except You.",reference:"Abu Dawud 1/124, Hisnul Muslim No. 14",reward:"Umar ibn al-Khattab (ra) used to recite this istiftah aloud so the companions could learn it. (Abu Dawud 1/124)"),
  HisnulEntry(id:50,type:"Adhkar",category:"Mosque & Prayer",title:"Tasbeeh in ruku (x3)",arabic:"سُبْحَانَ رَبِّيَ الْعَظِيمِ",transliteration:"Subhana rabbiyal-'azim",translation:"Glory be to my Lord, the Most Great.",count:3,reference:"Abu Dawud 1/130, Hisnul Muslim No. 15",reward:"The Prophet ﷺ commanded this glorification in ruku'. (Muslim 1/348)"),
  HisnulEntry(id:51,type:"Adhkar",category:"Mosque & Prayer",title:"Tasbeeh in sujud (x3)",arabic:"سُبْحَانَ رَبِّيَ الأَعْلَى",transliteration:"Subhana rabbiyal-a'la",translation:"Glory be to my Lord, the Most High.",count:3,reference:"Abu Dawud 1/134, Hisnul Muslim No. 17",reward:"The closest a servant comes to his Lord is when he is in prostration. (Muslim 1/350)"),
  HisnulEntry(id:52,type:"Dua",category:"Mosque & Prayer",title:"The Tashahud",arabic:"التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلاَمُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلاَمُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّداً عَبْدُهُ وَرَسُولُهُ",transliteration:"At-tahiyyatu lillahi was-salawatu wat-tayyibat, as-salamu 'alayka ayyuhan-nabiyyu wa rahmatullahi wa barakatuh, as-salamu 'alayna wa 'ala 'ibadillahis-salihin, ashhadu an la ilaha illallahu wa ashhadu anna Muhammadan 'abduhu wa rasuluh",translation:"All greetings, prayers and pure words are for Allah. Peace be upon you, O Prophet, and the mercy of Allah and His blessings. Peace be upon us and upon the righteous servants of Allah. I bear witness that none has the right to be worshipped except Allah, and I bear witness that Muhammad is His slave and messenger.",reference:"Al-Bukhari 1/202, Hisnul Muslim No. 21",reward:"Completing the Tashahud correctly earns the intercession of the Prophet ﷺ. (Al-Bukhari 1/202, Muslim 1/301)"),
  HisnulEntry(id:53,type:"Dua",category:"Traveling & Moving",title:"Upon riding a vehicle or starting a journey",arabic:"سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ. اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ",transliteration:"Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun. Allahumma inna nas'aluka fi safarina hadhal-birra wat-taqwa, wa minal-'amali ma tarda, Allahumma hawwin 'alayna safarana hadha watwi 'anna bu'dah",translation:"Glory be to Him who has subjected this to us, and we were not capable of that. And indeed, to our Lord we are returning. O Allah, we ask You during this journey for righteousness, piety, and deeds that please You. O Allah, ease this journey and shorten its distance.",reference:"Muslim 2/978, Hisnul Muslim No. 233",reward:"The one who recites it is placed under Allah's direct guardianship for the entire journey. (Muslim 2/978)"),
  HisnulEntry(id:54,type:"Dua",category:"Traveling & Moving",title:"Returning from a journey",arabic:"آيِبُونَ، تَائِبُونَ، عَابِدُونَ، لِرَبِّنَا حَامِدُونَ",transliteration:"Ayibun, ta'ibun, 'abidun, lirabbina hamidun",translation:"Returning, repenting, worshipping, and praising our Lord.",reference:"Muslim 2/980, Hisnul Muslim No. 236",reward:"The Prophet ﷺ would say this upon returning from every journey. (Muslim 2/980)"),
  HisnulEntry(id:55,type:"Dua",category:"Traveling & Moving",title:"Upon entering a new town or city",arabic:"اللَّهُمَّ رَبَّ السَّمَوَاتِ السَّبْعِ وَمَا أَظْلَلْنَ، وَرَبَّ الأَرَضِينَ السَّبْعِ وَمَا أَقْلَلْنَ، وَرَبَّ الشَّيَاطِينِ وَمَا أَضْلَلْنَ، وَرَبَّ الرِّيَاحِ وَمَا ذَرَيْنَ، أَسْأَلُكَ خَيْرَ هَذِهِ الْقَرْيَةِ وَخَيْرَ أَهْلِهَا وَخَيْرَ مَا فِيهَا، وَأَعُوذُ بِكَ مِنْ شَرِّهَا وَشَرِّ أَهْلِهَا وَشَرِّ مَا فِيهَا",transliteration:"Allahumma rabbas-samawatis-sab'i wa ma azlalna, wa rabbal-aradinas-sab'i wa ma aqallna, wa rabbash-shayatini wa ma adlalna, wa rabbar-riyahi wa ma dharayna, as'aluka khayra hadhihil-qaryati wa khayra ahliha wa khayra ma fiha, wa a'udhu bika min sharriha wa sharri ahliha wa sharri ma fiha",translation:"O Allah, Lord of the seven heavens and all they shade, Lord of the seven earths and all they carry, Lord of the devils and those they mislead, Lord of the winds and what they scatter — I ask You for the good of this town and the good of its people and the good within it, and I seek refuge in You from its evil, the evil of its people, and the evil within it.",reference:"Ibn As-Sunni / Hakim, Hisnul Muslim No. 239",reward:"Whoever recites it enters under Allah's guardianship. (Hakim, authenticated by Al-Albani)"),
  HisnulEntry(id:56,type:"Dua",category:"Traveling & Moving",title:"When stopping at a place during travel",arabic:"أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",transliteration:"A'udhu bikalimatillahit-tammati min sharri ma khalaq",translation:"I seek refuge in the perfect words of Allah from the evil of what He has created.",reference:"Muslim 4/2080, Hisnul Muslim No. 237",reward:"Nothing will harm him until he leaves that place. (Muslim 4/2080)"),
  HisnulEntry(id:57,type:"Dua",category:"Traveling & Moving",title:"Dua for protection during travel at night",arabic:"أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ الَّتِي لاَ يُجَاوِزُهُنَّ بَرٌّ وَلاَ فَاجِرٌ مِنْ شَرِّ مَا خَلَقَ وَذَرَأَ وَبَرَأَ، وَمِنْ شَرِّ مَا يَنْزِلُ مِنَ السَّمَاءِ وَمِنْ شَرِّ مَا يَعْرُجُ فِيهَا",transliteration:"A'udhu bikalimatillahit-tammatin allati la yujawizuhunna barrun wa la fajir, min sharri ma khalaqa wa dhara'a wa bara'a, wa min sharri ma yanzilu minas-sama'i wa min sharri ma ya'ruju fiha",translation:"I seek refuge in the perfect words of Allah, which no righteous or wicked person can transgress, from the evil of what He has created, engendered, and originated; and from the evil of what descends from the heavens and what ascends to them.",reference:"Ahmad 3/419, Hisnul Muslim No. 241",reward:"A complete shield that no righteous or wicked person can penetrate. (Ahmad 3/419)"),
  HisnulEntry(id:58,type:"Dua",category:"Traveling & Moving",title:"Protection from being led astray",arabic:"اللَّهُمَّ إِنِّي أَعُوذُ بِكَ أَنْ أَضِلَّ أَوْ أُضَلَّ، أَوْ أَزِلَّ أَوْ أُزَلَّ، أَوْ أَظْلِمَ أَوْ أُظْلَمَ، أَوْ أَجْهَلَ أَوْ يُجْهَلَ عَلَيَّ",transliteration:"Allahumma inni a'udhu bika an adilla aw udall, aw azilla aw uzall, aw azlima aw uzlam, aw ajhala aw yujhala 'alayy",translation:"O Allah, I seek refuge in You from going astray or being led astray, from slipping or being caused to slip, from wronging others or being wronged, from being ignorant or having others be ignorant toward me.",reference:"Abu Dawud 4/325, Hisnul Muslim No. 234",reward:"Covers six pairs of potential harm — one of the most comprehensive travel protections. (Abu Dawud)"),
  HisnulEntry(id:59,type:"Dua",category:"Hardship & Anxiety",title:"Protection from anxiety and grief",arabic:"اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ",transliteration:"Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabaatir-rijal",translation:"O Allah, I seek refuge in You from worry and grief, from weakness and laziness, from miserliness and cowardice, from the burden of debts and from being overpowered by men.",reference:"Al-Bukhari 7/158, Hisnul Muslim No. 120",reward:"The Prophet ﷺ used to regularly seek refuge from these eight destructive traits. (Al-Bukhari 7/158)"),
  HisnulEntry(id:60,type:"Dua",category:"Hardship & Anxiety",title:"Dua of Yunus (as) in distress",arabic:"لاَ إِلَهَ إِلاَّ أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",transliteration:"La ilaha illa anta subhanaka inni kuntu minaz-zalimin",translation:"None has the right to be worshipped except You. Glory be to You. Verily, I have been of the wrongdoers.",reference:"At-Tirmidhi 5/529, Hisnul Muslim No. 121",reward:"No Muslim ever supplicates using these words except that Allah responds to his supplication. (At-Tirmidhi 5/529)"),
  HisnulEntry(id:61,type:"Dua",category:"Hardship & Anxiety",title:"Dua when afflicted by calamity",arabic:"إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ، اللَّهُمَّ أْجُرْنِي فِي مُصِيبَتِي وَأَخْلِفْ لِي خَيْراً مِنْهَا",transliteration:"Inna lillahi wa inna ilayhi raji'un, Allahumma ajurni fi musibati wa akhlif li khayran minha",translation:"Verily, to Allah we belong and unto Him is our return. O Allah, recompense me for my affliction and replace it for me with something better.",reference:"Muslim 2/632, Hisnul Muslim No. 123",reward:"Allah will indeed replace it with something better. (Muslim 2/632)"),
  HisnulEntry(id:62,type:"Dua",category:"Hardship & Anxiety",title:"Reliance on Allah when overwhelmed",arabic:"حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",transliteration:"Hasbunallahu wa ni'mal-wakil",translation:"Allah is sufficient for us and He is the best Disposer of affairs.",reference:"Al-Bukhari 5/172, Hisnul Muslim No. 122",reward:"Ibrahim (as) said this when thrown into the fire — and Allah made it cool and safe. (Al-Bukhari 5/172)"),
  HisnulEntry(id:63,type:"Dua",category:"Hardship & Anxiety",title:"Comprehensive dua for removing sadness",arabic:"اللَّهُمَّ إِنِّي عَبْدُكَ، وَابْنُ عَبْدِكَ، وَابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ سَمَّيْتَ بِهِ نَفْسَكَ، أَوْ أَنْزَلْتَهُ فِي كِتَابِكَ، أَوْ عَلَّمْتَهُ أَحَداً مِنْ خَلْقِكَ، أَوِ اسْتَأْثَرْتَ بِهِ فِي عِلْمِ الْغَيْبِ عِنْدَكَ، أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي، وَنُورَ صَدْرِي، وَجَلاَءَ حُزْنِي، وَذَهَابَ هَمِّي",transliteration:"Allahumma inni 'abduka, wabnu 'abdika, wabnu amatik, nasiyati biyadik, madin fiyya hukmuk, 'adlun fiyya qada'uk, as'aluka bikulli ismin huwa lak, sammayta bihi nafsak, aw anzaltahu fi kitabik, aw 'allamtahu ahadan min khalqik, awista'tharta bihi fi 'ilmil-ghaybi 'indak, an taj'alal-Qur'ana rabi'a qalbi, wa nura sadri, wa jala'a huzni, wa dhahaba hammi",translation:"O Allah, I am Your slave, the son of Your slave, the son of Your female slave. My forelock is in Your hand, Your decree has been executed upon me, Your judgment of me is just. I ask You by every name You have — to make the Quran the spring of my heart, the light of my chest, the remover of my grief, and the reliever of my anxiety.",reference:"Ahmad 1/391, Hisnul Muslim No. 120",reward:"Allah will remove his grief and anxiety, and replace his sorrow with joy. (Ahmad 1/391)"),
  HisnulEntry(id:64,type:"Dua",category:"Hardship & Anxiety",title:"Dua when facing a difficult matter",arabic:"لاَ إِلَهَ إِلاَّ اللَّهُ الْعَظِيمُ الْحَلِيمُ، لاَ إِلَهَ إِلاَّ اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لاَ إِلَهَ إِلاَّ اللَّهُ رَبُّ السَّمَوَاتِ وَرَبُّ الأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ",transliteration:"La ilaha illallahul-'azimul-halim, la ilaha illallahu rabbul-'arshil-'azim, la ilaha illallahu rabbus-samawati wa rabbul-ardi wa rabbul-'arshil-karim",translation:"None has the right to be worshipped except Allah, the Magnificent, the Forbearing. None has the right to be worshipped except Allah, Lord of the Magnificent Throne. None has the right to be worshipped except Allah, Lord of the heavens, Lord of the earth, and Lord of the Generous Throne.",reference:"Al-Bukhari 7/154, Hisnul Muslim No. 119",reward:"The supplication of the Prophets in their greatest moments of hardship. (Al-Bukhari 8/140)"),
  HisnulEntry(id:65,type:"Dua",category:"Illness & Death",title:"Ruqyah – seeking cure from Allah",arabic:"اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِهِ وَأَنْتَ الشَّافِي، لاَ شِفَاءَ إِلاَّ شِفَاؤُكَ، شِفَاءً لاَ يُغَادِرُ سَقَماً",transliteration:"Allahumma rabban-nas, adhhibil-ba's, ishfihi wa antas-shafi, la shifa'a illa shifa'uk, shifa'an la yughadiru saqama",translation:"O Allah, Lord of mankind, remove the affliction and cure him, for You are the Healer. There is no cure except Your cure — a cure that leaves no disease behind.",reference:"Al-Bukhari 7/172, Hisnul Muslim No. 176",reward:"The Prophet ﷺ used to recite this for the ill, wiping them with his right hand. (Al-Bukhari 7/172)"),
  HisnulEntry(id:66,type:"Adhkar",category:"Illness & Death",title:"Ruqyah using Allah's name and refuge from pain (x7)",arabic:"بِسْمِ اللَّهِ — (ثَلاَثاً) — أَعُوذُ بِعِزَّةِ اللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ — (سَبْعاً)",transliteration:"Bismillah — (3 times) — A'udhu bi'izzatillahi wa qudratihi min sharri ma ajidu wa uhadhir — (7 times)",translation:"In the name of Allah — three times. I seek refuge in the might of Allah and His power from the evil of what I feel and I am wary of — seven times.",count:7,reference:"Muslim 4/1728, Hisnul Muslim No. 179",reward:"The pain will depart by the permission of Allah. (Muslim 4/1728)"),
  HisnulEntry(id:67,type:"Dua",category:"Illness & Death",title:"Visiting the sick",arabic:"لاَ بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ",transliteration:"La ba'sa tahurun insha'allah",translation:"Do not worry, this is a purification (of sins), if Allah wills.",reference:"Al-Bukhari 7/122, Hisnul Muslim No. 175",reward:"Illness expiates sins. (Al-Bukhari 7/122, Muslim 4/1992)"),
  HisnulEntry(id:68,type:"Dua",category:"Illness & Death",title:"Ruqyah by Jibril (as)",arabic:"بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ",transliteration:"Bismillahi arqik, min kulli shay'in yu'dhik, min sharri kulli nafsin aw 'ayni hasidin, Allahu yashfik, bismillahi arqik",translation:"In the name of Allah I perform ruqyah for you, from everything that harms you, from the evil of every soul or envious eye. May Allah cure you. In the name of Allah I perform ruqyah for you.",reference:"Muslim 4/1718, Hisnul Muslim No. 178",reward:"Jibril (as) performed this ruqyah on the Prophet ﷺ himself. (Muslim 4/1718)"),
  HisnulEntry(id:69,type:"Dua",category:"Illness & Death",title:"Supplication for the deceased in funeral prayer",arabic:"اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ، وَعَافِهِ وَاعْفُ عَنْهُ، وَأَكْرِمْ نُزُلَهُ وَوَسِّعْ مُدْخَلَهُ، وَاغْسِلْهُ بِالْمَاءِ وَالثَّلْجِ وَالْبَرَدِ، وَنَقِّهِ مِنَ الْخَطَايَا كَمَا نَقَّيْتَ الثَّوْبَ الأَبْيَضَ مِنَ الدَّنَسِ",transliteration:"Allahummaghfir lahu warhamhu, wa 'afihi wa'fu 'anhu, wa akrim nuzulahu wa wassi' mudkhalah, waghsilhu bil-ma'i wathalji wal-barad, wa naqqihi minal-khataaya kama naqqaytat-thawbal-abyada minad-danas",translation:"O Allah, forgive him and have mercy on him. Pardon him and grant him security. Honor his place of rest and widen his entrance. Wash him with water, snow and hail, and purify him of sins as a white garment is purified of filth.",reference:"Muslim 1/477, Hisnul Muslim No. 156",reward:"The one who performs janazah prayer sincerely earns a mountain-sized reward. (Al-Bukhari 2/88)"),
  HisnulEntry(id:70,type:"Dua",category:"Illness & Death",title:"Closing the eyes of the deceased",arabic:"اللَّهُمَّ اغْفِرْ لِ(فُلاَنٍ) وَارْفَعْ دَرَجَتَهُ فِي الْمَهْدِيِّينَ، وَاخْلُفْهُ فِي عَقِبِهِ فِي الْغَابِرِينَ، وَاغْفِرْ لَنَا وَلَهُ يَا رَبَّ الْعَالَمِينَ، وَافْسَحْ لَهُ فِي قَبْرِهِ وَنَوِّرْ لَهُ فِيهِ",transliteration:"Allahummaghfir li (fulan) warfa' darajatahu fil-mahdiyyin, wakhlufhu fi 'aqibihi fil-ghabirin, waghfir lana wa lahu ya rabbal-'alamin, wafsah lahu fi qabrihi wa nawwir lahu fih",translation:"O Allah, forgive [name] and raise his rank among those who are rightly guided. Be his successor among those who survive him. Forgive us and him, O Lord of the worlds. Open up his grave for him and lighten it.",reference:"Muslim 2/634, Hisnul Muslim No. 157",reward:"The angels say Ameen to whatever the family says. (Muslim 2/634)"),
  HisnulEntry(id:71,type:"Dua",category:"Social Interactions",title:"Islamic greeting",arabic:"السَّلاَمُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ",transliteration:"As-salamu 'alaykum wa rahmatullahi wa barakatuh",translation:"Peace be upon you, and the mercy of Allah and His blessings.",reference:"Abu Dawud 4/350, Hisnul Muslim No. 171",reward:"The full greeting earns 30 good deeds. (Abu Dawud 4/350, At-Tirmidhi 5/49)"),
  HisnulEntry(id:72,type:"Dua",category:"Social Interactions",title:"Response to the Islamic greeting",arabic:"وَعَلَيْكُمُ السَّلاَمُ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ",transliteration:"Wa 'alaykumus-salamu wa rahmatullahi wa barakatuh",translation:"And peace be upon you too, and the mercy of Allah and His blessings.",reference:"Abu Dawud 4/350, Hisnul Muslim No. 172",reward:"The one who returns the full greeting earns the same 30 good deeds. (Muslim 1/74)"),
  HisnulEntry(id:73,type:"Dua",category:"Social Interactions",title:"When sneezing",arabic:"الْحَمْدُ لِلَّهِ",transliteration:"Alhamdu lillah",translation:"All praise is for Allah. (Those who hear respond: Yarhamukallah — May Allah have mercy on you.)",reference:"Al-Bukhari 7/125, Hisnul Muslim No. 242",reward:"Allah loves sneezing. When you praise Allah, it becomes obligatory to say Yarhamukallah. (Al-Bukhari 7/125)"),
  HisnulEntry(id:74,type:"Dua",category:"Social Interactions",title:"When becoming angry",arabic:"أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ",transliteration:"A'udhu billahi minash-shaytanir-rajim",translation:"I seek refuge in Allah from the accursed devil.",reference:"Al-Bukhari 4/119, Hisnul Muslim No. 247",reward:"When a man becomes angry and says this, his anger will subside. (Abu Dawud 4/249)"),
  HisnulEntry(id:75,type:"Dua",category:"Social Interactions",title:"Thanking someone for a kindness",arabic:"جَزَاكَ اللَّهُ خَيْراً",transliteration:"Jazakallaahu khayra",translation:"May Allah reward you with good.",reference:"At-Tirmidhi 4/380, Hisnul Muslim No. 251",reward:"This dua is the best form of repayment. (Abu Dawud 2/142)"),
  HisnulEntry(id:76,type:"Dua",category:"Social Interactions",title:"Responding to good news",arabic:"بَارَكَ اللَّهُ فِيكَ",transliteration:"Barakallahu fik",translation:"May Allah bless you.",reference:"At-Tirmidhi, Hisnul Muslim No. 252",reward:"Barakallahu fik brings divine blessing upon the receiver. (At-Tirmidhi 4/380)"),
  HisnulEntry(id:77,type:"Dua",category:"Social Interactions",title:"Response to congratulations",arabic:"بَارَكَ اللَّهُ لَكَ وَبَارَكَ عَلَيْكَ وَجَمَعَ بَيْنَكُمَا فِي خَيْرٍ",transliteration:"Barakallahu laka wa baraka 'alayka wa jama'a baynakuma fi khayr",translation:"May Allah bless you and send blessings upon you, and may He bring you together in goodness.",reference:"Abu Dawud 2/228, Hisnul Muslim No. 206",reward:"The exact wording the Prophet ﷺ used to congratulate newlyweds. (Abu Dawud 2/228)"),
  HisnulEntry(id:78,type:"Dua",category:"Knowledge & Protection",title:"Protection from harmful knowledge",arabic:"اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عِلْمٍ لاَ يَنْفَعُ، وَمِنْ قَلْبٍ لاَ يَخْشَعُ، وَمِنْ نَفْسٍ لاَ تَشْبَعُ، وَمِنْ دَعْوَةٍ لاَ يُسْتَجَابُ لَهَا",transliteration:"Allahumma inni a'udhu bika min 'ilmin la yanfa', wa min qalbin la yakhsha', wa min nafsin la tashba', wa min da'watin la yustajabullaha",translation:"O Allah, I seek refuge in You from knowledge that brings no benefit, from a heart that does not fear, from a soul that is never satisfied, and from a supplication that is not answered.",reference:"Muslim 4/2088, Hisnul Muslim No. 131",reward:"A comprehensive shield against four spiritual diseases. (Muslim 4/2088)"),
  HisnulEntry(id:79,type:"Dua",category:"Knowledge & Protection",title:"Asking for beneficial knowledge and pure sustenance",arabic:"اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْماً نَافِعاً، وَرِزْقاً طَيِّباً، وَعَمَلاً مُتَقَبَّلاً",transliteration:"Allahumma inni as'aluka 'ilman nafi'a, wa rizqan tayyiba, wa 'amalan mutaqabbala",translation:"O Allah, I ask You for knowledge that is beneficial, sustenance that is good, and deeds that are accepted.",reference:"Ibn Majah 1/152, Hisnul Muslim No. 50",reward:"The Prophet ﷺ recited this after the Fajr prayer. (Ibn Majah 1/152)"),
  HisnulEntry(id:80,type:"Dua",category:"Knowledge & Protection",title:"Protection from the evil eye",arabic:"أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لاَمَّةٍ",transliteration:"A'udhu bikalimatillahit-tammati min kulli shaytanin wa hammah, wa min kulli 'aynin lammah",translation:"I seek refuge in the perfect words of Allah from every devil and every poisonous creature, and from every evil eye.",reference:"Al-Bukhari 4/119, Hisnul Muslim No. 172",reward:"A complete shield against Shaytan, poisonous creatures, and the evil eye. (Al-Bukhari 4/119)"),
  HisnulEntry(id:81,type:"Dua",category:"Knowledge & Protection",title:"Morning supplication for protection of the day",arabic:"اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ",transliteration:"Allahumma bika asbahna wa bika amsayna wa bika nahya wa bika namutu wa ilaykal-masir",translation:"O Allah, by You we have entered the morning and by You we have entered the evening, by You we live and by You we die, and to You is our return.",reference:"At-Tirmidhi 5/466, Hisnul Muslim No. 75",reward:"The highest form of reliance — Allah will suffice him in every matter. (At-Tirmidhi 5/466, Quran 65:3)"),
  HisnulEntry(id:82,type:"Dua",category:"Knowledge & Protection",title:"Seeking refuge from the punishment of the grave",arabic:"اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، وَمِنْ عَذَابِ جَهَنَّمَ، وَمِنْ فِتْنَةِ الْمَحْيَا وَالْمَمَاتِ، وَمِنْ شَرِّ فِتْنَةِ الْمَسِيحِ الدَّجَّالِ",transliteration:"Allahumma inni a'udhu bika min 'adhabul-qabr, wa min 'adhabi jahannam, wa min fitnatil-mahya wal-mamat, wa min sharri fitnatil-masihid-dajjal",translation:"O Allah, I seek refuge in You from the punishment of the grave, from the punishment of Hellfire, from the trials of living and dying, and from the evil of the fitnah of the False Messiah.",reference:"Al-Bukhari 2/102, Hisnul Muslim No. 19",reward:"The Prophet ﷺ commanded seeking refuge from these four trials in every prayer. (Al-Bukhari 2/102, Muslim 1/412)"),
  HisnulEntry(id:83,type:"Adhkar",category:"General Praise & Repentance",title:"Glorification with praise (x100)",arabic:"سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",transliteration:"SubhanAllahi wa bihamdih",translation:"Glory be to Allah and praise be to Him. (Whoever says this 100 times will not be surpassed in reward except by one who said it more.)",count:100,reference:"Muslim 4/2071, Hisnul Muslim No. 71",reward:"Whoever says this 100 times a day, his sins will be forgiven even if they are like the foam of the sea. (Al-Bukhari 7/168, Muslim 4/2071)"),
  HisnulEntry(id:84,type:"Adhkar",category:"General Praise & Repentance",title:"The two phrases beloved to the Most Merciful",arabic:"سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ",transliteration:"SubhanAllahi wa bihamdih, SubhanAllahil-'azim",translation:"Glory be to Allah and praise be to Him. Glory be to Allah, the Most Great. (Light on the tongue, heavy in the scale, beloved to the Most Merciful.)",count:1,reference:"Al-Bukhari 7/168, Hisnul Muslim No. 72",reward:"Light on the tongue, heavy in the scale, and beloved to the Most Merciful. (Al-Bukhari 7/168, Muslim 4/2072)"),
  HisnulEntry(id:85,type:"Adhkar",category:"General Praise & Repentance",title:"Tahlil – best of dhikr (x100)",arabic:"لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",transliteration:"La ilaha illallahu wahdahu la sharika lah, lahul mulku walahul hamdu wahuwa 'ala kulli shay'in qadir",translation:"None has the right to be worshipped except Allah, alone, without partner. To Him belongs all sovereignty and praise and He is over all things omnipotent. (100 times a day.)",count:100,reference:"Al-Bukhari 4/95, Hisnul Muslim No. 66",reward:"Equivalent to freeing 10 slaves, 100 good deeds written, 100 sins erased, and protection from Shaytan for the day. (Al-Bukhari 4/95, Muslim 4/2071)"),
  HisnulEntry(id:86,type:"Adhkar",category:"General Praise & Repentance",title:"Complete glorification phrase",arabic:"سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلاَ إِلَهَ إِلاَّ اللَّهُ، وَاللَّهُ أَكْبَرُ",transliteration:"SubhanAllah, walhamdu lillah, wa la ilaha illallah, wallahu akbar",translation:"Glory be to Allah. All praise is for Allah. None has the right to be worshipped except Allah. Allah is the Greatest.",count:1,reference:"Muslim 4/2072, Hisnul Muslim No. 73",reward:"The most beloved words to Allah are four. Each fills the scale on the Day of Judgement. (Muslim 4/2072)"),
  HisnulEntry(id:87,type:"Dua",category:"General Praise & Repentance",title:"Seeking forgiveness and acceptance of repentance",arabic:"اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي",transliteration:"Allahumma innaka 'afuwwun tuhibbul-'afwa fa'fu 'anni",translation:"O Allah, You are Most Forgiving, You love forgiveness, so forgive me.",reference:"At-Tirmidhi 3/153, Hisnul Muslim No. 206",reward:"The best supplication for Laylatul Qadr — equivalent to the worship of 1000 months. (At-Tirmidhi 3/153)"),
  HisnulEntry(id:88,type:"Dua",category:"General Praise & Repentance",title:"Comprehensive dua for this world and the hereafter",arabic:"رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",transliteration:"Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina 'adhaaban-nar",translation:"Our Lord, give us good in this world and good in the hereafter, and save us from the punishment of the Fire.",reference:"Al-Bukhari 8/167, Hisnul Muslim No. 128",reward:"The Prophet ﷺ recited this dua more than any other. (Al-Bukhari 8/167, Muslim 4/2070)"),
  HisnulEntry(id:89,type:"Adhkar",category:"General Praise & Repentance",title:"Istighfar – seeking forgiveness throughout the day",arabic:"أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ",transliteration:"Astaghfirullahul-'azimal-ladhi la ilaha illa huwal-hayyul-qayyumu wa atubu ilayh",translation:"I seek the forgiveness of Allah the Magnificent, none has the right to be worshipped except Him, the Ever-Living, the Sustainer of all existence, and I turn to Him in repentance.",count:3,reference:"Abu Dawud, At-Tirmidhi, Hisnul Muslim No. 271",reward:"Whoever says this, his sins will be forgiven even if he had fled from battle. (Abu Dawud, At-Tirmidhi)"),
  HisnulEntry(id:90,type:"Dua",category:"General Praise & Repentance",title:"Glorification in the closing of a gathering (Kaffaratul-Majlis)",arabic:"سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ، أَشْهَدُ أَنْ لاَ إِلَهَ إِلاَّ أَنْتَ، أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ",transliteration:"Subhanakallahumma wa bihamdik, ashhadu an la ilaha illa ant, astaghfiruka wa atubu ilayk",translation:"Glory be to You, O Allah, and praise. I bear witness that none has the right to be worshipped except You. I seek Your forgiveness and turn to You in repentance.",reference:"At-Tirmidhi 3/153, Hisnul Muslim No. 256",reward:"An expiation for whatever sins occurred during the gathering. (At-Tirmidhi 3/153)"),
  // ── RAMADAN ──
  HisnulEntry(id:91,type:"Dua",category:"Ramadan",title:"Upon sighting the Ramadan crescent moon",arabic:"اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالأَمْنِ وَالإِيمَانِ، وَالسَّلاَمَةِ وَالإِسْلاَمِ، وَالتَّوْفِيقِ لِمَا تُحِبُّ وَتَرْضَى، رَبِّي وَرَبُّكَ اللَّهُ",transliteration:"Allahumma ahillahu 'alayna bil-amni wal-iman, was-salamati wal-islam, wat-tawfiqi lima tuhibbu wa tarda, rabbi wa rabbukallah",translation:"O Allah, let this moon appear on us with security and faith, with peace and Islam, and with the ability to do what You love and are pleased with. My Lord and your Lord is Allah.",reference:"At-Tirmidhi 5/504, Ad-Darimi 1/336, Hisnul Muslim No. 176",reward:"The Prophet ﷺ would say this upon sighting every new moon. Welcoming the moon of Ramadan with this dua establishes the entire month under Allah's blessing, security, and tawfiq from its very first moment. (At-Tirmidhi 5/504)"),
  HisnulEntry(id:92,type:"Dua",category:"Ramadan",title:"Breaking the fast at Iftar",arabic:"ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الأَجْرُ إِنْ شَاءَ اللَّهُ",transliteration:"Dhahabaz-zama'u wabtallatil-'uruqu wa thabatal-ajru insha'allah",translation:"The thirst is gone, the veins are moistened, and the reward is confirmed, if Allah wills.",reference:"Abu Dawud 2/306, Hisnul Muslim No. 202",reward:"The Prophet ﷺ said: 'The fasting person has at the time of breaking his fast a supplication that is not rejected.' This is the most authentic dua at iftar. (Abu Dawud 2/306, authenticated by Al-Albani)"),
  HisnulEntry(id:93,type:"Dua",category:"Ramadan",title:"When someone abuses you while fasting",arabic:"إِنِّي صَائِمٌ، إِنِّي صَائِمٌ",transliteration:"Inni sa'im, inni sa'im",translation:"I am fasting. I am fasting.",reference:"Al-Bukhari 4/103, Muslim 2/806, Hisnul Muslim No. 203",reward:"The Prophet ﷺ said: 'Fasting is a shield. When one of you is fasting and someone abuses him, let him say: I am fasting.' This preserves the fast and earns the full reward of patience. (Al-Bukhari 4/103, Muslim 2/806)"),
  HisnulEntry(id:94,type:"Adhkar",category:"Ramadan",title:"Seeking Laylatul Qadr in the last 10 nights",arabic:"اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي",transliteration:"Allahumma innaka 'afuwwun tuhibbul-'afwa fa'fu 'anni",translation:"O Allah, You are Most Forgiving, You love forgiveness, so forgive me.",count:1,reference:"At-Tirmidhi 3/153, Ibn Majah 2/1265, Hisnul Muslim No. 206",reward:"Aisha (ra) asked: 'O Messenger of Allah, if I know which night is Laylatul Qadr, what should I say?' He ﷺ replied: 'Say this dua.' Reciting it on Laylatul Qadr is equivalent to worship for over 83 years. (At-Tirmidhi 3/153)"),
  HisnulEntry(id:95,type:"Adhkar",category:"Ramadan",title:"Eid Takbir",arabic:"اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، لاَ إِلَهَ إِلاَّ اللَّهُ، وَاللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، وَلِلَّهِ الْحَمْدُ",transliteration:"Allahu akbar, Allahu akbar, la ilaha illallah, wallahu akbar, Allahu akbar, wa lillahil-hamd",translation:"Allah is the Greatest, Allah is the Greatest. None has the right to be worshipped except Allah. Allah is the Greatest, Allah is the Greatest. And all praise is for Allah.",count:1,reference:"Al-Bukhari (mu'allaqan), Ibn Abi Shaybah 2/1, authenticated by Al-Albani",reward:"The Companions used to raise their voices with this Takbir from the night of Eid until the Imam came out for prayer. (Al-Bukhari, authenticated by Al-Albani)"),
  HisnulEntry(id:96,type:"Dua",category:"Ramadan",title:"Eid greeting to a fellow Muslim",arabic:"تَقَبَّلَ اللَّهُ مِنَّا وَمِنْكُمْ",transliteration:"Taqabbalallahu minna wa minkum",translation:"May Allah accept from us and from you.",reference:"Al-Mughni li Ibn Qudamah 2/259, authenticated by Al-Albani",reward:"This was the greeting of the Companions on the day of Eid. Saying it to your fellow Muslim means you are making dua for their deeds to be accepted — and the angels say Ameen for you. (Al-Albani, Irwa al-Ghalil 3/124)"),
  HisnulEntry(id:97,type:"Dua",category:"Ramadan",title:"Witr Qunut — supplication in the last rak'ah",arabic:"اللَّهُمَّ اهْدِنِي فِيمَنْ هَدَيْتَ، وَعَافِنِي فِيمَنْ عَافَيْتَ، وَتَوَلَّنِي فِيمَنْ تَوَلَّيْتَ، وَبَارِكْ لِي فِيمَا أَعْطَيْتَ، وَقِنِي شَرَّ مَا قَضَيْتَ، فَإِنَّكَ تَقْضِي وَلاَ يُقْضَى عَلَيْكَ، وَإِنَّهُ لاَ يَذِلُّ مَنْ وَالَيْتَ، تَبَارَكْتَ رَبَّنَا وَتَعَالَيْتَ",transliteration:"Allahummahdini fiman hadayt, wa 'afini fiman 'afayt, wa tawallani fiman tawallayt, wa barik li fima a'tayt, wa qini sharra ma qadayt, fa innaka taqdi wa la yuqda 'alayk, wa innahu la yadhillu man walayt, tabarakta rabbana wa ta'alayt",translation:"O Allah, guide me among those You have guided, pardon me among those You have pardoned, turn to me in friendship among those on whom You have turned in friendship, bless me in what You have bestowed, and save me from the evil of what You have decreed. For verily You decree and none can influence You. And he is not humiliated whom You have befriended. Blessed are You, our Lord, and Exalted.",reference:"Abu Dawud 2/39, At-Tirmidhi 2/328, Hisnul Muslim No. 23",reward:"The Prophet ﷺ taught this Qunut to Al-Hasan ibn Ali (ra) to recite in Witr. Reciting it in Witr especially in Ramadan's last nights carries enormous reward. (Abu Dawud 2/39)"),
  HisnulEntry(id:98,type:"Adhkar",category:"Ramadan",title:"Abundant istighfar in Ramadan",arabic:"أَسْتَغْفِرُ اللَّهَ",transliteration:"Astaghfirullah",translation:"I seek the forgiveness of Allah.",count:100,reference:"Muslim 4/2075, Hisnul Muslim No. 270",reward:"The Prophet ﷺ said: 'By Allah, I seek forgiveness from Allah and repent to Him more than seventy times a day.' Pairing the fast with abundant istighfar multiplies expiation. (Al-Bukhari 1/21)"),
  HisnulEntry(id:99,type:"Adhkar",category:"Ramadan",title:"Tasbih of Ramadan nights — abundant in Tarawih",arabic:"سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ",transliteration:"SubhanAllahi wa bihamdih, SubhanAllahil-'azim",translation:"Glory be to Allah and praise be to Him. Glory be to Allah, the Most Great.",count:100,reference:"Al-Bukhari 7/168, Muslim 4/2072, Hisnul Muslim No. 72",reward:"Two phrases light on the tongue, heavy on the scales, beloved to the Most Merciful. Filling Ramadan nights with this tasbih multiplies rewards manifold. (Al-Bukhari 7/168)"),
  HisnulEntry(id:100,type:"Dua",category:"Ramadan",title:"Supplication when hearing Fajr adhan in Ramadan",arabic:"اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ وَالصَّلاَةِ الْقَائِمَةِ، آتِ مُحَمَّداً الْوَسِيلَةَ وَالْفَضِيلَةَ وَابْعَثْهُ مَقَاماً مَحْمُوداً الَّذِي وَعَدْتَهُ",transliteration:"Allahumma rabba hadhihid-da'watit-tammati was-salatil-qa'imah, ati Muhammadanil-wasilata wal-fadilah, wab'athu maqamam-mahmudan alladhi wa'adtah",translation:"O Allah, Lord of this perfect call and established prayer, grant Muhammad the privilege of intercession and excellence, and raise him to the praiseworthy station You have promised him.",reference:"Al-Bukhari 1/152, Hisnul Muslim No. 18",reward:"The Prophet ﷺ said: 'Whoever says this after hearing the adhan, my intercession will be permitted for him on the Day of Resurrection.' (Al-Bukhari 1/152)"),
  HisnulEntry(id:101,type:"Dua",category:"Ramadan",title:"Dua for a fasting person who eats at your table",arabic:"أَفْطَرَ عِنْدَكُمُ الصَّائِمُونَ، وَأَكَلَ طَعَامَكُمُ الأَبْرَارُ، وَصَلَّتْ عَلَيْكُمُ الْمَلاَئِكَةُ",transliteration:"Aftara 'indakumus-sa'imun, wa akala ta'amakumul-abrar, wa sallat 'alaykumul-mala'ikah",translation:"May the fasting people break their fast with you, may the righteous eat your food, and may the angels send prayers upon you.",reference:"Abu Dawud 3/367, Ibn Majah 1/556, Hisnul Muslim No. 201",reward:"The Prophet ﷺ said: 'Whoever feeds a fasting person to break his fast, he will have a reward equal to his.' This dua calls down three blessings at once. (At-Tirmidhi 3/143)"),
  HisnulEntry(id:102,type:"Dua",category:"Ramadan",title:"Dua at the completion of Ramadan",arabic:"اللَّهُمَّ تَقَبَّلْ مِنَّا صِيَامَنَا وَقِيَامَنَا وَرُكُوعَنَا وَسُجُودَنَا وَتِلاَوَتَنَا وَصَدَقَاتِنَا، وَأَتْمِمْ تَقْصِيرَنَا، يَا كَرِيمُ",transliteration:"Allahumma taqabbal minna siyamana wa qiyamana wa ruku'ana wa sujudana wa tilawatana wa sadaqatina, wa atmim taqsirana, ya Karim",translation:"O Allah, accept from us our fasting, our night prayers, our bowing, our prostrations, our recitation, and our charity. Complete what we fell short in. O Most Generous.",reference:"Reported from the Salaf, Ibn Rajab's Lata'if al-Ma'arif",reward:"The pious predecessors used to make dua for 6 months that Allah accept Ramadan from them. Ending Ramadan with this comprehensive dua is the seal of a complete month of worship. (Ibn Rajab, Lata'if al-Ma'arif)"),
];

// ──────────────────────────────────────────────────────────────────────
//  CATEGORY MAP
// ──────────────────────────────────────────────────────────────────────
const Map<String, String> _categoryEmojis = {
  'Morning Adhkar': '🌅',
  'Evening Adhkar': '🌙',
  'After Salah Adhkar': '🕌',
  'Waking Up & Sleeping': '😴',
  'Home & Family': '🏠',
  'Dress & Appearance': '👕',
  'Toilet & Cleanliness': '🚿',
  'Food & Drink': '🍽️',
  'Mosque & Prayer': '🕋',
  'Traveling & Moving': '✈️',
  'Hardship & Anxiety': '💆',
  'Illness & Death': '🏥',
  'Social Interactions': '🤝',
  'Knowledge & Protection': '📚',
  'General Praise & Repentance': '🤲',
  'Ramadan': '🌙',
};

List<String> get _allCategories => _categoryEmojis.keys.toList();

// ──────────────────────────────────────────────────────────────────────
//  PROVIDERS
// ──────────────────────────────────────────────────────────────────────
final _hisnulBookmarksProvider =
    StateNotifierProvider<_BookmarkNotifier, Set<int>>((ref) {
  return _BookmarkNotifier();
});

class _BookmarkNotifier extends StateNotifier<Set<int>> {
  _BookmarkNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hisnul_bookmarks') ?? [];
    state = saved.map(int.parse).toSet();
  }

  Future<void> toggle(int id) async {
    final s = Set<int>.from(state);
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'hisnul_bookmarks', s.map((e) => e.toString()).toList());
  }
}

final _hisnulCountProvider =
    StateNotifierProvider<_CountNotifier, Map<int, int>>((ref) {
  return _CountNotifier();
});

class _CountNotifier extends StateNotifier<Map<int, int>> {
  _CountNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hisnul_counts') ?? [];
    final m = <int, int>{};
    for (final s in saved) {
      final parts = s.split(':');
      if (parts.length == 2) {
        m[int.parse(parts[0])] = int.parse(parts[1]);
      }
    }
    state = m;
  }

  Future<void> increment(int id, int max) async {
    final m = Map<int, int>.from(state);
    final cur = m[id] ?? 0;
    if (cur < max) {
      m[id] = cur + 1;
    }
    state = m;
    await _save();
  }

  Future<void> decrement(int id) async {
    final m = Map<int, int>.from(state);
    final cur = m[id] ?? 0;
    if (cur > 0) {
      m[id] = cur - 1;
    }
    state = m;
    await _save();
  }

  Future<void> reset(int id) async {
    final m = Map<int, int>.from(state);
    m.remove(id);
    state = m;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'hisnul_counts',
        state.entries.map((e) => '${e.key}:${e.value}').toList());
  }
}

// ──────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ──────────────────────────────────────────────────────────────────────
class HisnulMuslimScreen extends ConsumerStatefulWidget {
  const HisnulMuslimScreen({super.key});

  @override
  ConsumerState<HisnulMuslimScreen> createState() => _HisnulMuslimScreenState();
}

class _HisnulMuslimScreenState extends ConsumerState<HisnulMuslimScreen> {
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Adhkar, Dua
  String? _categoryFilter;
  bool _showBookmarksOnly = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 400;
      if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<HisnulEntry> get _filteredEntries {
    var list = _allEntries.toList();

    // Type filter
    if (_typeFilter == 'Adhkar') {
      list = list.where((e) => e.type == 'Adhkar').toList();
    } else if (_typeFilter == 'Dua') {
      list = list.where((e) => e.type == 'Dua').toList();
    }

    // Category filter
    if (_categoryFilter != null) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.arabic.contains(q) ||
            e.translation.toLowerCase().contains(q) ||
            e.transliteration.toLowerCase().contains(q);
      }).toList();
    }

    // Bookmarks
    if (_showBookmarksOnly) {
      final bm = ref.read(_hisnulBookmarksProvider);
      list = list.where((e) => bm.contains(e.id)).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final bookmarks = ref.watch(_hisnulBookmarksProvider);
    final counts = ref.watch(_hisnulCountProvider);
    final filtered = _filteredEntries;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              backgroundColor: tc.green.withValues(alpha: 0.9),
              onPressed: () {
                _scrollController.animateTo(0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut);
              },
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            )
          : null,
      body: Column(
          children: [
            // ── Search + Bookmark + Type filter ──
            _buildSearchRow(tc),
            // ── Category chips ──
            _buildCategoryChips(tc),
            const SizedBox(height: 6),
            // ── List ──
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(tc)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        return _HisnulCard(
                          entry: entry,
                          tc: tc,
                          isBookmarked: bookmarks.contains(entry.id),
                          currentCount: counts[entry.id] ?? 0,
                        );
                      },
                    ),
            ),
          ],
      ),
    );
  }

  Widget _buildSearchRow(IslamicThemeColors tc) {
    const types = ['All', 'Adhkar', 'Dua'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tc.border.withValues(alpha: 0.4)),
              ),
              child: TextField(
                style: TextStyle(color: tc.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.4),
                      fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: tc.textSecondary.withValues(alpha: 0.4)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: Icon(Icons.close_rounded,
                              size: 16,
                              color: tc.textSecondary.withValues(alpha: 0.4)),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bookmark toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showBookmarksOnly = !_showBookmarksOnly);
            },
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _showBookmarksOnly
                    ? tc.accent.withValues(alpha: 0.15)
                    : tc.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showBookmarksOnly
                      ? tc.accent.withValues(alpha: 0.5)
                      : tc.border.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                _showBookmarksOnly
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                size: 18,
                color: _showBookmarksOnly
                    ? tc.accent
                    : tc.textSecondary.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Type toggle pills
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.border.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: types.map((t) {
                final selected = _typeFilter == t;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _typeFilter = t);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? tc.green.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: selected
                            ? tc.green
                            : tc.textSecondary.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(IslamicThemeColors tc) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _allCategories.length + 1, // +1 for "All" chip
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = _categoryFilter == null;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _categoryFilter = null);
                },
                child: Chip(
                  label: Text('All',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white : tc.text.withValues(alpha: 0.7),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      )),
                  backgroundColor: selected
                      ? tc.accent.withValues(alpha: 0.85)
                      : tc.surface,
                  side: BorderSide(
                    color: selected
                        ? tc.accent.withValues(alpha: 0.9)
                        : tc.border.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );
          }
          final cat = _allCategories[index - 1];
          final emoji = _categoryEmojis[cat] ?? '📿';
          final selected = _categoryFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() =>
                    _categoryFilter = _categoryFilter == cat ? null : cat);
              },
              child: Chip(
                label: Text(
                  '$emoji ${cat.replaceAll(' Adhkar', '').replaceAll(' & ', '/')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : tc.text.withValues(alpha: 0.7),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                backgroundColor: selected
                    ? tc.accent.withValues(alpha: 0.85)
                    : tc.surface,
                side: BorderSide(
                  color: selected
                      ? tc.accent.withValues(alpha: 0.9)
                      : tc.border.withValues(alpha: 0.6),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(IslamicThemeColors tc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: tc.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            _showBookmarksOnly ? 'No bookmarks yet' : 'No results found',
            style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
//  HISNUL CARD
// ──────────────────────────────────────────────────────────────────────
class _HisnulCard extends ConsumerStatefulWidget {
  final HisnulEntry entry;
  final IslamicThemeColors tc;
  final bool isBookmarked;
  final int currentCount;

  const _HisnulCard({
    required this.entry,
    required this.tc,
    required this.isBookmarked,
    required this.currentCount,
  });

  @override
  ConsumerState<_HisnulCard> createState() => _HisnulCardState();
}

class _HisnulCardState extends ConsumerState<_HisnulCard>
    with SingleTickerProviderStateMixin {
  bool _showTransliteration = false;
  bool _showReward = false;
  bool _showArabic = true; // default, adjusted in initState
  late AnimationController _completionController;
  late Animation<double> _completionAnimation;
  bool _justCompleted = false;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _completionAnimation = CurvedAnimation(
      parent: _completionController,
      curve: Curves.elasticOut,
    );
  // By default hide Arabic for Hadith entries
  _showArabic = widget.entry.type != 'Hadith';
  }

  @override
  void dispose() {
    _completionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HisnulCard old) {
    super.didUpdateWidget(old);
    if (widget.entry.count != null &&
        widget.currentCount >= widget.entry.count! &&
        old.currentCount < widget.entry.count!) {
      _justCompleted = true;
      _completionController.forward(from: 0);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justCompleted = false);
      });
    }
    // if the entry changed, reset Arabic visibility according to type
    if (old.entry.id != widget.entry.id) {
      _showArabic = widget.entry.type != 'Hadith';
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final tc = widget.tc;
    final isComplete =
        e.count != null && widget.currentCount >= e.count!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete
              ? tc.green.withValues(alpha: 0.3)
              : tc.border.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top badges row ──
          _buildBadgeRow(tc, e),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              e.title,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // ── Arabic (hidden by default for Hadith) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AnimatedCrossFade(
              firstChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: tc.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: tc.text.withValues(alpha: 0.9),
                    ),
                    icon: Icon(Icons.remove_red_eye_outlined,
                        size: 18, color: tc.textSecondary.withValues(alpha: 0.6)),
                    label: Text('Show Arabic',
                        style: TextStyle(
                            color: tc.textSecondary.withValues(alpha: 0.7))),
                    onPressed: () => setState(() => _showArabic = true),
                  ),
                ),
              ),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: tc.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      e.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(
                        color: tc.arabicText,
                        fontSize: 26,
                        height: 2.2,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: e.arabic));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Arabic text copied'),
                                backgroundColor: tc.green.withValues(alpha: 0.9),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 12,
                                  color: tc.textSecondary.withValues(alpha: 0.35)),
                              const SizedBox(width: 6),
                              Text(
                                'Copy Arabic',
                                style: TextStyle(
                                  color: tc.textSecondary.withValues(alpha: 0.35),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Hide button
                        GestureDetector(
                          onTap: () => setState(() => _showArabic = false),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_outlined,
                                  size: 14,
                                  color: tc.textSecondary.withValues(alpha: 0.35)),
                              const SizedBox(width: 6),
                              Text(
                                'Hide',
                                style: TextStyle(
                                  color: tc.textSecondary.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  _showArabic ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ),
          const SizedBox(height: 12),
          // ── Transliteration (collapsible) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _showTransliteration = !_showTransliteration),
              child: Row(
                children: [
                  Icon(
                    _showTransliteration
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: tc.green.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Transliteration',
                    style: TextStyle(
                      color: tc.green.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                e.transliteration,
                style: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
            ),
            crossFadeState: _showTransliteration
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 12),
          // ── Translation ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: tc.accent.withValues(alpha: 0.4),
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              e.translation,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.75),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Reference pill ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.reference,
                style: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // ── Reward (conditional) ──
          if (e.reward != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showReward = !_showReward),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 14, color: tc.accent.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _showReward ? 'Hide Reward' : 'Show Reward',
                      style: TextStyle(
                        color: tc.accent.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showReward
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 14,
                      color: tc.accent.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tc.accent.withValues(alpha: 0.08),
                      tc.accent.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: tc.accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: tc.accent.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.reward!,
                        style: TextStyle(
                          color: tc.text.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showReward
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
          // ── Count tracker (conditional) ──
          if (e.count != null) ...[
            const SizedBox(height: 12),
            _buildCountTracker(tc, e, isComplete),
          ],
          // ── Divider ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Divider(
              height: 1,
              color: tc.border.withValues(alpha: 0.15),
            ),
          ),
          // ── Action row ──
          _buildActionRow(tc, e),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(IslamicThemeColors tc, HisnulEntry e) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: e.type == 'Adhkar'
                  ? tc.green.withValues(alpha: 0.12)
                  : tc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              e.type.toUpperCase(),
              style: TextStyle(
                color: e.type == 'Adhkar'
                    ? tc.green.withValues(alpha: 0.8)
                    : tc.accent.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Category chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_categoryEmojis[e.category] ?? "📿"} ${e.category.replaceAll(" Adhkar", "")}',
              style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.55),
                fontSize: 9.5,
              ),
            ),
          ),
          const Spacer(),
          // Count badge
          if (e.count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '×${e.count}',
                style: TextStyle(
                  color: tc.green.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountTracker(
      IslamicThemeColors tc, HisnulEntry e, bool isComplete) {
    final max = e.count!;
    final cur = widget.currentCount;
    final progress = max > 0 ? (cur / max).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isComplete
              ? tc.green.withValues(alpha: 0.06)
              : tc.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isComplete
                ? tc.green.withValues(alpha: 0.2)
                : tc.border.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Minus button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(_hisnulCountProvider.notifier).decrement(e.id);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tc.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.remove_rounded,
                    size: 16, color: tc.textSecondary.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: 12),
            // Circular progress
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: tc.border.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                            isComplete
                                ? tc.green.withValues(alpha: 0.8)
                                : tc.green.withValues(alpha: 0.5),
                          ),
                        ),
                        if (_justCompleted)
                          ScaleTransition(
                            scale: _completionAnimation,
                            child: Icon(Icons.check_circle_rounded,
                                size: 24,
                                color: tc.green.withValues(alpha: 0.8)),
                          )
                        else
                          Text(
                            '$cur',
                            style: TextStyle(
                              color: tc.text.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ $max',
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: tc.green.withValues(alpha: 0.7)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Plus button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(_hisnulCountProvider.notifier)
                    .increment(e.id, max);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tc.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_rounded,
                    size: 16, color: tc.green.withValues(alpha: 0.8)),
              ),
            ),
            // Reset button
            if (cur > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(_hisnulCountProvider.notifier).reset(e.id);
                },
                child: Icon(Icons.refresh_rounded,
                    size: 16, color: tc.textSecondary.withValues(alpha: 0.35)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(IslamicThemeColors tc, HisnulEntry e) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // Bookmark
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(_hisnulBookmarksProvider.notifier).toggle(e.id);
            },
            child: Icon(
              widget.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 20,
              color: widget.isBookmarked
                  ? tc.accent
                  : tc.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 16),
          // Share
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Share.share(e.shareableText);
            },
            child: Icon(Icons.share_outlined,
                size: 18, color: tc.textSecondary.withValues(alpha: 0.3)),
          ),
          const SizedBox(width: 16),
          // Copy all
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: e.shareableText));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copied to clipboard'),
                  backgroundColor: tc.green.withValues(alpha: 0.9),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Icon(Icons.copy_all_rounded,
                size: 18, color: tc.textSecondary.withValues(alpha: 0.3)),
          ),
          const Spacer(),
          // Entry number
          Text(
            '#${e.id}',
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.25),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
