import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/resource.dart';

class ResourceProvider extends ChangeNotifier {
  Box<Resource> get _box => Hive.box<Resource>('resources');

  Resource get data {
    if (_box.isEmpty) return Resource(utilities: 0, salary: 0);
    return _box.values.first;
  }

  void save(Resource r) {
    if (_box.isEmpty) {
      _box.add(r);
    } else {
      _box.put(_box.keyAt(0), r);
    }
    notifyListeners();
  }

  /// Метод-обёртка, который вызывали экраны: prov.setBoth(utilities: ..., salary: ...)
  void setBoth({required double utilities, required double salary}) {
    save(Resource(utilities: utilities, salary: salary));
  }
}
