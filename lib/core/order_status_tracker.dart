/// Keeps status notifications independent from payment and other order updates.
class OrderStatusTracker {
  final Map<String, String> _statuses = {};

  void seed(Iterable<({String id, String status})> orders) {
    for (final order in orders) {
      _statuses[order.id] = order.status;
    }
  }

  bool recordUpdate(
    Map<String, dynamic> record, {
    Map<String, dynamic> oldRecord = const {},
  }) {
    final id = record['id']?.toString();
    final status = record['status']?.toString();
    if (id == null || status == null || status.isEmpty) return false;
    final previous = _statuses[id] ?? oldRecord['status']?.toString();
    _statuses[id] = status;
    return previous != null && previous != status;
  }
}
