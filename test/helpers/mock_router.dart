import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Creates a mock GoRouter for testing navigation
///
/// Parameters:
/// - [initialLocation]: The initial route to navigate to (default: '/')
///
/// Returns a GoRouter instance with a simple route structure for testing
GoRouter createMockRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: '/login',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Login'))),
      ),
      GoRoute(
        path: '/feed',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Feed'))),
      ),
      GoRoute(
        path: '/post/:id',
        builder:
            (context, state) => Scaffold(
              body: Center(child: Text('Post ${state.pathParameters['id']}')),
            ),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder:
            (context, state) => Scaffold(
              body: Center(
                child: Text('Profile ${state.pathParameters['userId']}'),
              ),
            ),
      ),
      GoRoute(
        path: '/settings',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Settings'))),
      ),
      GoRoute(
        path: '/settings/profile',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Edit Profile'))),
      ),
      GoRoute(
        path: '/settings/room/:roomId/permissions',
        builder:
            (context, state) => Scaffold(
              body: Center(
                child: Text(
                  'Room Permissions ${state.pathParameters['roomId']}',
                ),
              ),
            ),
      ),
      GoRoute(
        path: '/settings/security',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Security'))),
      ),
    ],
  );
}
