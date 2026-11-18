import 'dart:async';

import 'package:dio/dio.dart';
import 'package:wavelog_mobile/data/datasources/remote/park_boundary_datasource.dart';
import 'package:wavelog_mobile/data/models/park_boundary_model.dart';

/// A square outline of [half] degrees around a point.
ParkBoundary squareOutline(double lat, double lon,
        {double half = 0.01, BoundarySource source = BoundarySource.osm}) =>
    ParkBoundary(
      source: source,
      name: 'Test outline',
      kind: 'boundary:protected_area',
      areas: [
        ParkArea([
          (lat: lat - half, lon: lon - half),
          (lat: lat - half, lon: lon + half),
          (lat: lat + half, lon: lon + half),
          (lat: lat + half, lon: lon - half),
          (lat: lat - half, lon: lon - half),
        ]),
      ],
    );

/// An outline source that never reaches Nominatim: answers with [result], or
/// fails with [error], or waits for [gate].
class FakeBoundaries extends ParkBoundaryDatasource {
  ParkBoundary? result;
  Object? error;
  Completer<void>? gate;
  final asked = <String>[];

  FakeBoundaries({this.result}) : super(dio: Dio());

  @override
  Future<ParkBoundary?> find({
    required String reference,
    required String name,
    required double lat,
    required double lon,
  }) async {
    asked.add(reference);
    await gate?.future;
    if (error != null) throw error!;
    return result;
  }
}
