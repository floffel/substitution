import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart';

// TODO: this icon picker is not really ideal. It has no translation and will be too big for the screens on wide screens. Fix it or find a new one
mixin MatrixEssentials<T extends StatefulWidget> on State<T> {
  Client get client => Provider.of<Client>(context, listen: false);

  // todo: as soon as macros are released, do things like this:
  // Room? get room => client.getRoomById(widget.roomId);
}
