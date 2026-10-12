import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'pages.dart';
import 'stores.dart';
import 'tmdb_service.dart';
import 'widgets.dart';

class TVDashboard extends StatefulWidget {
  final DashboardHooks hooks;
  const TVDashboard({super.key, this.hooks = const DashboardHooks()});

  @override
  State<TVDashboard> createState() => _TVDashboardState();
}

class _TVDashboardState extends State<TVDashboard> {
  static const List<String> _tabs = [
    'HANNU TRENDING',
    'Anime',
    'Movies',
    'Series',
    'Kids',
    'Live TV',
  ];

  final ScrollController _scrollController = ScrollController();
  final FocusScopeNode _focusScopeNode = FocusScopeNode();

  late Future<List<TmdbItem>> _heroFuture;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    Hooks.cfg = widget.hooks;
    WatchlistStore.I.load();
    ContinueWatchingStore.I.load();
    NotificationStore.I.init();
    _heroFuture = Tmdb.I.heroItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    Tmdb.I.clearCache();
    final f = Tmdb.I.heroItems();
    setState(() {
      _epoch++;
      _heroFuture = f;
    });
    await f;
  }

  void _onTabSelected(int index) {
    switch (index) {
      case 0:
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
        break;
      case 1:
        openCategory(context, CategoryKind.anime);
        break;
      case 2:
        openCategory(context, CategoryKind.movies);
        break;
      case 3:
        openCategory(context, CategoryKind.series);
        break;
      case 4:
        openCategory(context, CategoryKind.kids);
        break;
      case 5:
        if (widget.hooks.onOpenLiveTv != null) {
          widget.hooks.onOpenLiveTv!();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: hannuTheme().copyWith(
        focusColor: Colors.white24, // TV remote focus highlight
      ),
      child: Scaffold(
        backgroundColor: HC.bg,
        body: FocusScope(
          node: _focusScopeNode,
          child: Stack(
            children: [
              // Safe Area & Scrollable Content
              SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverList(delegate: SliverChildListDelegate(_buildTVContent())),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTVContent() {
    final List<Widget> content = [
      _buildTVHeader(),
      _buildTVTabs(),
      const SizedBox(height: 20),
      _buildTVHeroSection(),
      const SizedBox(height: 20),
      _buildTVContinueWatching(),
      _buildTVOttSection(),
      
      // Top 10 India TV Row
      TVPosterRow(
        key: ValueKey<String>('tv_india$_epoch'),
        title: 'Top 10 in India',
        ranked: true,
        loader: () => Tmdb.I.topIndia(),
      ),
      
      // Top 10 World TV Row
      TVPosterRow(
        key: ValueKey<String>('tv_world$_epoch'),
        title: 'Top 10 Worldwide',
        ranked: true,
        loader: () => Tmdb.I.topWorld(),
      ),
      
      _buildTVGenreChips(),
    ];

    // Build standard genre rows
    for (int i = 0; i < kDashGenres.length; i++) {
      final g = kDashGenres[i];
      content.add(TVGenreBlock(
        key: ValueKey<String>('tv_${g.key}$_epoch'),
        g: g,
        onSeeAll: () => openGenre(context, g),
      ));
    }
    
    content.add(const SizedBox(height: 60)); // Bottom padding
    return content;
  }

  Widget _buildTVHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 10), // Wider padding for TV
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/logo.png', height: 50, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
          Row(
            children: [
              _buildTVFocusableIcon(Icons.search_rounded, () {
                if (widget.hooks.onOpenSearch != null) {
                  widget.hooks.onOpenSearch!();
                } else {
                  openSearch(context);
                }
              }),
              const SizedBox(width: 15),
              _buildTVFocusableIcon(Icons.bookmark_border_rounded, () => openWatchlist(context)),
              const SizedBox(width: 15),
              _buildTVFocusableIcon(Icons.settings, () => showSupportSheet(context)), 
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTVFocusableIcon(IconData icon, VoidCallback onTap) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isFocused = false;
        return Focus(
          onFocusChange: (focused) => setState(() => isFocused = focused),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFocused ? Colors.white : Colors.transparent,
                border: Border.all(color: isFocused ? Colors.white : Colors.white24, width: 2),
                boxShadow: isFocused ? [const BoxShadow(color: Colors.white54, blurRadius: 10)] : [],
              ),
              child: Icon(icon, size: 30, color: isFocused ? Colors.black : Colors.white),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTVTabs() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (context, i) {
          final bool isDashboard = i == 0;
          return StatefulBuilder(
            builder: (context, setState) {
              bool isFocused = false;
              return Focus(
                onFocusChange: (focused) => setState(() => isFocused = focused),
                child: InkWell(
                  onTap: () => _onTabSelected(i),
                  borderRadius: BorderRadius.circular(30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: isDashboard ? HC.primary : null,
                      color: isFocused 
                          ? Colors.white 
                          : (isDashboard ? null : Colors.white10),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isFocused ? Colors.white : Colors.transparent, width: 2),
                      boxShadow: isFocused ? [const BoxShadow(color: Colors.white54, blurRadius: 10)] : [],
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isFocused 
                            ? Colors.black 
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildTVHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: FutureBuilder<List<TmdbItem>>(
        future: _heroFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox(height: 300, child: HeroSkeleton());
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const SizedBox(height: 300, child: Center(child: Text("Unable to load trending movies", style: TextStyle(color: Colors.white))));
          
          return TVHeroCarousel(items: items);
        },
      ),
    );
  }

  Widget _buildTVContinueWatching() {
     return AnimatedBuilder(
      animation: ContinueWatchingStore.I,
      builder: (context, _) {
        final list = ContinueWatchingStore.I.entries;
        if (list.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 40, bottom: 15),
              child: Text('Continue Watching', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (context, i) {
                  return TVPosterCard(
                    item: list[i].item,
                    progress: list[i].progress,
                    onLongPress: () => ContinueWatchingStore.I.remove(list[i].item),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _buildTVOttSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 40, bottom: 15),
          child: Text('Streaming on', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            itemCount: kOtts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, i) {
              return StatefulBuilder(
                builder: (context, setState) {
                  bool isFocused = false;
                  return Focus(
                    onFocusChange: (focused) => setState(() => isFocused = focused),
                    child: InkWell(
                      onTap: () => openOtt(context, kOtts[i]),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isFocused ? Colors.white : Colors.transparent, width: 3),
                          boxShadow: isFocused ? [const BoxShadow(color: Colors.white54, blurRadius: 10)] : [],
                        ),
                        child: OttLogo(kOtts[i], w: 120, h: 80, radius: 12),
                      ),
                    ),
                  );
                }
              );
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildTVGenreChips() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 40, bottom: 15),
          child: Text('Genres', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            itemCount: kAllGenres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, i) {
              final g = kAllGenres[i];
              return StatefulBuilder(
                builder: (context, setState) {
                  bool isFocused = false;
                  return Focus(
                    onFocusChange: (focused) => setState(() => isFocused = focused),
                    child: InkWell(
                      onTap: () => openGenre(context, g),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(colors: [g.c1, g.c2]),
                          border: Border.all(color: isFocused ? Colors.white : Colors.transparent, width: 3),
                          boxShadow: isFocused ? [const BoxShadow(color: Colors.white54, blurRadius: 10)] : [],
                        ),
                        child: Text(g.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }
              );
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ───────────────────────── TV Custom Widgets ─────────────────────────

class TVPosterRow extends StatefulWidget {
  final String title;
  final Future<List<TmdbItem>> Function() loader;
  final bool ranked;

  const TVPosterRow({super.key, required this.title, required this.loader, this.ranked = false});

  @override
  State<TVPosterRow> createState() => _TVPosterRowState();
}

class _TVPosterRowState extends State<TVPosterRow> {
  late Future<List<TmdbItem>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbItem>>(
      future: _f,
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (snap.connectionState == ConnectionState.done && items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 15),
              child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 250, // Fixed height for TV posters
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                itemCount: snap.connectionState != ConnectionState.done ? 6 : items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (context, i) {
                  if (snap.connectionState != ConnectionState.done) {
                    return ShimmerBox(w: 150, h: 225, r: 12);
                  }
                  return TVPosterCard(item: items[i], rank: widget.ranked ? i + 1 : null);
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

class TVPosterCard extends StatelessWidget {
  final TmdbItem item;
  final int? rank;
  final double? progress;
  final VoidCallback? onLongPress;

  const TVPosterCard({super.key, required this.item, this.rank, this.progress, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isFocused = false;
        return Focus(
          onFocusChange: (focused) => setState(() => isFocused = focused),
          child: InkWell(
            onTap: () => Hooks.open(context, item),
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedScale(
              scale: isFocused ? 1.05 : 1.0, // Scale up on D-pad focus
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isFocused ? Colors.white : Colors.transparent, width: 3),
                  boxShadow: isFocused ? [const BoxShadow(color: Colors.white24, blurRadius: 15, spreadRadius: 2)] : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9), // Inner radius
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PosterImage(item: item, width: 150),
                            if (rank != null)
                              Positioned(
                                left: -5,
                                bottom: -5,
                                child: RankNumber(rank!, size: 100),
                              ),
                            if (progress != null)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(value: progress, backgroundColor: Colors.black54, valueColor: const AlwaysStoppedAnimation<Color>(HC.accent2)),
                              )
                          ],
                        ),
                      ),
                    ),
                    if (isFocused) // Only show title text when focused to keep TV UI clean
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

class TVHeroCarousel extends StatefulWidget {
  final List<TmdbItem> items;
  const TVHeroCarousel({super.key, required this.items});

  @override
  State<TVHeroCarousel> createState() => _TVHeroCarouselState();
}

class _TVHeroCarouselState extends State<TVHeroCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextIndex = (_currentIndex + 1) % widget.items.length;
        _pageController.animateToPage(nextIndex, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final bool isActive = _currentIndex == index;
          
          return StatefulBuilder(
            builder: (context, setStateFocus) {
              bool isFocused = false;
              return Focus(
                onFocusChange: (focused) {
                   setStateFocus(() => isFocused = focused);
                   if(focused && !isActive && _pageController.hasClients){
                      _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.ease);
                   }
                },
                child: AnimatedScale(
                  scale: isActive ? (isFocused ? 1.05 : 1.0) : 0.9,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: () => Hooks.open(context, item),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isFocused ? Colors.white : Colors.transparent, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(item.backdropUrl('w1280')),
                          fit: BoxFit.cover,
                        )
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                          )
                        ),
                        padding: const EdgeInsets.all(30),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          item.title,
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }
}

class TVGenreBlock extends StatelessWidget {
  final GenreDef g;
  final VoidCallback onSeeAll;

  const TVGenreBlock({super.key, required this.g, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 20, bottom: 10),
          child: Text(g.label, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        TVPosterRow(title: 'Movies', loader: () => Tmdb.I.genreRow(g, RowKind.movie)),
        TVPosterRow(title: 'Series', loader: () => Tmdb.I.genreRow(g, RowKind.series)),
      ],
    );
  }
}