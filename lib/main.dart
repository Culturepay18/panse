import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:panse_app/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  final bool autoLoad;

  const MyApp({super.key, this.autoLoad = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Homescreen(autoLoad: autoLoad),
    );
  }
}

class Homescreen extends StatefulWidget {
  final bool autoLoad;

  const Homescreen({super.key, this.autoLoad = true});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  static const String _favoritesKey = 'favorites_quotes';
  static const String _lastQuoteKey = 'last_quote';

  int index = 0;
  bool isLoading = false;
  List<Quote> quotes = [];
  List<Quote> favs = [];
  Quote? lastQuote;

  @override
  void initState() {
    super.initState();
    _restoreLocalData().then((_) {
      if (widget.autoLoad) {
        loadQuotes();
      }
    });
  }

  Future<void> _restoreLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    final storedFavs = prefs.getStringList(_favoritesKey) ?? const [];
    final restoredFavs = storedFavs
        .map(_decodeQuote)
        .whereType<Quote>()
        .toList();

    final restoredLast = _decodeQuote(prefs.getString(_lastQuoteKey));

    if (!mounted) {
      return;
    }

    setState(() {
      favs = restoredFavs;
      lastQuote = restoredLast;
    });
  }

  Future<void> _persistFavorites() async => (await SharedPreferences.getInstance())
      .setStringList(_favoritesKey, favs.map(_encodeQuote).toList());

  Future<void> _persistLastQuote(Quote? quote) async {
    final prefs = await SharedPreferences.getInstance();
    if (quote == null) {
      await prefs.remove(_lastQuoteKey);
      return;
    }
    await prefs.setString(_lastQuoteKey, _encodeQuote(quote));
  }

  String _encodeQuote(Quote quote) =>
      jsonEncode({'text': quote.text, 'author': quote.author});

  Quote? _decodeQuote(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final text = decoded['text']?.toString().trim() ?? '';
      if (text.isEmpty) return null;

      final author = decoded['author']?.toString().trim();
      return Quote(
        text: text,
        author: (author == null || author.isEmpty) ? 'Unknown' : author,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> loadQuotes() async {
    setState(() => isLoading = true);

    try {
      final data = await Api.fetch5Quotes();
      if (!mounted) {
        return;
      }

      final newest = data.isEmpty ? null : data.first;

      setState(() {
        quotes = data;
        if (newest != null) lastQuote = newest;
        isLoading = false;
      });

      if (newest != null) _persistLastQuote(newest);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        quotes = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
    }
  }

  void addFav(Quote q) {
    if (_isFavorite(q)) return;
    setState(() {
      favs.add(q);
      lastQuote = q;
    });
    _persistFavorites();
    _persistLastQuote(q);
  }

  void removeFav(Quote q) {
    setState(() => favs.removeWhere((x) => x.text == q.text));
    _persistFavorites();
  }

  bool _isFavorite(Quote q) => favs.any((x) => x.text == q.text);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        quotes: quotes,
        favs: favs,
        lastQuote: lastQuote,
        isLoading: isLoading,
        onLike: addFav,
        onReload: loadQuotes,
      ),
      FavoritesPage(favs: favs, onRemove: removeFav),
      const AboutPage(),
    ];

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.green, title: const Text('Panse')),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Quote> quotes;
  final List<Quote> favs;
  final Quote? lastQuote;
  final bool isLoading;
  final void Function(Quote) onLike;
  final Future<void> Function() onReload;

  const HomePage({
    super.key,
    required this.quotes,
    required this.favs,
    required this.lastQuote,
    required this.isLoading,
    required this.onLike,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (quotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lastQuote != null) ...[
                _LastQuoteCard(quote: lastQuote!),
                const SizedBox(height: 12),
              ],
              const Text('Aucune citation disponible.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onReload,
                child: const Text('Chaje quotes'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (lastQuote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: _LastQuoteCard(quote: lastQuote!),
          ),
        for (final q in quotes)
          Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(q.text),
              subtitle: Text(q.author),
              trailing: IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: favs.any((x) => x.text == q.text)
                      ? Colors.red
                      : Colors.grey.shade600,
                ),
                onPressed: () => onLike(q),
              ),
            ),
          ),
      ],
    );
  }
}

class _LastQuoteCard extends StatelessWidget {
  final Quote quote;

  const _LastQuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        title: Text('Derniere citation'),
        subtitle: Text('"${quote.text}"\n- ${quote.author}'),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final List<Quote> favs;
  final void Function(Quote) onRemove;

  const FavoritesPage({super.key, required this.favs, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (favs.isEmpty) {
      return const Center(child: Text('Favorites vid'));
    }

    return ListView.builder(
      itemCount: favs.length,
      itemBuilder: (context, i) {
        final q = favs[i];
        return Card(
          margin: const EdgeInsets.all(10),
          child: ListTile(
            title: Text(q.text),
            subtitle: Text(q.author),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => onRemove(q),
            ),
          ),
        );
      },
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const List<String> _images = [
    'lib/assets/photo1.png.jpeg',
    'lib/assets/images/photo2.png.jpeg',
    'lib/assets/images/photo3.png.jpeg',
  ];
  static const String _aboutText = '''Kreyate:
- Kensly EUGENE
- Rodjensky PITON
- Alisha CHERY

Kontak:
info@panse.ht''';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panse',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Aplikasyon motivasyon pou ranfose lespri ou chak jou.'),
            const SizedBox(height: 16),
            ..._images
                .map(
                  (imagePath) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.asset(
                      imagePath,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined),
                            SizedBox(width: 8),
                            Text('Image introuvable'),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
            const Text(_aboutText),
          ],
        ),
      ),
    );
  }
}
