import 'theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// ----- Модели (Hive) -----
import 'models/ingredient.dart';
import 'models/packaging.dart';
import 'models/subrecipe_ingredient.dart';
import 'models/subrecipe.dart';
import 'models/resource.dart';
import 'models/recipe_item.dart';
import 'models/recipe.dart';
import 'models/assortment_item.dart';

// ----- Провайдеры -----
import 'providers/ingredient_provider.dart';
import 'providers/packaging_provider.dart';
import 'providers/subrecipe_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/assortment_provider.dart';

// ----- Экраны -----
import 'screens/ingredients_screen.dart';
import 'screens/packaging_screen.dart';
import 'screens/subrecipes_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/assortment_screen.dart';
import 'screens/scale_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_help_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ВАЖНО: провайдеры оборачивают весь MaterialApp (над Navigator)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
        ChangeNotifierProvider(create: (_) => PackagingProvider()),
        ChangeNotifierProvider(create: (_) => SubrecipeProvider()),
        ChangeNotifierProvider(create: (_) => ResourceProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => AssortmentProvider()),
      ],
      child: const CakeCostApp(),
    ),
  );
}

class CakeCostApp extends StatelessWidget {
  const CakeCostApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cake&Cost',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _BootstrapScreen(), // загрузочный экран
    );
  }
}

/// ------------------------------------------------------------
/// Загрузочный экран: гладкий фон + КРУПНЫЙ логотип с шиммером.
/// После инициализации + 3 перелива — мягкий cross-fade в HomeSwiper.
/// ------------------------------------------------------------
class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen({Key? key}) : super(key: key);

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen>
    with SingleTickerProviderStateMixin {
  static const int _kMinShimmerCycles = 3;

  bool _ready = false;
  bool _bootstrapDone = false;
  bool _minCyclesDone = false;

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // стартуем инициализацию после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBootstrap());

    // параллельно запускаем «таймер» на 3 цикла шиммера
    _waitShimmerCycles();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _maybeProceed() {
    if (!_ready && _bootstrapDone && _minCyclesDone && mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _waitShimmerCycles() async {
    final period = _shimmerCtrl.duration ?? const Duration(milliseconds: 1600);
    final total = Duration(milliseconds: period.inMilliseconds * _kMinShimmerCycles);
    await Future.delayed(total);
    if (!mounted) return;
    setState(() => _minCyclesDone = true);
    _maybeProceed();
  }

  Future<void> _runBootstrap() async {
    // Инициализация (Hive)
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);

    void safeRegister<T>(TypeAdapter<T> adapter) {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter<T>(adapter);
      }
    }

    safeRegister<Ingredient>(IngredientAdapter());
    safeRegister<Packaging>(PackagingAdapter());
    safeRegister<SubrecipeIngredient>(SubrecipeIngredientAdapter());
    safeRegister<Subrecipe>(SubrecipeAdapter());
    safeRegister<Resource>(ResourceAdapter());
    safeRegister<RecipeItemKind>(RecipeItemKindAdapter());
    safeRegister<RecipeItem>(RecipeItemAdapter());
    safeRegister<Recipe>(RecipeAdapter());
    safeRegister<AssortmentItem>(AssortmentItemAdapter());

    await Hive.openBox<Ingredient>('ingredients');
    await Hive.openBox<Packaging>('packaging');
    await Hive.openBox<Subrecipe>('subrecipes');
    await Hive.openBox<Resource>('resources');
    await Hive.openBox<Recipe>('recipes');
    await Hive.openBox<AssortmentItem>('assortment');

    // Прекэш фоновых карт — необязательно, но приятно
    final homeAssets = <String>[
      'lib/assets/home/ingredients.png',
      'lib/assets/home/packaging.png',
      'lib/assets/home/resources.png',
      'lib/assets/home/subrecipes.png',
      'lib/assets/home/recipes.png',
      'lib/assets/home/assortment.png',
      'lib/assets/home/scale.png',
      'lib/assets/home/backup.png',
      'lib/assets/home/export.png',
      'lib/assets/home/helper.png',
    ];
    for (final a in homeAssets) {
      try {
        await precacheImage(AssetImage(a), context);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _bootstrapDone = true);
    _maybeProceed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: _ready
          ? const HomeSwiper() // провайдеры уже доступны глобально
          : _SplashContent(shimmer: _shimmerCtrl),
    );
  }
}

/// Splash UI: фон + крупный логотип с шиммером
class _SplashContent extends StatelessWidget {
  final AnimationController shimmer;
  const _SplashContent({Key? key, required this.shimmer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const splashTop = Color(0xFF7A1E1E);
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;
    final logoW = shortest.clamp(260.0, 360.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [splashTop, Color(0xFF7A1E1E), Color(0xFF5E1515)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (context, _) {
                final t = shimmer.value;
                return ShaderMask(
                  shaderCallback: (rect) {
                    final w = rect.width;
                    final dx = (t * (w + rect.height)) - rect.height * 0.5;
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.65),
                        Colors.transparent,
                      ],
                      stops: [
                        ((dx - 80) / w).clamp(0.0, 1.0),
                        (dx / w).clamp(0.0, 1.0),
                        ((dx + 80) / w).clamp(0.0, 1.0),
                      ],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcATop,
                  child: Image.asset(
                    'lib/assets/branding/splash_logo.png',
                    width: logoW,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------------
/// Домашний экран: БЕСКОНЕЧНАЯ карусель
/// -------------------------
class HomeSwiper extends StatefulWidget {
  const HomeSwiper({Key? key}) : super(key: key);
  @override
  State<HomeSwiper> createState() => _HomeSwiperState();
}

class _HomeSwiperState extends State<HomeSwiper> {
  static const double _kParallax = 40.0;
  static const int _kInitialLoop = 1000;

  late final PageController _pageC;
  double _page = 0;

  final _items = <_HomeItem>[
    _HomeItem('Ингредиенты', 'lib/assets/home/ingredients.png', const IngredientsScreen()),
    _HomeItem('Упаковка', 'lib/assets/home/packaging.png', const PackagingScreen()),
    _HomeItem('Ресурсы', 'lib/assets/home/resources.png', const ResourcesScreen()),
    _HomeItem('Субрецепты', 'lib/assets/home/subrecipes.png', const SubrecipesScreen()),
    _HomeItem('Рецепты', 'lib/assets/home/recipes.png', const RecipesScreen()),
    _HomeItem('Ассортимент', 'lib/assets/home/assortment.png', const AssortmentScreen()),
    _HomeItem('Пересчёт форм', 'lib/assets/home/scale.png', const ScaleScreen()),
    _HomeItem('Резервное копирование', 'lib/assets/home/backup.png', const BackupScreen()),
    _HomeItem('Экспорт / Импорт', 'lib/assets/home/export.png', const ExportScreen()),
    _HomeItem('Настройки и помощь', 'lib/assets/home/helper.png', const SettingsHelpScreen()),
  ];

  int get _len => _items.length;

  @override
  void initState() {
    super.initState();
    final initialPage = _kInitialLoop * _len;
    _pageC = PageController(initialPage: initialPage);
    _page = initialPage.toDouble();
    _pageC.addListener(() => setState(() => _page = _pageC.page ?? _page));
  }

  @override
  void dispose() {
    _pageC.dispose();
    super.dispose();
  }

  void _openCurrent() {
    final i = _page.round();
    final idx = ((i % _len) + _len) % _len;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _items[idx].screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeGlobal = _page.round();
    final active = ((activeGlobal % _len) + _len) % _len;
    final currentTitle = _items[active].title.toUpperCase();

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageC,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (ctx, i) {
              final idx = ((i % _len) + _len) % _len;
              final it = _items[idx];
              final dx = (_page - i) * _kParallax;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _ParallaxBackground(asset: it.asset, offset: dx.clamp(-60.0, 60.0)),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openCurrent,
                        splashColor: Colors.white.withOpacity(0.06),
                        highlightColor: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
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
                  const Spacer(),
                  SizedBox(
                    height: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: FittedBox(
                        key: ValueKey(currentTitle),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currentTitle,
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white.withOpacity(0.90),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_len, (i) {
                      final isActive = i == active;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 8,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isActive ? 0.9 : 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParallaxBackground extends StatelessWidget {
  final String asset;
  final double offset;
  const _ParallaxBackground({Key? key, required this.asset, required this.offset}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: Offset(offset, 0),
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
              stops: [0.3, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeItem {
  final String title;
  final String asset;
  final Widget screen;
  const _HomeItem(this.title, this.asset, this.screen);
}
