import 'dart:io' as io;

import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'matrix_test_setup.dart';

io.HttpOverrides? _previousHttpOverrides;

void configureHttpOverridesImpl() {
  _previousHttpOverrides = io.HttpOverrides.current;
  io.HttpOverrides.global = null;
}

void restoreHttpOverridesImpl() {
  io.HttpOverrides.global = _previousHttpOverrides;
}

Future<T> runWithHttpOverridesImpl<T>(Future<T> Function() body) {
  return io.HttpOverrides.runZoned(
    () => body(),
    createHttpClient:
        (_) =>
            io.HttpClient()
              ..badCertificateCallback = (cert, host, port) => true,
  );
}

Future<MatrixTestDatabase> createMatrixTestDatabaseImpl(String name) async {
  if (io.Platform.isLinux || io.Platform.isWindows || io.Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final sqliteDatabase = await openDatabase(inMemoryDatabasePath, version: 1);
  final matrixDatabase = await MatrixSdkDatabase.init(
    name,
    database: sqliteDatabase,
  );

  return MatrixTestDatabase(matrixDatabase, () async {
    await matrixDatabase.close();
    await sqliteDatabase.close();
  });
}
