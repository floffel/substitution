import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart';

/// Mixin that gives any [State] a typed `client` getter wired up to the
/// [Provider] tree. Centralizes the boilerplate
/// `Provider.of<Client>(context, listen: false)` so individual
/// settings / write pages don't have to repeat it.
mixin MatrixEssentials<T extends StatefulWidget> on State<T> {
  Client get client => Provider.of<Client>(context, listen: false);

  // Design note: the original matrix_essentials.dart shipped a
  // "make client a mixin" inline TODO plus a "macros are released"
  // musing about a `room` getter that reads `widget.roomId` once
  // compile-time metaprogramming is available. Both are deliberate
  // design observations, not actionable code — the mixin above is
  // the realized version. See CHANGELOG for the history.
}
