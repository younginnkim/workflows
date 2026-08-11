// Bluetooth2Service — LS2 service binding for com.webos.service.bluetooth2
// decision: bt-paired-devices / bt-a2dp-connect (decisions.yaml)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webos_service_bridge/webos_service_bridge.dart';

import '../../domain/entity/bluetooth2.dart';

class Bluetooth2Service {
  StreamSubscription<Map<String, dynamic>>? _pairedDevicesSubscription;

  // ACG required: bluetooth.query (declared in appinfo.json > requiredPermissions)
  /// luna://com.webos.service.bluetooth2/device/getPairedDevices (subscribe)
  /// doc: API_Docs/com.webos.service.bluetooth2_v4.0.md:8300
  ///
  /// devices[] 가 비면 5.5(이력 없음), 있으면 5.4(이력 있음) 로 분기한다.
  void startPairedDevicesSubscribe({
    required void Function(List<Bluetooth2Device> devices) onDevices,
  }) {
    const WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.bluetooth2/device/getPairedDevices',
      payload: <String, dynamic>{'subscribe': true},
    );

    _pairedDevicesSubscription = WebOSServiceBridge.call(request).listen((
      Map<String, dynamic> event,
    ) {
      if (event['returnValue'] == true) {
        final List<dynamic> raw =
            (event['devices'] as List<dynamic>?) ?? const <dynamic>[];
        onDevices(
          raw
              .whereType<Map<String, dynamic>>()
              .map(Bluetooth2Device.fromMap)
              .toList(),
        );
      } else {
        debugPrint('device/getPairedDevices error: ${event['errorText']}');
      }
    });
  }

  void stopPairedDevicesSubscribe() {
    _pairedDevicesSubscription?.cancel();
    _pairedDevicesSubscription = null;
  }

  // ACG required: bluetooth.query (declared in appinfo.json > requiredPermissions)
  /// luna://com.webos.service.bluetooth2/a2dp/connect
  /// doc: API_Docs/com.webos.service.bluetooth2_v4.0.md:151
  ///
  /// [address] 는 params_template 의 {recent_device.address} 자리 —
  /// device/getPairedDevices 결과에서 얻은 실제 주소를 넘긴다.
  Future<bool> connectA2dp({required String address}) async {
    final WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.bluetooth2/a2dp/connect',
      payload: <String, dynamic>{'address': address},
    );

    final Map<String, dynamic>? response =
        await WebOSServiceBridge.callOneReply(request);

    if (response != null && response['returnValue'] == true) {
      return true;
    }
    debugPrint('a2dp/connect failed: ${response?['errorText']}');
    return false;
  }
}
