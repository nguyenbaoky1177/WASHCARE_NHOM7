import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/order_status_tracker.dart';

void main() {
  test('payment updates and repeated status events do not notify', () {
    final tracker = OrderStatusTracker()..seed([(id: '1', status: 'pending')]);
    expect(
      tracker.recordUpdate({
        'id': 1,
        'status': 'pending',
        'momo_payment_status': 'paid',
      }),
      isFalse,
    );
    expect(tracker.recordUpdate({'id': 1, 'status': 'confirmed'}), isTrue);
    expect(tracker.recordUpdate({'id': 1, 'status': 'confirmed'}), isFalse);
  });

  test('unknown orders require an old status before notifying', () {
    final tracker = OrderStatusTracker();
    expect(tracker.recordUpdate({'id': 2, 'status': 'pending'}), isFalse);
    expect(
      tracker.recordUpdate(
        {'id': 3, 'status': 'washing'},
        oldRecord: {'status': 'confirmed'},
      ),
      isTrue,
    );
  });
}
