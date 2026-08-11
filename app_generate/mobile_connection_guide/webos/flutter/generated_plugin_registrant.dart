//
// Generated file. Do not edit.
//

// ignore_for_file: lines_longer_than_80_chars

import 'package:webos_logger/webos_logger.dart';
import 'package:webos_service_bridge/webos_service_bridge.dart';
import 'package:webos_system/webos_system.dart';
import 'package:plover_platform_webos/plover_platform_webos.dart';

// ignore: public_member_api_docs
void registerPlugins() {
  WebosLogger.registerWith();
  LS2ServiceChannel.registerWith();
  WebOSSystem.registerWith();
  PloverPlatformWebosPlugin.registerWith();
}
