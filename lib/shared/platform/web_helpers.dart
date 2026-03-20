// Conditional export: uses real web APIs on JS/Wasm, stubs on native.
export 'web_helpers_stub.dart' if (dart.library.js_interop) 'web_helpers_web.dart';
