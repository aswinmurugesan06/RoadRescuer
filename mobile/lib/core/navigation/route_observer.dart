import 'package:flutter/material.dart';

/// App-wide route observer.
///
/// Tab screens live inside a `Navigator` shell that stays mounted, so their
/// Firestore-backed lists can become stale after a job is accepted or a route
/// is popped. `RouteAware` screens subscribe to this observer and refresh in
/// `didPopNext`.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
