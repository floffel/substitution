import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Represents a parsed SSO identity provider from the Matrix login flows response.
///
/// Corresponds to the `identity_providers` entries in the `m.login.sso` flow:
/// https://spec.matrix.org/v1.7/client-server-api/#get_matrixclientv3login
class SsoProvider {
  const SsoProvider({required this.id, required this.name, this.icon});

  /// The provider ID used in the SSO redirect URL path, e.g. "google", "github".
  final String id;

  /// Human-readable display name, e.g. "Google", "GitHub".
  final String name;

  /// Optional icon as an `mxc://` URI. May be null if the server doesn't supply one.
  final String? icon;

  factory SsoProvider.fromMap(Map<String, Object?> map) {
    return SsoProvider(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
    );
  }
}

/// Holds the login capabilities advertised by the currently selected homeserver.
///
/// Populated by [HostPage] after a successful [Client.checkHomeserver] call and
/// consumed by [LoginPage] to render only the login options the server supports.
class AuthState extends ChangeNotifier {
  List<LoginFlow>? _loginFlows;

  /// The raw login flows returned by the homeserver, or null before
  /// [checkHomeserver] has been called.
  List<LoginFlow>? get loginFlows => _loginFlows;

  /// Updates the login flows and notifies listeners.
  void setLoginFlows(List<LoginFlow> flows) {
    _loginFlows = flows;
    notifyListeners();
  }

  /// Clears all state, e.g. when the user navigates back to pick a different server.
  void clear() {
    _loginFlows = null;
    notifyListeners();
  }

  /// Whether the homeserver supports username/password login (`m.login.password`).
  /// Returns true when flows have not been loaded yet so the form is shown by default.
  bool get hasPasswordFlow {
    if (_loginFlows == null) return true;
    return _loginFlows!.any((f) => f.type == AuthenticationTypes.password);
  }

  /// Parsed list of SSO identity providers from the `m.login.sso` flow.
  /// Returns an empty list if the homeserver does not support SSO.
  List<SsoProvider> get ssoProviders {
    if (_loginFlows == null) return const [];

    final ssoFlow =
        _loginFlows!
            .where((f) => f.type == AuthenticationTypes.sso)
            .firstOrNull;

    if (ssoFlow == null) return const [];

    final rawProviders = ssoFlow.additionalProperties['identity_providers'];
    if (rawProviders == null) {
      // SSO is supported but no individual providers listed — treat as a single
      // unnamed provider so the button is still shown.
      return const [SsoProvider(id: '', name: 'SSO')];
    }

    try {
      return (rawProviders as List)
          .cast<Map<String, Object?>>()
          .map(SsoProvider.fromMap)
          .toList();
    } catch (_) {
      return const [SsoProvider(id: '', name: 'SSO')];
    }
  }
}
