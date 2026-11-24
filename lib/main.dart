import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/movie_model.dart';
import 'services/tmdb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TmdbApp());
}

class TmdbApp extends StatelessWidget {
  const TmdbApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CineTrack TMDB',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF01B4E4),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B1118),
        ),
        home: const UpcomingScreen(),
      );
}

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});
  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  final TmdbService api = TmdbService();
  static const storage = FlutterSecureStorage();

  List<Movie> movies = [];
  List<Movie> favoriteMovies = [];
  List<Movie> ratedMovies = [];
  final Set<int> favorites = {};
  final Set<int> busy = {};

  String? sessionId;
  int? accountId;
  String? upcomingError, favoritesError, ratedError;
  bool upcomingLoading = true, favoritesLoading = false, ratedLoading = false;
  bool authLoading = false;
  int selectedTab = 0;

  bool get authenticated => sessionId != null && accountId != null;

  @override
  void initState() {
    super.initState();
    loadMovies();
    restoreSession();
  }

  String clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  void feedback(String text, {bool failed = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: failed ? Colors.red.shade800 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> restoreSession() async {
    try {
      final s = await storage.read(key: 'tmdb_session_id');
      final a = await storage.read(key: 'tmdb_account_id');
      if (!mounted) return;
      setState(() {
        sessionId = s;
        accountId = int.tryParse(a ?? '');
      });
      if (authenticated) await refreshAccountLists();
    } catch (e) {
      feedback('Não foi possível recuperar a sessão: ${clean(e)}', failed: true);
    }
  }

  Future<void> loadMovies() async {
    setState(() {
      upcomingLoading = true;
      upcomingError = null;
    });
    try {
      final data = await api.getUpcomingMovies();
      if (mounted) setState(() => movies = data);
    } catch (e) {
      if (mounted) setState(() => upcomingError = clean(e));
    } finally {
      if (mounted) setState(() => upcomingLoading = false);
    }
  }

  Future<void> loadFavoriteMovies() async {
    if (!authenticated) return;
    setState(() {
      favoritesLoading = true;
      favoritesError = null;
    });
    try {
      final data = await api.getFavoriteMovies(accountId: accountId!, sessionId: sessionId!);
      if (!mounted) return;
      setState(() {
        favoriteMovies = data;
        favorites
          ..clear()
          ..addAll(data.map((m) => m.id));
      });
    } catch (e) {
      if (mounted) setState(() => favoritesError = clean(e));
    } finally {
      if (mounted) setState(() => favoritesLoading = false);
    }
  }

  Future<void> loadRatedMovies() async {
    if (!authenticated) return;
    setState(() {
      ratedLoading = true;
      ratedError = null;
    });
    try {
      final data = await api.getRatedMovies(accountId: accountId!, sessionId: sessionId!);
      if (mounted) setState(() => ratedMovies = data);
    } catch (e) {
      if (mounted) setState(() => ratedError = clean(e));
    } finally {
      if (mounted) setState(() => ratedLoading = false);
    }
  }

  Future<void> refreshAccountLists() async {
    if (!authenticated) return;
    await Future.wait([loadFavoriteMovies(), loadRatedMovies()]);
  }

  Future<void> login() async {
    if (!api.hasToken) {
      feedback('Configure TMDB_ACCESS_TOKEN para autenticar.', failed: true);
      return;
    }
    setState(() => authLoading = true);
    try {
      final requestToken = await api.createRequestToken();
      final uri = Uri.parse(
        'https://www.themoviedb.org/authenticate/$requestToken?redirect_to=https://www.themoviedb.org/',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Não foi possível abrir a autorização no navegador.');
      }
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Autorizar conta TMDB'),
          content: const Text(
            'No navegador, entre na sua conta TMDB e aprove o acesso. Depois volte aqui e toque em “Já autorizei”.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Já autorizei')),
          ],
        ),
      );
      if (approved != true) return;
      final s = await api.createSessionId(requestToken);
      final a = await api.getAccountId(s);
      await storage.write(key: 'tmdb_session_id', value: s);
      await storage.write(key: 'tmdb_account_id', value: '$a');
      if (!mounted) return;
      setState(() {
        sessionId = s;
        accountId = a;
      });
      await refreshAccountLists();
      feedback('Conta TMDB conectada!');
    } catch (e) {
      feedback(clean(e), failed: true);
    } finally {
      if (mounted) setState(() => authLoading = false);
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'tmdb_session_id');
    await storage.delete(key: 'tmdb_account_id');
    if (!mounted) return;
    setState(() {
      sessionId = null;
      accountId = null;
      favorites.clear();
      favoriteMovies.clear();
      ratedMovies.clear();
      selectedTab = 0;
    });
    feedback('Sessão removida deste dispositivo.');
  }

  Future<void> toggleFavorite(Movie movie) async {
    if (!authenticated) {
      feedback('Conecte sua conta TMDB para favoritar.', failed: true);
      return;
    }
    final next = !favorites.contains(movie.id);
    setState(() => busy.add(movie.id));
    try {
      final ok = await api.markAsFavorite(
        accountId: accountId!,
        sessionId: sessionId!,
        movieId: movie.id,
        favorite: next,
      );
      if (!ok) throw Exception('O TMDB não confirmou a operação.');
      if (!mounted) return;
      setState(() {
        if (next) {
          favorites.add(movie.id);
          if (!favoriteMovies.any((m) => m.id == movie.id)) favoriteMovies.insert(0, movie);
        } else {
          favorites.remove(movie.id);
          favoriteMovies.removeWhere((m) => m.id == movie.id);
        }
      });
      feedback(next ? 'Adicionado aos favoritos.' : 'Removido dos favoritos.');
    } catch (e) {
      feedback(clean(e), failed: true);
    } finally {
      if (mounted) setState(() => busy.remove(movie.id));
    }
  }

  Future<void> rate(Movie movie) async {
    if (!authenticated) {
      feedback('Conecte sua conta TMDB para avaliar.', failed: true);
      return;
    }
    double value = 8;
    final selected = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Avaliar ${movie.title}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${value.toStringAsFixed(1)} / 10'),
            Slider(
              min: .5,
              max: 10,
              divisions: 19,
              value: value,
              label: value.toStringAsFixed(1),
              onChanged: (v) => setDialog(() => value = v),
            ),
            const Text('Notas de 0,5 a 10,0 em intervalos de 0,5.'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('Enviar nota')),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => busy.add(movie.id));
    try {
      if (!await api.rateMovie(movieId: movie.id, sessionId: sessionId!, rating: selected)) {
        throw Exception('O TMDB não confirmou a avaliação.');
      }
      await loadRatedMovies();
      feedback('Nota ${selected.toStringAsFixed(1)} enviada!');
    } catch (e) {
      feedback(clean(e), failed: true);
    } finally {
      if (mounted) setState(() => busy.remove(movie.id));
    }
  }

  Future<void> deleteRating(Movie movie) async {
    if (!authenticated) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover avaliação?'),
        content: Text('Deseja remover sua avaliação de “${movie.title}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover avaliação'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => busy.add(movie.id));
    try {
      if (!await api.deleteRating(movieId: movie.id, sessionId: sessionId!)) {
        throw Exception('O TMDB não confirmou a remoção.');
      }
      if (mounted) setState(() => ratedMovies.removeWhere((m) => m.id == movie.id));
      feedback('Avaliação removida.');
    } catch (e) {
      feedback(clean(e), failed: true);
    } finally {
      if (mounted) setState(() => busy.remove(movie.id));
    }
  }

  String date(DateTime? d) => d == null
      ? 'Data não informada'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> refreshCurrentTab() async {
    if (selectedTab == 0) return loadMovies();
    if (!authenticated) return;
    if (selectedTab == 1) return loadFavoriteMovies();
    return loadRatedMovies();
  }

  Widget _statusMessage({required bool loading, required String? error, required String emptyText, required Future<void> Function() retry}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 44),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ]),
      ));
    }
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.movie_filter_outlined, size: 48, color: Colors.white54),
        const SizedBox(height: 12),
        Text(emptyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      ]),
    ));
  }

  Widget _movieCard(Movie movie, {required bool showRating, required bool allowDeleteRating}) {
    final isFavorite = favorites.contains(movie.id);
    final waiting = busy.contains(movie.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 100,
              height: 150,
              child: movie.posterUrl == null
                  ? const ColoredBox(color: Colors.white10, child: Icon(Icons.movie))
                  : Image.network(movie.posterUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.white10, child: Icon(Icons.broken_image))),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_month, size: 15, color: Color(0xFF01B4E4)),
              const SizedBox(width: 5),
              Text(date(movie.releaseDate), style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
            if (movie.voteAverage > 0)
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                const Icon(Icons.star, size: 15, color: Colors.amber),
                const SizedBox(width: 4),
                Text('TMDB ${movie.voteAverage.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
              ])),
            if (showRating && movie.userRating != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                const Icon(Icons.person, size: 15, color: Color(0xFF01B4E4)),
                const SizedBox(width: 4),
                Text('Minha nota: ${movie.userRating!.toStringAsFixed(1)} / 10',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF65D8F5), fontSize: 12)),
              ])),
            const SizedBox(height: 7),
            Text(movie.overview.isEmpty ? 'Sinopse não disponível.' : movie.overview,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3)),
            const SizedBox(height: 4),
            Wrap(spacing: 2, children: [
              IconButton(
                tooltip: isFavorite ? 'Remover favorito' : 'Adicionar favorito',
                visualDensity: VisualDensity.compact,
                onPressed: waiting ? null : () => toggleFavorite(movie),
                icon: waiting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.redAccent : null),
              ),
              if (!showRating)
                IconButton(
                  tooltip: 'Avaliar filme',
                  visualDensity: VisualDensity.compact,
                  onPressed: waiting ? null : () => rate(movie),
                  icon: const Icon(Icons.star_rate),
                ),
              if (allowDeleteRating)
                IconButton(
                  tooltip: 'Remover avaliação',
                  visualDensity: VisualDensity.compact,
                  onPressed: waiting ? null : () => deleteRating(movie),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildUpcoming() {
    if (upcomingLoading) return const Center(child: CircularProgressIndicator());
    if (upcomingError != null) {
      return _statusMessage(loading: false, error: upcomingError, emptyText: '', retry: loadMovies);
    }
    if (movies.isEmpty) {
      return _statusMessage(loading: false, error: null, emptyText: 'Nenhum próximo lançamento encontrado.', retry: loadMovies);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      itemCount: movies.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('O que vem por aí?', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('Próximos lançamentos de filmes', style: TextStyle(color: Colors.white70)),
          ]),
        );
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: _movieCard(movies[index - 1], showRating: false, allowDeleteRating: false));
      },
    );
  }

  Widget _buildAccountList({required List<Movie> list, required bool loading, required String? error,
      required String emptyText, required bool showRating, required bool allowDelete, required Future<void> Function() retry}) {
    if (!authenticated) {
      return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outline, size: 48, color: Colors.white54),
        const SizedBox(height: 12),
        const Text('Conecte sua conta TMDB para acessar esta área.', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: authLoading ? null : login, icon: const Icon(Icons.login), label: const Text('Conectar TMDB')),
      ])));
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _statusMessage(loading: false, error: error, emptyText: '', retry: retry);
    if (list.isEmpty) return _statusMessage(loading: false, error: null, emptyText: emptyText, retry: retry);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      itemCount: list.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _movieCard(list[index], showRating: showRating, allowDeleteRating: allowDelete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.movie_filter, color: Color(0xFF01B4E4)),
            SizedBox(width: 9),
            Text('CineTrack'),
          ]),
          actions: [
            if (authenticated)
              IconButton(tooltip: 'Desconectar', onPressed: logout, icon: const Icon(Icons.logout))
            else
              TextButton.icon(
                onPressed: authLoading ? null : login,
                icon: authLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Conectar TMDB'),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          if (selectedTab != 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: authenticated ? Colors.green.withValues(alpha: .10) : Colors.white.withValues(alpha: .05),
              child: Row(children: [
                Icon(authenticated ? Icons.verified_user : Icons.lock_outline,
                    color: authenticated ? Colors.greenAccent : Colors.white70, size: 18),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  authenticated ? 'Conta TMDB conectada' : 'Conecte sua conta para sincronizar seus dados',
                  style: const TextStyle(fontSize: 12),
                )),
              ]),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshCurrentTab,
              child: selectedTab == 0
                  ? _buildUpcoming()
                  : selectedTab == 1
                      ? _buildAccountList(
                          list: favoriteMovies,
                          loading: favoritesLoading,
                          error: favoritesError,
                          emptyText: 'Você ainda não adicionou filmes aos favoritos.',
                          showRating: false,
                          allowDelete: false,
                          retry: loadFavoriteMovies,
                        )
                      : _buildAccountList(
                          list: ratedMovies,
                          loading: ratedLoading,
                          error: ratedError,
                          emptyText: 'Você ainda não avaliou nenhum filme.',
                          showRating: true,
                          allowDelete: true,
                          retry: loadRatedMovies,
                        ),
            ),
          ),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (index) {
            setState(() => selectedTab = index);
            if (index == 1 && authenticated && favoriteMovies.isEmpty && !favoritesLoading) loadFavoriteMovies();
            if (index == 2 && authenticated && ratedMovies.isEmpty && !ratedLoading) loadRatedMovies();
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.upcoming_outlined), selectedIcon: Icon(Icons.upcoming), label: 'Lançamentos'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
            NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star), label: 'Avaliações'),
          ],
        ),
      );
}
