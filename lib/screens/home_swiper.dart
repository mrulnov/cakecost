// lib/screens/home_swiper.dart
import 'package:flutter/material.dart';

import '../screens/ingredients_screen.dart';
import '../screens/packaging_screen.dart';
import '../screens/subrecipes_screen.dart';
import '../screens/resources_screen.dart';
import '../screens/recipes_screen.dart';
import '../screens/assortment_screen.dart';
import '../screens/scale_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/export_screen.dart';
import '../screens/settings_help_screen.dart'; // NEW

class HomeSwiper extends StatefulWidget {
  const HomeSwiper({Key? key}) : super(key: key);

  @override
  State<HomeSwiper> createState() => _HomeSwiperState();
}

class _HomeSwiperState extends State<HomeSwiper>
    with SingleTickerProviderStateMixin {
  static const double _kParallax = 36.0;

  final PageController _pageCtrl = PageController();
  double _page = 0;

  late final AnimationController _pulseCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  late final List<_Item> _items = <_Item>[
    _Item('Ингредиенты', 'lib/assets/home/ingredients.png',
        () => const IngredientsScreen()),
    _Item('Упаковка', 'lib/assets/home/packaging.png',
        () => const PackagingScreen()),
    _Item('Субрецепты', 'lib/assets/home/subrecipes.png',
        () => const SubrecipesScreen()),
    _Item('Ресурсы', 'lib/assets/home/resources.png',
        () => const ResourcesScreen()),
    _Item('Рецепты', 'lib/assets/home/recipes.png',
        () => const RecipesScreen()),
    _Item('Ассортимент', 'lib/assets/home/assortment.png',
        () => const AssortmentScreen()),
    _Item('Пересчёт форм', 'lib/assets/home/scale.png',
        () => const ScaleScreen()),
    _Item('Бэкап', 'lib/assets/home/backup.png', () => const BackupScreen()),
    _Item('Экспорт', 'lib/assets/home/export.png', () => const ExportScreen()),
    _Item('Настройки и помощь', 'lib/assets/home/helper.png',
        () => const SettingsHelpScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      setState(() => _page = _pageCtrl.page ?? 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final it in _items) {
      precacheImage(AssetImage(it.asset), context);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _page.round().clamp(0, _items.length - 1);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.85),
                      theme.colorScheme.primary.withOpacity(0.40),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 12),
                Opacity(
                  opacity: 0.72,
                  child: Text(
                    'CAKE&COST',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white,
                      height: 1.1,
                      shadows: const [Shadow(blurRadius: 10, color: Colors.black26)],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _items.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      final dx = (_page - i) * _kParallax;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: _Slide(
                          title: it.title,
                          asset: it.asset,
                          dx: dx,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => it.builder()),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Opacity(
                    opacity: 0.85,
                    child: Text(
                      _items[active].title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                _Dots(count: _items.length, page: _page, pulse: _pulseCtrl),
                const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String title;
  final String asset;
  final double dx;
  final VoidCallback onTap;

  const _Slide({
    Key? key,
    required this.title,
    required this.asset,
    required this.dx,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(dx, 0),
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.45, 1.0],
                colors: [Colors.black45, Colors.black26, Colors.transparent],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              highlightColor: Colors.white.withOpacity(0.06),
              splashColor: Colors.white.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final double page;
  final Animation<double> pulse;

  const _Dots({
    Key? key,
    required this.count,
    required this.page,
    required this.pulse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final active = page.round().clamp(0, count - 1);
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final List<Widget> dots = <Widget>[];
        for (int i = 0; i < count; i++) {
          final bool isActive = i == active;
          final double baseW = isActive ? 24.0 : 8.0;
          final double scale =
              isActive ? (1.0 + (pulse.value - 0.5) * 0.2) : 1.0;

          dots.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: baseW,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: dots,
        );
      },
    );
  }
}

class _Item {
  final String title;
  final String asset;
  final Widget Function() builder;

  _Item(this.title, this.asset, this.builder);
}
