// AudioService — LS2 service binding for com.webos.service.audio
// decision: soundout-get / soundout-set (decisions.yaml)
import 'package:flutter/foundation.dart';
import 'package:webos_service_bridge/webos_service_bridge.dart';

import '../../domain/entity/audio.dart';

class AudioService {
  // ACG required: audio.query (declared in appinfo.json > requiredPermissions)
  /// luna://com.webos.service.audio/getSoundOutput
  /// doc: API_Docs/com.webos.service.audio_v1.14.md:3822
  Future<String?> getSoundOutput() async {
    const WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.audio/getSoundOutput',
      payload: <String, dynamic>{},
    );

    final Map<String, dynamic>? response =
        await WebOSServiceBridge.callOneReply(request);

    if (response != null && response['returnValue'] == true) {
      return response['soundOutput'] as String?;
    }
    debugPrint('getSoundOutput failed: ${response?['errorText']}');
    return null;
  }

  /// condition_expr 대응 — 현재 출력이 블루투스 계열인지.
  ///
  /// TODO(unresolved: soundout-value-mapping) — 후보값 기반이라 오탐/미탐 가능.
  /// 값 목록은 [AudioSoundOutput.bluetoothCandidates] 참고.
  Future<bool> isBluetoothSoundOutput() async {
    final String? current = await getSoundOutput();
    return current != null &&
        AudioSoundOutput.bluetoothCandidates.contains(current);
  }

  /// luna://com.webos.service.audio/setSoundOutput
  /// doc: API_Docs/com.webos.service.audio_v1.14.md:13467
  /// 'tv_speaker' = 기기 스피커 (문서의 TV 적용 값 목록에서 확인).
  Future<bool> setSoundOutputToTvSpeaker() async {
    const WebOSServiceData request = WebOSServiceData(
      'luna://com.webos.service.audio/setSoundOutput',
      payload: <String, dynamic>{'soundOutput': AudioSoundOutput.tvSpeaker},
    );

    final Map<String, dynamic>? response =
        await WebOSServiceBridge.callOneReply(request);

    if (response != null && response['returnValue'] == true) {
      return true;
    }
    debugPrint('setSoundOutput failed: ${response?['errorText']}');
    return false;
  }
}
