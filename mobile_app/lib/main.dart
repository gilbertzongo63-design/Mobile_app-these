import 'package:flutter/material.dart';

import 'app.dart';
import 'services/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategyIfWeb();
  runApp(const WasteSortingMobileApp());
}
