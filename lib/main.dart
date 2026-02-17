import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panse_app/api.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class AppPalette {
  static const Color canvas = Color(0xFF040714);
  static const Color canvasGlow = Color(0xFF131A36);
  static const Color card = Color(0xFF232B4A);
  static const Color cardBorder = Color(0xFF3A4467);
  static const Color cardBack = Color(0xFF1B233F);
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textMuted = Color(0xFFB5BCD9);
  static const Color accent = Color(0xFFFF7E86);
  static const Color save = Color(0xFF18B964);
  static const Color dismiss = Color(0xFFF2727D);
  static const Color button = Color(0xFFF5F6FA);
}

class MyApp extends StatelessWidget {
  final bool autoLoad;
  final bool showSplash;

  const MyApp({super.key, this.autoLoad = true, bool? showSplash})
    : showSplash = showSplash ?? autoLoad;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: AppPalette.canvas,
        textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
          bodyColor: AppPalette.textPrimary,
          displayColor: AppPalette.textPrimary,
        ),
        colorScheme: base.colorScheme.copyWith(
          primary: AppPalette.accent,
          secondary: AppPalette.save,
          surface: AppPalette.card,
        ),
      ),
      home: SplashGate(autoLoad: autoLoad, showSplash: showSplash),
    );
  }
}

class SplashGate extends StatefulWidget {
  final bool autoLoad;
  final bool showSplash;

  const SplashGate({
    super.key,
    required this.autoLoad,
    required this.showSplash,
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  late bool _displaySplash;

  @override
  void initState() {
    super.initState();
    _displaySplash = widget.showSplash;

    if (_displaySplash) {
      _timer = Timer(const Duration(seconds: 5), () {
        if (!mounted) {
          return;
        }
        setState(() => _displaySplash = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _displaySplash
          ? const SplashScreen(key: ValueKey('splash'))
          : Homescreen(key: const ValueKey('home'), autoLoad: widget.autoLoad),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.0,
            colors: [AppPalette.canvasGlow, AppPalette.canvas],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.84, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Panse',
                  style: TextStyle(
                    fontSize: 58,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Inspirasyon chak jou',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  int _currentQuoteIndex = 0;
  bool isLoading = false;
  List<Quote> quotes = [];
  List<Quote> favs = [];
  Quote? lastQuote;

  Quote? get _currentQuote =>
      _currentQuoteIndex < quotes.length ? quotes[_currentQuoteIndex] : null;

  List<Quote> get _queuedQuotes => _currentQuoteIndex < quotes.length
      ? quotes.sublist(_currentQuoteIndex)
      : const [];

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

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favs.map(_encodeQuote).toList());
  }

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
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final text = decoded['text']?.toString().trim() ?? '';
      if (text.isEmpty) {
        return null;
      }

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
        _currentQuoteIndex = 0;
        if (newest != null) {
          lastQuote = newest;
        }
        isLoading = false;
      });

      if (newest != null) {
        _persistLastQuote(newest);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        quotes = [];
        _currentQuoteIndex = 0;
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
    }
  }

  void likeCurrentQuote() {
    final quote = _currentQuote;
    if (quote == null) {
      return;
    }

    setState(() {
      if (!_isFavorite(quote)) {
        favs.add(quote);
      }
      lastQuote = quote;
      _currentQuoteIndex += 1;
    });

    _persistFavorites();
    _persistLastQuote(quote);
  }

  void rejectCurrentQuote() {
    final quote = _currentQuote;
    if (quote == null) {
      return;
    }

    setState(() {
      lastQuote = quote;
      _currentQuoteIndex += 1;
    });

    _persistLastQuote(quote);
  }

  bool removeFav(Quote quote) {
    final hadQuote = favs.any((x) => x.text == quote.text);
    if (!hadQuote) {
      return false;
    }

    setState(() => favs.removeWhere((x) => x.text == quote.text));
    _persistFavorites();
    return true;
  }

  bool _isFavorite(Quote quote) => favs.any((x) => x.text == quote.text);

  @override
  Widget build(BuildContext context) {
    final favoriteCount = favs.length;

    final pages = [
      HomePage(
        quotes: _queuedQuotes,
        isLoading: isLoading,
        isCurrentFavorite: _currentQuote != null && _isFavorite(_currentQuote!),
        lastQuote: lastQuote,
        onLikeCurrent: likeCurrentQuote,
        onRejectCurrent: rejectCurrentQuote,
        onReload: loadQuotes,
      ),
      FavoritesPage(favs: favs, onRemove: removeFav),
      const AboutPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF070D26),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Panse',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFF1E2748)),
        ),
      ),
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF070D26),
          border: Border(top: BorderSide(color: Color(0xFF1E2748))),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (value) => setState(() => index = value),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF7D85A9),
          selectedFontSize: 14,
          unselectedFontSize: 13,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Remix.home_3_line),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _FavoritesNavIcon(
                count: favoriteCount,
                isActive: false,
              ),
              activeIcon: _FavoritesNavIcon(
                count: favoriteCount,
                isActive: true,
              ),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.information_line),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesNavIcon extends StatelessWidget {
  final int count;
  final bool isActive;

  const _FavoritesNavIcon({
    required this.count,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = count > 0;
    final badgeText = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Remix.heart_3_fill : Remix.heart_3_line),
        if (showBadge)
          Positioned(
            right: -11,
            top: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppPalette.save,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: const Color(0xFF070D26),
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Quote> quotes;
  final bool isLoading;
  final bool isCurrentFavorite;
  final Quote? lastQuote;
  final VoidCallback onLikeCurrent;
  final VoidCallback onRejectCurrent;
  final Future<void> Function() onReload;

  const HomePage({
    super.key,
    required this.quotes,
    required this.isLoading,
    required this.isCurrentFavorite,
    required this.lastQuote,
    required this.onLikeCurrent,
    required this.onRejectCurrent,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _HomeBackground(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (quotes.isEmpty) {
      return _HomeBackground(
        child: _EmptyHomeCard(lastQuote: lastQuote, onReload: onReload),
      );
    }

    return _HomeBackground(
      child: _QuoteDeckPanel(
        quotes: quotes,
        isCurrentFavorite: isCurrentFavorite,
        onRejectCurrent: onRejectCurrent,
        onLikeCurrent: onLikeCurrent,
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  final Widget child;

  const _HomeBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.18,
          colors: [Color(0xFF151D3C), AppPalette.canvas],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteDeckPanel extends StatelessWidget {
  final List<Quote> quotes;
  final bool isCurrentFavorite;
  final VoidCallback onRejectCurrent;
  final VoidCallback onLikeCurrent;

  const _QuoteDeckPanel({
    required this.quotes,
    required this.isCurrentFavorite,
    required this.onRejectCurrent,
    required this.onLikeCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final visibleLayers = quotes.length >= 3 ? 3 : quotes.length;

    return SizedBox(
      height: 560,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int depth = visibleLayers - 1; depth > 0; depth--)
            Positioned(
              left: (depth * 10).toDouble(),
              right: (depth * 10).toDouble(),
              top: (depth * 18).toDouble(),
              bottom: -(depth * 14).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.cardBack,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: AppPalette.cardBorder, width: 2),
                ),
              ),
            ),
          Positioned.fill(
            child: _FrontQuoteCard(
              quote: quotes.first,
              remainingCount: quotes.length,
              isCurrentFavorite: isCurrentFavorite,
              onRejectCurrent: onRejectCurrent,
              onLikeCurrent: onLikeCurrent,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontQuoteCard extends StatelessWidget {
  final Quote quote;
  final int remainingCount;
  final bool isCurrentFavorite;
  final VoidCallback onRejectCurrent;
  final VoidCallback onLikeCurrent;

  const _FrontQuoteCard({
    required this.quote,
    required this.remainingCount,
    required this.isCurrentFavorite,
    required this.onRejectCurrent,
    required this.onLikeCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final quoteFontSize = quote.text.length > 110
        ? 24.0
        : quote.text.length > 70
        ? 27.0
        : 31.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppPalette.card,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppPalette.cardBorder, width: 2.2),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          child: Column(
            children: [
              const _PredictionBadge(),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '"${quote.text}"',
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: quoteFontSize,
                          height: 1.17,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        quote.author,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _MainActionButton(
                      label: 'Dismiss',
                      icon: Remix.close_line,
                      iconColor: AppPalette.dismiss,
                      onPressed: onRejectCurrent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MainActionButton(
                      label: 'Save',
                      icon: isCurrentFavorite
                          ? Remix.heart_3_fill
                          : Remix.heart_3_line,
                      iconColor: AppPalette.save,
                      onPressed: onLikeCurrent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          right: -8,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF474F6D),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2C3454), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$remainingCount',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _PredictionBadge extends StatelessWidget {
  const _PredictionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Citation du jour sur Panse',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            Icon(Remix.chat_quote_line, color: Colors.black, size: 16),
          ],
        ),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _MainActionButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPressed,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: AppPalette.button,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x36000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  final Quote? lastQuote;
  final Future<void> Function() onReload;

  const _EmptyHomeCard({required this.lastQuote, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppPalette.cardBorder, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Toutes les citations sont passees.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recharge pour recevoir un nouveau lot.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textMuted),
          ),
          if (lastQuote != null) ...[
            const SizedBox(height: 20),
            Text(
              'Derniere citation:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"${lastQuote!.text}"',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              lastQuote!.author,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: _MainActionButton(
              label: 'Reload',
              icon: Remix.refresh_line,
              iconColor: AppPalette.save,
              onPressed: () {
                onReload();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final List<Quote> favs;
  final bool Function(Quote) onRemove;

  const FavoritesPage({super.key, required this.favs, required this.onRemove});

  Future<void> _confirmRemove(BuildContext context, Quote quote) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171D38),
              title: const Text('Supprimer'),
              content: const Text('Tu veux supprimer cette citation des favoris ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.dismiss,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!shouldDelete) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Suppression annulee.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final removed = onRemove(quote);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed ? 'Citation supprimee.' : 'Citation deja supprimee.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (favs.isEmpty) {
      return const _DarkPage(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Remix.heart_3_line, size: 44, color: AppPalette.textMuted),
              SizedBox(height: 12),
              Text('Aucun favori pour le moment.'),
            ],
          ),
        ),
      );
    }

    return _DarkPage(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: favs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final quote = favs[index];
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF171D38),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.cardBorder),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${quote.text}"',
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  quote.author,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _confirmRemove(context, quote),
                    icon: const Icon(
                      Remix.close_line,
                      color: AppPalette.dismiss,
                    ),
                    label: const Text('Retirer'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
    return _DarkPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF171D38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panse',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text('Aplikasyon motivasyon pou ranfose lespri ou chak jou.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._images.map(
            (imagePath) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF171D38),
                    padding: const EdgeInsets.symmetric(vertical: 34),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Remix.image_line),
                        SizedBox(width: 8),
                        Text('Image introuvable'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF171D38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.cardBorder),
            ),
            padding: const EdgeInsets.all(14),
            child: const Text(_aboutText),
          ),
        ],
      ),
    );
  }
}

class _DarkPage extends StatelessWidget {
  final Widget child;

  const _DarkPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.8),
          radius: 1.2,
          colors: [Color(0xFF131A36), AppPalette.canvas],
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
