import 'package:matrix/matrix.dart';

import 'matrix_test_setup.dart';

void configureHttpOverridesImpl() {}

void restoreHttpOverridesImpl() {}

Future<MatrixTestDatabase> createMatrixTestDatabaseImpl(String name) async {
  final database = await MatrixSdkDatabase.init(name);
  return MatrixTestDatabase(database, () async {
    await database.close();
  });
}

Future<T> runWithHttpOverridesImpl<T>(Future<T> Function() body) => body();
