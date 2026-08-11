// ConnectionmanagerService — LS2 service binding for com.webos.service.connectionmanager
// decision: network-status (decisions.yaml)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webos_service_bridge/webos_service_bridge.dart';

import '../../domain/entity/connectionmanager.dart';

class ConnectionmanagerService {
  StreamSubscription<Map<String, dynamic>>? _statusSubscription;

  // ACG required: networkconnection.query (declared in appinfo.json > requiredPermissions)
  /// luna://com.webos.service.connectionmanager/getStatus (subscribe)
  /// doc: API_Docs/com.webos.service.connectionmanager_v3.0.md:488
  ///
  /// 네트워크 상태 변화를 계속 통지한다.
  /// - 팝업 호출 조건 : status.isOffline
  /// - 유선 연결 조건 : status.isWiredConnected (보조 문구 미제공)
  void startStatusSubscribe({
    required void Function(Connectionmanager status) onStatus,
  }) {
    const WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.connectionmanager/getStatus',
      payload: <String, dynamic>{'subscribe': true},
    );

    _statusSubscription = WebOSServiceBridge.call(request).listen((
      Map<String, dynamic> event,
    ) {
      if (event['returnValue'] == true) {
        onStatus(Connectionmanager.fromMap(event));
      } else {
        debugPrint('getStatus error: ${event['errorText']}');
      }
    });
  }

  void stopStatusSubscribe() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }
}
