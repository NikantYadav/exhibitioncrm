import 'dart:async';

/// Minimal combineLatest for two streams — re-emits the combined value
/// whenever either source emits, once both have produced at least one
/// value. Avoids adding rxdart as a direct dependency for a few use sites
/// across repositories that join multiple synced-table streams.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  A? latestA;
  B? latestB;
  var hasA = false, hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) { latestA = v; hasA = true; emit(); }, onError: controller.addError);
      subB = b.listen((v) { latestB = v; hasB = true; emit(); }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}

/// Three-stream combineLatest, built on [combineLatest2].
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A, B, C) combine,
) {
  return combineLatest2(
    combineLatest2(a, b, (A x, B y) => (x, y)),
    c,
    (ab, cValue) => combine(ab.$1, ab.$2, cValue),
  );
}
