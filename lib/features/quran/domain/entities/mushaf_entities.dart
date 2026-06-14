class MushafAyahEntity {
  final int surahId;
  final int ayahNum;
  final String text;
  final int juz;
  final int hizbQuarter;
  final bool isSajda;

  const MushafAyahEntity({
    required this.surahId,
    required this.ayahNum,
    required this.text,
    required this.juz,
    required this.hizbQuarter,
    required this.isSajda,
  });
}

class MushafSurahInfo {
  final int id;
  final String arabicName;
  final String type; // meccan / medinan
  final int verseCount;

  const MushafSurahInfo({
    required this.id,
    required this.arabicName,
    required this.type,
    required this.verseCount,
  });
}

class MushafPageEntity {
  final int pageNumber;
  final int juzNumber;
  final List<MushafAyahEntity> ayahs;

  const MushafPageEntity({
    required this.pageNumber,
    required this.juzNumber,
    required this.ayahs,
  });

  List<int> get surahIds {
    final seen = <int>{};
    return ayahs.map((a) => a.surahId).where(seen.add).toList();
  }

  List<MushafAyahEntity> ayahsForSurah(int id) =>
      ayahs.where((a) => a.surahId == id).toList();
}

class MushafInitData {
  final List<MushafSurahInfo> surahInfos;
  final Map<int, int> surahFirstPages;
  final int lastReadPage;
  final String lastReadSurahName;
  final int lastReadJuz;
  final List<MushafBookmark> bookmarks;
  final Set<int> readPages;
  final bool tajweedMode;

  const MushafInitData({
    required this.surahInfos,
    required this.surahFirstPages,
    this.lastReadPage = 1,
    this.lastReadSurahName = '',
    this.lastReadJuz = 1,
    this.bookmarks = const [],
    this.readPages = const <int>{},
    this.tajweedMode = false,
  });
}

// ─── Bookmark / Highlight ───

class MushafBookmark {
  final int surahId;
  final int ayahNum;
  final int pageNum;
  final String note;
  final int colorIndex; // 0=bookmark only, 1=yellow, 2=green, 3=blue, 4=red
  final int timestamp;

  const MushafBookmark({
    required this.surahId,
    required this.ayahNum,
    required this.pageNum,
    this.note = '',
    this.colorIndex = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        's': surahId,
        'a': ayahNum,
        'p': pageNum,
        'n': note,
        'c': colorIndex,
        't': timestamp,
      };

  factory MushafBookmark.fromJson(Map<String, dynamic> j) => MushafBookmark(
        surahId: j['s'] as int,
        ayahNum: j['a'] as int,
        pageNum: j['p'] as int,
        note: (j['n'] as String?) ?? '',
        colorIndex: (j['c'] as int?) ?? 0,
        timestamp: (j['t'] as int?) ?? 0,
      );

  MushafBookmark copyWith({String? note, int? colorIndex}) => MushafBookmark(
        surahId: surahId,
        ayahNum: ayahNum,
        pageNum: pageNum,
        note: note ?? this.note,
        colorIndex: colorIndex ?? this.colorIndex,
        timestamp: timestamp,
      );
}
