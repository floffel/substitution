import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class Error404Page extends StatefulWidget {
  const Error404Page({super.key});

  static Error404PageState of(BuildContext context) {
    return context.findAncestorStateOfType<Error404PageState>()!;
  }

  @override
  Error404PageState createState() => Error404PageState();
}

class Error404PageState extends State<Error404Page> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("404"), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '404',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'error_page_not_found'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
