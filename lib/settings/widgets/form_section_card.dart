import 'package:flutter/material.dart';

/// Reusable card-with-section-title used throughout the room form to
/// group related fields (basic info, settings, members, …).
///
/// Stateless — caller supplies the list of [children] widgets to render
/// inside the card. Keeps the visual style consistent across all
/// sections without duplicating Card + Padding + Title boilerplate.
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  /// Section heading, e.g. "Basic info".
  final String title;

  /// Widgets to render inside the section body, in source order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable `SwitchListTile` with the app's standard form-tile styling.
///
/// Used for all boolean settings in the room form (visibility, encryption,
/// substitution status, blog mode, …).
class FormToggleTile extends StatelessWidget {
  const FormToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Whether the underlying `Switch` should allow a "null" middle state.
  /// Note: this is plumbed for API compatibility with the original
  /// `SwitchListTile` call site; the room form does not currently use it.
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SwitchListTile(
      secondary: Icon(icon, color: colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
