import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home/home_bloc.dart';
import '../widgets/content_carousel.dart';
import '../widgets/category_row.dart';
import '../widgets/featured_hero_banner.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../domain/entities/content.dart';
import '../../core/config/constants.dart';
import 'video_player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  int _selectedNavIndex = 0;
  double _scrollOffset = 0.0;

  final List<String> _categories = [
    'الرئيسية',
    'أفلام',
    'مسلسلات',
    'رياضة',
    'البث المباشر',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: true,
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return _buildLoadingState();
          } else if (state is HomeLoaded) {
            return _buildLoadedState(state);
          } else if (state is HomeError) {
            return _buildErrorState(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري التحميل...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<HomeBloc>().add(LoadHomeContent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(HomeLoaded state) {
    final featured = state.featuredContent;
    if (featured.isEmpty) {
      return _buildLoadedStateWithPlaceholder(state);
    }
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: FeaturedHeroBanner(
                content: featured.first,
                onPlay: () => _navigateToPlayer(featured.first),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _GlassmorphicAppBarDelegate(
                minHeight: 100,
                maxHeight: 100,
                scrollOffset: _scrollOffset,
                tabController: _tabController,
                categories: _categories,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHomeTab(state),
                    _buildMoviesTab(state),
                    _buildSeriesTab(state),
                    _buildSportsTab(state),
                    _buildLiveTab(state),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedStateWithPlaceholder(HomeLoaded state) {
    final placeholder = state.trendingContent.isNotEmpty
        ? state.trendingContent.first
        : _createPlaceholderContent();
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: FeaturedHeroBanner(
                content: placeholder,
                onPlay: () => _navigateToPlayer(placeholder),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _GlassmorphicAppBarDelegate(
                minHeight: 100,
                maxHeight: 100,
                scrollOffset: _scrollOffset,
                tabController: _tabController,
                categories: _categories,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHomeTab(state),
                    _buildMoviesTab(state),
                    _buildSeriesTab(state),
                    _buildSportsTab(state),
                    _buildLiveTab(state),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Content _createPlaceholderContent() {
    return const Content(
      id: 'placeholder',
      title: 'محتوى تجريبي',
      description: 'محتوى تجريبي غير متوفر من Firebase Remote Config.',
      posterUrl: 'https://via.placeholder.com/800x450',
      streamingUrls: [],
    );
  }

  Widget _buildHomeTab(HomeLoaded state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          CategoryRow(
            title: 'الأكثر مشاهدة',
            titleColor: const Color(0xFFFF6B00),
            items: state.trendingContent,
            onItemTap: _navigateToPlayer,
            itemHeight: 180,
          ),

          const SizedBox(height: 32),

          CategoryRow(
            title: 'تابع المشاهدة',
            items: state.continueWatching,
            onItemTap: _navigateToPlayer,
            showProgress: true,
          ),

          const SizedBox(height: 32),

          CategoryRow(
            title: 'إصدارات جديدة',
            items: state.newReleases,
            onItemTap: _navigateToPlayer,
          ),

          const SizedBox(height: 32),

          CategoryRow(
            title: 'موصى به لك',
            items: state.recommended,
            onItemTap: _navigateToPlayer,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMoviesTab(HomeLoaded state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          CategoryRow(
            title: 'أفلام نوستالجيا',
            items: state.movies.where((m) => (m.year ?? 0) < 2010).toList(),
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 32),
          CategoryRow(
            title: 'أفلام الأكشن',
            items: state.movies
                .where((m) => m.genres.contains('Action'))
                .toList(),
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSeriesTab(HomeLoaded state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          CategoryRow(
            title: 'مسلسلات مصرية',
            items: state.series
                .where((s) => s.contentType == 'egyptian')
                .toList(),
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 32),
          CategoryRow(
            title: 'مسلسلات قصيرة',
            items: state.series
                .where((s) => (s.totalEpisodes ?? 0) < 30)
                .toList(),
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSportsTab(HomeLoaded state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          CategoryRow(
            title: 'مباريات قادمة - كرة القدم',
            items: state.sportsContent,
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 32),
          CategoryRow(
            title: 'بطولة أستراليا المفتوحة للتنس',
            items: state.sportsContent,
            onItemTap: _navigateToPlayer,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLiveTab(HomeLoaded state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          CategoryRow(
            title: 'البث المباشر - رياضات متعددة',
            items: state.liveContent,
            onItemTap: _navigateToPlayer,
            isLive: true,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _navigateToPlayer(Content content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(content: content),
      ),
    );
  }
}

// Custom SliverPersistentHeaderDelegate for Glassmorphic App Bar
class _GlassmorphicAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final double scrollOffset;
  final TabController tabController;
  final List<String> categories;

  _GlassmorphicAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.scrollOffset,
    required this.tabController,
    required this.categories,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final opacity = (scrollOffset / 300).clamp(0.0, 1.0);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: opacity * 10,
          sigmaY: opacity * 10,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3 + (opacity * 0.5)),
                Colors.black.withOpacity(0.1 + (opacity * 0.3)),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      Image.asset(
                        AppConstants.appLogo,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          'TOTV+',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B00),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined,
                                color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle,
                                color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFFFF6B00),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFFF6B00),
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: categories.map((cat) => Tab(text: cat)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
