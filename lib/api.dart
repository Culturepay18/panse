import 'dart:convert';

import 'package:http/http.dart' as http;

class Quote {
  final String text;
  final String author;


  const Quote({required this.text, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json) {
    final text =
        _firstNonEmpty(json, ['quote', 'content', 'text', 'q']) ?? '';
    final author =
        _firstNonEmpty(json, ['author', 'a', 'authorSlug']) ?? 'Unknown';
    return Quote(text: text, author: author);
  }

  static String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) {
        continue;
      }

      final normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }
}

class Api {
  static const int _defaultLimit = 50;
  static const Duration _timeout = Duration(seconds: 8);
  static const String _baseUrl = 'https://dummyjson.com/quotes';

  static Future<List<Quote>> fetchQuotes({int limit = _defaultLimit}) async {
    final response =
        await http.get(Uri.parse('$_baseUrl?limit=$limit')).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: impossible de charger les quotes.');
    }

    final quotes = _parseQuotes(response.body);
    if (quotes.isEmpty) {
      throw Exception('Aucune quote trouvee dans la reponse API.');
    }

    return quotes;
  }

  // Keep old name for compatibility with existing UI code.
  static Future<List<Quote>> fetch5Quotes() => fetchQuotes(limit: _defaultLimit);

  static List<Quote> _parseQuotes(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return [];
    }

    final rawList = decoded['quotes'];
    if (rawList is! List) {
      return [];
    }

    return _parseQuoteList(rawList);
  }

  static List<Quote> _parseQuoteList(List<dynamic> rawList) {
    final result = <Quote>[];
    for (final item in rawList) {
      if (item is Map) {
        final normalized = item.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
        final quote = Quote.fromJson(normalized);
        if (quote.text.isNotEmpty) {
          result.add(quote);
        }
      }
    }
    return result;
  }
}
