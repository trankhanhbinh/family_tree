import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/person/ui/add_child_screen.dart';
import 'package:familytree/features/person/ui/add_spouse_screen.dart';
import 'package:familytree/features/person/ui/marriage_edit_screen.dart';
import 'package:familytree/features/person/ui/person_edit_screen.dart';
import 'package:familytree/features/person/ui/person_screen.dart';
import 'package:familytree/features/person/ui/relation_type_screen.dart';
import 'package:familytree/features/person/ui/relations_screen.dart';
import 'package:familytree/features/person/ui/remove_screens.dart';
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
      GoRoute(
        path: '/person/:id/edit',
        builder: (context, state) =>
            PersonEditScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id/add-child',
        builder: (context, state) =>
            AddChildScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id/add-spouse',
        builder: (context, state) =>
            AddSpouseScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id/relations',
        builder: (context, state) =>
            RelationsScreen(personId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/person/:id/relations/type/:childId',
        builder: (context, state) =>
            RelationTypeScreen(childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/person/:id/relations/remove/:linkId',
        builder: (context, state) =>
            RemoveParentChildScreen(linkId: state.pathParameters['linkId']!),
      ),
      GoRoute(
        path: '/person/:id/marriage/:marriageId',
        builder: (context, state) =>
            MarriageEditScreen(marriageId: state.pathParameters['marriageId']!),
      ),
      GoRoute(
        path: '/person/:id/marriage/:marriageId/remove',
        builder: (context, state) => RemoveMarriageScreen(
          marriageId: state.pathParameters['marriageId']!,
        ),
      ),
      GoRoute(
        path: '/person/:id/delete',
        builder: (context, state) =>
            DeletePersonScreen(personId: state.pathParameters['id']!),
      ),
    ],
  );
});