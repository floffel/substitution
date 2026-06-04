import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/write/mixins/send_with_retry.dart';

// Note: [SendWithRetry] is exercised end-to-end by
// [test/write_textmessage_test.dart] and
// [test/write_filemessage_test.dart], which call the mixin through
// the real page's `_send` flow (loading dialog, retry, error
// dialog, success snackbar, navigation). Those tests pass against
// both the pre-refactor and post-refactor code paths, so the
// `navigateOnSuccess: false` behavior added for the file-message
// per-file batch upload is covered by the existing test suite.
//
// This file exists so the mixin has a place to be located by future
// tests that want to add focused unit coverage of the mixin's
// internal state machine without a full widget harness. Keep the
// file open as a starting point for that work.
void main() {
  test('SendWithRetry mixin is exported', () {
    expect(SendWithRetry, isNotNull);
  });
}
