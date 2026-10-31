import 'history.dart';
import 'profile.dart';

/// Un fil trouvé : [text] est le texte original (titre, aperçu ou extrait
/// d'un message déjà chargé), [start]–[end] le passage correspondant dans
/// [text], aux limites de caractères d'origine.
class SearchHit {
  const SearchHit({
    required this.profile,
    required this.session,
    required this.text,
    required this.start,
    required this.end,
  });
  final ProfileKey profile;
  final SessionSummary session;
  final String text;
  final int start;
  final int end;
}

const _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ç': 'c', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', //
  'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ø': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', //
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
};

bool _combining(int c) => c >= 0x300 && c <= 0x36F;

/// Texte sans casse ni diacritiques et, pour chaque unité produite, son
/// indice dans [s].
// ponytail: table latine + marques combinantes U+0300–036F ; une vraie
// décomposition NFD si d'autres écritures doivent être couvertes.
(String, List<int>) fold(String s) {
  final out = StringBuffer();
  final origin = <int>[];
  for (var i = 0; i < s.length; i++) {
    final unit = s.codeUnitAt(i);
    if (_combining(unit)) continue;
    // Paire de substitution (emoji) : recopiée telle quelle, jamais coupée.
    if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < s.length) {
      out.write(s.substring(i, i + 2));
      origin
        ..add(i)
        ..add(i + 1);
      i++;
      continue;
    }
    for (final ch in s[i].toLowerCase().split('')) {
      if (_combining(ch.codeUnitAt(0))) continue;
      final folded = _fold[ch] ?? ch;
      out.write(folded);
      for (var k = 0; k < folded.length; k++) {
        origin.add(i);
      }
    }
  }
  return (out.toString(), origin);
}

/// Passage de [text] correspondant à [query] (déjà replié), ou `null`.
(int, int)? match(String text, String query) {
  if (query.isEmpty) return null;
  final (folded, origin) = fold(text);
  final at = folded.indexOf(query);
  if (at < 0) return null;
  final last = at + query.length;
  final start = origin[at];
  // La fin englobe les marques combinantes qui suivent le dernier caractère.
  var end = last < origin.length ? origin[last] : text.length;
  if (end <= origin[last - 1]) end = origin[last - 1] + 1;
  return (start, end);
}

/// Fenêtre autour d'un passage trouvé dans un long message.
const _context = 40;

/// Fils de [sessions] (ordre conservé) dont le titre, l'aperçu ou un texte
/// chargé contient [query] ; un seul résultat par fil.
List<SearchHit> searchSessions(
  String query, {
  required ProfileKey profile,
  required List<SessionSummary> sessions,
  Map<String, List<String>> texts = const {},
}) {
  final q = fold(query.trim()).$1;
  if (q.isEmpty) return const [];
  final hits = <SearchHit>[];
  for (final s in sessions) {
    SearchHit? hit;
    for (final (i, text) in [
      s.title,
      s.preview,
      ...?texts[s.id],
    ].nonNulls.indexed) {
      final m = match(text, q);
      if (m == null) continue;
      var (start, end) = m;
      var snippet = text;
      // Titre et aperçu entiers ; un message est réduit autour du passage.
      if (i > 1 && text.length > 2 * _context) {
        var from = (start - _context).clamp(0, text.length);
        var to = (end + _context).clamp(0, text.length);
        if (from > 0 && _low(text.codeUnitAt(from))) from--;
        if (to < text.length && _low(text.codeUnitAt(to))) to++;
        final lead = from > 0 ? '…' : '';
        snippet =
            '$lead${text.substring(from, to)}${to < text.length ? '…' : ''}';
        start = start - from + lead.length;
        end = end - from + lead.length;
      }
      hit = SearchHit(
        profile: profile,
        session: s,
        text: snippet,
        start: start,
        end: end,
      );
      break;
    }
    if (hit != null) hits.add(hit);
  }
  return hits;
}

bool _low(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
