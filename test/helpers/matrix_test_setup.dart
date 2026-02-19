import 'package:matrix/matrix.dart';

import 'matrix_test_setup_stub.dart'
    if (dart.library.io) 'matrix_test_setup_io.dart';

class MatrixTestDatabase {
  final MatrixSdkDatabase database;
  final Future<void> Function() _dispose;

  MatrixTestDatabase(this.database, this._dispose);

  Future<void> dispose() => _dispose();
}

void configureHttpOverrides() => configureHttpOverridesImpl();

void restoreHttpOverrides() => restoreHttpOverridesImpl();

Future<MatrixTestDatabase> createMatrixTestDatabase(String name) =>
    createMatrixTestDatabaseImpl(name);

Future<T> runWithHttpOverrides<T>(Future<T> Function() body) =>
    runWithHttpOverridesImpl(body);
