import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/person/ui/person_screen.dart';
import 'package:familytree/features/tree/ui/search_screen.dart';
import 'package:familytree/features/tree/ui/splash_screen.dart';
import 'package:familytree/features/tree/ui/tree_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const TreeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (context, state) =>
            PersonScreen(personId: state.pathParameters['id']!),
      ),
    ],
  );
});