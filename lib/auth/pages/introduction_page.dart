import '/auth/pages/host_page.dart';
import '/auth/pages/login.dart';
import '/shared/widgets/startroom_dialog.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';

/// The first-run / first-login onboarding page shown at `/intro`.
///
/// Walks the user through:
/// 1. A welcome screen
/// 2. Account selection (if not yet created)
/// 3. Homeserver selection (`HostPage`)
/// 4. Login (`LoginPage`)
/// 5. A "you're in" final page with a button that completes onboarding
///
/// If a `?goto=` deep-link destination was preserved by the route guard,
/// the final "Continue to App" button honors it (after validating it via
/// [safeGotoDestination] in the calling route).
class IntroductionPage extends StatefulWidget {
  /// Optional destination to navigate to once the user completes the
  /// introduction / login flow. Set from the `?goto=` query parameter on
  /// the `/intro` route (see [safeGotoDestination] in
  /// `lib/shared/utils/routing_utils.dart`).
  final String? goto;

  const IntroductionPage({super.key, this.goto});

  @override
  State<IntroductionPage> createState() => _IntroductionState();
}

class _IntroductionState extends State<IntroductionPage> {
  late final Client client = Provider.of<Client>(context, listen: false);
  final _introKey = GlobalKey<IntroductionScreenState>();

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      key: _introKey,
      pages: [
        PageViewModel(
          title: "intro.welcome.title".tr(),
          image: Image(
            image: const AssetImage('assets/icon/logo.png'),
            errorBuilder:
                (ctx, err, stack) =>
                    const Icon(Icons.image_not_supported, size: 80),
          ),
          bodyWidget: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: const Text("intro.welcome.desc").tr()),
                ],
              ),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.account.title".tr(),
          bodyWidget: Column(
            //mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text("intro.account.desc").tr(),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.host.title".tr(),
          bodyWidget: Column(
            children: [
              if (client.isLogged()) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text("intro.isLoggedIn").tr(),
              ] else ...[
                HostPage(onComplete: () => {_introKey.currentState?.next()}),
              ],
            ],
          ),
        ),
        PageViewModel(
          title: "intro.login.title".tr(),
          bodyWidget: Column(
            children: [
              if (client.isLogged()) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text("intro.isLoggedIn").tr(),
              ] else
                LoginPage(
                  onComplete: () {
                    _introKey.currentState?.next();
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.finished.title".tr(),
          bodyWidget: Column(
            children: [
              if (!client.isLogged()) ...[
                const Text("intro.isNotLoggedIn").tr(),
              ] else ...[
                const Text("intro.finished.desc").tr(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('introGoButton'),
                    onPressed: () async {
                      final goRouter = GoRouter.of(context);
                      await showStartroomDialog(context, client);
                      if (mounted) {
                        // Honor the `?goto=` deep-link destination if one
                        // was passed (e.g. from a deep link to a room feed).
                        // Falls back to `/` for the normal manual flow.
                        final destination = widget.goto ?? '/';
                        goRouter.go(destination);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text("intro.finished.buttons.go").tr(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      canProgress: (int toPage) {
        if (toPage <= 2) {
          // allow navigation to Welcome, Account, and Host pages
          return true;
        } else if (toPage == 3 &&
            client.homeserver != null &&
            client.homeserver.toString() != "") {
          // only allow navigation to Login page if homeserver is set
          return true;
        } else if (toPage == 4 && client.isLogged()) {
          // only allow navigation to Finished page if logged in
          return true;
        } else {
          return false;
        }
      },
      showNextButton: true,
      showBackButton: true,
      showDoneButton: false,
      next: const Text("intro.buttons.next").tr(),
      back: const Text("intro.buttons.back").tr(),
    );
  }
}
