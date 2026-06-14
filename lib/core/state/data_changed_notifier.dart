import 'dart:async';

class DataChangedNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}
