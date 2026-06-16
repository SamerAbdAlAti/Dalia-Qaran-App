"""
generate_quran_lines.py
Generates assets/quran/quran_lines.json from the Quran.com public API v4.

Each page contains:
  - lines: list of {l, t, c, type} — one entry per Mushaf line
  - ayahs: list of {s, a, t, j, h, sa} — full ayah text + metadata

Line types:
  "normal"     — ayah text line (justified)
  "basmala"    — بسم الله line (centered)
  "surah_name" — surah header line (centered, styled)
  "centered"   — other centered line

Usage:
  pip install requests
  python generate_quran_lines.py
  (output: assets/quran/quran_lines.json)
"""

import json
import time
import sys
import os
import requests
from collections import defaultdict

BASE = "https://api.qurancdn.com/api/v4"
OUT  = os.path.join(os.path.dirname(__file__), "..", "assets", "quran", "quran_lines.json")
TOTAL_PAGES = 604

BASMALA = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"

# ─── Helpers ───────────────────────────────────────────────────────────────────

def get_json(url, params=None, retries=5):
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, timeout=30)
            r.raise_for_status()
            return r.json()
        except Exception as e:
            if attempt == retries - 1:
                raise
            wait = 2 ** attempt
            print(f"  retry {attempt+1} after {wait}s ({e})")
            time.sleep(wait)

# ─── Fetch chapters ─────────────────────────────────────────────────────────────

def fetch_chapters():
    print("Fetching chapters...")
    data = get_json(f"{BASE}/chapters", {"language": "ar"})
    chapters = {}
    for ch in data["chapters"]:
        cid = ch["id"]
        chapters[cid] = {
            "name":         ch.get("name_arabic") or ch.get("name_simple") or "",
            "type":         "meccan" if ch.get("revelation_place", "").lower() in ("mecca", "meccan") else "medinan",
            "verse_count":  ch["verses_count"],
        }
    return chapters   # {surah_id: {name, type, verse_count}}

# ─── Fetch one page ──────────────────────────────────────────────────────────────

def fetch_page_verses(page_num):
    """Returns list of verse dicts from API for this page."""
    data = get_json(
        f"{BASE}/verses/by_page/{page_num}",
        {
            "words":       "true",
            "word_fields": "text_uthmani,line_number,page_number,char_type_name",
            "fields":      "text_uthmani,juz_number,hizb_number,sajdah_type,chapter_id,verse_number",
            "per_page":    "50",
            "page":        "1",
        },
    )
    return data.get("verses", [])

# ─── Build one page ──────────────────────────────────────────────────────────────

def build_page(page_num, verses, chapters):
    """
    Returns (lines_list, ayahs_list) for this page.
    """
    if not verses:
        return [], []

    first_verse   = verses[0]
    juz_number    = first_verse.get("juz_number") or 1

    # ── ayahs ──
    ayahs = []
    for v in verses:
        sid  = v.get("chapter_id") or int(v["verse_key"].split(":")[0])
        anum = v.get("verse_number") or int(v["verse_key"].split(":")[1])
        text = v.get("text_uthmani") or ""
        juz  = v.get("juz_number") or 1
        hizb = v.get("hizb_number") or 1
        sajd = bool(v.get("sajdah_type"))
        ayahs.append({"s": sid, "a": anum, "t": text, "j": juz, "h": hizb, "sa": sajd})

    # ── lines: group words by line_number ──
    line_words: dict[int, list[str]] = defaultdict(list)
    line_char_types: dict[int, set[str]] = defaultdict(set)

    for v in verses:
        sid  = v.get("chapter_id") or int(v["verse_key"].split(":")[0])
        anum = v.get("verse_number") or int(v["verse_key"].split(":")[1])
        for w in (v.get("words") or []):
            pg = w.get("page_number")
            # Include word if it belongs to this page, or if page_number is null
            if pg is not None and pg != page_num:
                continue
            ln    = w.get("line_number")
            ctype = w.get("char_type_name") or "word"
            # For "end" words (ayah markers), ensure ۝ prefix so fonts can render the circle
            raw   = (w.get("text_uthmani") or "").strip()
            if not raw:
                continue
            if ctype == "end":
                # Keep only Arabic-Indic digits, prefix with ۝ (U+06DD)
                digits = "".join(c for c in raw if "٠" <= c <= "٩")
                text = "۝" + digits if digits else raw
            else:
                text = raw
            if ln and text:
                line_words[ln].append(text)
                line_char_types[ln].add(ctype)

    if not line_words:
        return [], ayahs

    min_line = min(line_words)
    max_line = max(line_words)

    lines = []

    # ── detect surah start on this page ──
    first_ayah = ayahs[0]
    surah_starts_here = first_ayah["a"] == 1  # first verse of a surah starts on this page

    # Detect if there's a gap at the top = surah header lines
    gap_at_top = list(range(1, min_line))  # line numbers without words

    if surah_starts_here and gap_at_top:
        # First gap line = surah name header
        sid_for_header = first_ayah["s"]
        ch = chapters.get(sid_for_header, {})
        surah_name = ch.get("name", "")
        type_label = "مكية" if ch.get("type") == "meccan" else "مدنية"
        vc = ch.get("verse_count", 0)
        header_text = f"{surah_name}  •  {type_label}  •  {vc} آية"

        # Use first gap line as surah name
        lines.append({"l": gap_at_top[0], "t": header_text, "c": True, "type": "surah_name"})

        # Remaining gap lines before min_line (if any): bismillah or empty centered
        for gln in gap_at_top[1:]:
            # If the surah is not At-Tawbah (9) and not Al-Fatiha (1 already has basmala as v1),
            # add basmala line for the gap before first word
            if sid_for_header != 9 and sid_for_header != 1:
                lines.append({"l": gln, "t": BASMALA, "c": True, "type": "basmala"})
            else:
                # Empty decorative centered line
                lines.append({"l": gln, "t": "", "c": True, "type": "centered"})

    elif gap_at_top:
        # Gap exists but surah doesn't start here — shouldn't normally happen
        # Fill with empty centered lines
        for gln in gap_at_top:
            lines.append({"l": gln, "t": "", "c": True, "type": "centered"})

    # ── normal text lines ──
    for ln in sorted(line_words.keys()):
        text = " ".join(line_words[ln])
        ctypes = line_char_types[ln]

        # Detect basmala line: if the first verse is verse 1 of surah and
        # it's a short single-line, or if words match known basmala
        is_basmala = False
        is_surah_name_line = False

        if surah_starts_here:
            # Check if this is verse 1:1 of Al-Fatiha (basmala IS the verse)
            first_v = verses[0]
            if first_v.get("chapter_id") == 1 and first_v.get("verse_number") == 1:
                if ln == min_line:
                    is_basmala = True

        line_type = "normal"
        is_centered = False

        if is_basmala:
            line_type = "basmala"
            is_centered = True
        elif "end" in ctypes and len(line_words[ln]) <= 3:
            # Short lines with only end markers — likely centered
            is_centered = True

        lines.append({"l": ln, "t": text, "c": is_centered, "type": line_type})

    # Sort lines by line number
    lines.sort(key=lambda x: x["l"])

    return lines, ayahs

# ─── Main ────────────────────────────────────────────────────────────────────────

def main():
    chapters = fetch_chapters()

    # Build surahs array (ordered 1-114)
    surahs = []
    for i in range(1, 115):
        ch = chapters.get(i, {"name": "", "type": "meccan", "verse_count": 0})
        surahs.append({"n": ch["name"], "t": ch["type"], "v": ch["verse_count"]})

    pages_out = []

    for page_num in range(1, TOTAL_PAGES + 1):
        sys.stdout.write(f"\rProcessing page {page_num}/{TOTAL_PAGES}...")
        sys.stdout.flush()

        try:
            verses = fetch_page_verses(page_num)
        except Exception as e:
            print(f"\nERROR on page {page_num}: {e}")
            pages_out.append({"p": page_num, "j": 1, "lines": [], "ayahs": []})
            continue

        lines, ayahs = build_page(page_num, verses, chapters)

        juz = ayahs[0]["j"] if ayahs else 1
        pages_out.append({"p": page_num, "j": juz, "lines": lines, "ayahs": ayahs})

        # Be polite to the API — 100ms between requests
        time.sleep(0.1)

    print(f"\nDone. Writing {OUT}")

    out_data = {"surahs": surahs, "pages": pages_out}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out_data, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = os.path.getsize(OUT) / (1024 * 1024)
    print(f"Output: {OUT}  ({size_mb:.1f} MB)")

if __name__ == "__main__":
    main()
