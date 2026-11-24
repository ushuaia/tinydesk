import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/document_sync.dart';

void main() {
  test('an unchanged document needs no action', () {
    final policy = DocSyncPolicy();
    expect(
      policy.decide(changed: false, dirty: true, now: DateTime(2026, 1, 1)),
      DocSyncAction.none,
    );
  });

  test('an external change reloads a clean document', () {
    final policy = DocSyncPolicy();
    expect(
      policy.decide(changed: true, dirty: false, now: DateTime(2026, 1, 1)),
      DocSyncAction.reload,
    );
  });

  test('a dirty document reports the conflict at most once a minute', () {
    final policy = DocSyncPolicy();
    final start = DateTime(2026, 1, 1, 12);

    expect(
      policy.decide(changed: true, dirty: true, now: start),
      DocSyncAction.conflict,
    );
    expect(
      policy.decide(
        changed: true,
        dirty: true,
        now: start.add(const Duration(seconds: 30)),
      ),
      DocSyncAction.none,
    );
    expect(
      policy.decide(
        changed: true,
        dirty: true,
        now: start.add(const Duration(minutes: 1)),
      ),
      DocSyncAction.conflict,
    );
  });
}
