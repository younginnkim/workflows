// ApplicationmanagerService — LS2 service binding for com.webos.service.applicationmanager
// decision: launch-network-settings / launch-google-cast / soundshare-stream-out
import 'package:flutter/foundation.dart';
import 'package:webos_service_bridge/webos_service_bridge.dart';

import '../../domain/entity/applicationmanager.dart';

class ApplicationmanagerService {
  // ACG required: application.operation (declared in appinfo.json > requiredPermissions)
  /// luna://com.webos.service.applicationmanager/launch — 공통 실행 헬퍼.
  /// doc: API_Docs/com.webos.service.applicationmanager_v4.9.md:5406
  Future<bool> launch({
    required String id,
    Map<String, dynamic>? params,
  }) async {
    final WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.applicationmanager/launch',
      payload: <String, dynamic>{
        'id': id,
        if (params != null) 'params': params,
      },
    );

    final Map<String, dynamic>? response =
        await WebOSServiceBridge.callOneReply(request);

    if (response != null && response['returnValue'] == true) {
      return true;
    }
    debugPrint('launch($id) failed: ${response?['errorText']}');
    return false;
  }

  /// luna://com.webos.service.applicationmanager/launch — 네트워크 설정 화면.
  ///
  /// TODO(unresolved: settings-deeplink-target)
  ///   params.target 키/값('network')은 문서에 정의가 없다. 설정앱 딥링크
  ///   스펙이 확인되면 교체할 것. 확인 전에도 앱 자체는 실행되므로 호출은
  ///   유지하되, 딥링크가 안 먹으면 이 파라미터가 원인이다.
  Future<bool> launchNetworkSettings() {
    return launch(
      id: ApplicationmanagerAppId.settings,
      params: const <String, dynamic>{'target': 'network'},
    );
  }

  /// luna://com.webos.service.applicationmanager/launch — Google Cast 앱.
  ///
  /// TODO(unresolved: google-cast-app-id) — appId 미확정이라 호출 시 StateError.
  Future<bool> launchGoogleCast() async {
    const String? appId = ApplicationmanagerAppId.googleCast;
    if (appId == null) {
      throw StateError(
        'googleCastAppId unresolved — decisions.yaml unresolved: '
        'google-cast-app-id 를 확정한 뒤 '
        'ApplicationmanagerAppId.googleCast 상수를 채우세요.',
      );
    }
    return launch(id: appId);
  }

  /// luna://com.webos.service.applicationmanager/launch
  /// params: {scene: 'play'} — Sound Share 앱의 Play 씬으로 진입.
  ///
  /// TODO(unresolved: soundshare-app-id) — appId 미확정이라 호출 시 StateError.
  Future<bool> launchSoundSharePlay() async {
    const String? appId = ApplicationmanagerAppId.soundShare;
    if (appId == null) {
      throw StateError(
        'soundShareAppId unresolved — decisions.yaml unresolved: '
        'soundshare-app-id 를 확정한 뒤 '
        'ApplicationmanagerAppId.soundShare 상수를 채우세요.',
      );
    }
    return launch(id: appId, params: const <String, dynamic>{'scene': 'play'});
  }
}
