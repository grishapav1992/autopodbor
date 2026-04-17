/// Backwards-compat re-export.
///
/// Canonical tokens live at `lib/core/constants/design_tokens.dart` so that
/// common widgets outside the spark_joy feature can depend on them without
/// reaching into this folder. This file is kept as a thin shim for all the
/// existing `package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/
/// spark_joy_tokens.dart` imports.
library;

export 'package:flutter_application_1/core/constants/design_tokens.dart';
