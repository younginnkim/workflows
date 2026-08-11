// SoundSharePairedViewModel — ViewModel (5.4 · 사운드셰어 > 연결기기 있을 때)
//
// decisions.yaml wiring — [연결하기] 는 IR 이 정한 순서대로 3단계다:
//   순서 1  soundout-get / soundout-set
//           사운드 아웃이 블루투스 계열이면 'tv_speaker'(기기 스피커)로 보정
//   순서 2  bt-a2dp-connect   가장 최근 기기에 a2dp/connect
//   순서 3  soundshare-stream-out  Sound Share 앱 Play 씬으로 이동
//
// 화면 표시용 데이터는 bt-paired-devices 구독에서 온다.
import 'package:flutter/foundation.dart';

import '../../../data/service/applicationmanager_service.dart';
import '../../../data/service/audio_service.dart';
import '../../../data/service/bluetooth2_service.dart';
import '../../../domain/entity/bluetooth2.dart';

class SoundSharePairedViewModel extends ChangeNotifier {
  SoundSharePairedViewModel({
    Bluetooth2Service? bluetooth2,
    AudioService? audio,
    ApplicationmanagerService? applicationmanager,
  }) : _bluetooth2 = bluetooth2 ?? Bluetooth2Service(),
       _audio = audio ?? AudioService(),
       _applicationmanager = applicationmanager ?? ApplicationmanagerService();

  final Bluetooth2Service _bluetooth2;
  final AudioService _audio;
  final ApplicationmanagerService _applicationmanager;

  List<Bluetooth2Device> pairedDevices = const <Bluetooth2Device>[];

  /// 연결 시도 중 — [연결하기] 중복 입력을 막는다.
  bool isConnecting = false;

  void init() {
    _bluetooth2.startPairedDevicesSubscribe(
      onDevices: (List<Bluetooth2Device> devices) {
        pairedDevices = devices;
        notifyListeners();
      },
    );
  }

  /// condition_expr_has_history: devices.length > 0
  bool get hasHistory => pairedDevices.isNotEmpty;

  /// TODO(unresolved: bt-recent-device-order)
  ///   '가장 최근에 연결한 기기' 정렬 기준 필드가
  ///   com.webos.service.bluetooth2_v4.0.md 에 명시돼 있지 않다.
  ///   지금은 응답 순서의 첫 항목을 사용한다 — 정렬 기준 필드가 확인되면
  ///   그 필드로 sort 한 뒤 first 를 쓰도록 교체할 것. (추측 금지)
  Bluetooth2Device? get recentDevice =>
      pairedDevices.isEmpty ? null : pairedDevices.first;

  /// IR ux_tag 5 — "가장 최근에 연결한 기기명" ({%Mobile_name}).
  String? get recentDeviceName => recentDevice?.name;

  /// IR ux_tag 4 — "전체 설정 메뉴에서 확인 가능한 StanbyME 이름" ({name}).
  ///
  /// TODO(unresolved: device-name-source)
  ///   기기 이름 조회 API 를 luna-api-docs 에서 특정하지 못했다.
  ///   (bluetooth2 adapter/getStatus 는 discoverable/pairable 만 제공,
  ///    settingsservice 에 deviceName/tvName 키 grep 0건)
  ///   확정될 때까지 null 을 반환해 화면은 플레이스홀더를 그대로 노출한다.
  String? get deviceName => null;

  /// IR ux_tag 7 — [연결하기] 선택 시.
  ///
  /// 순서 1(사운드 아웃 보정) → 순서 2(연결) → 순서 3(앱 이동).
  ///
  /// TODO(unresolved: connect-failure-handling)
  ///   a2dp/connect 실패 시 동작이 5.4 에 명세되지 않았다. 지금은 뒤 단계를
  ///   진행하지 않고 화면을 유지한다.
  Future<void> connectRecentDevice() async {
    final Bluetooth2Device? device = recentDevice;
    if (device == null || isConnecting) {
      return;
    }

    isConnecting = true;
    notifyListeners();
    try {
      // 순서 1 — 사운드 아웃이 블루투스 계열이면 기기 스피커로 되돌린다.
      await _ensureTvSpeakerOutput();

      // 순서 2 — 가장 최근 기기에 연결 시도.
      final bool connected = await _bluetooth2.connectA2dp(
        address: device.address,
      );
      if (!connected) {
        return;
      }

      // 순서 3 — Sound Share 앱 Play 씬으로 이동.
      //
      // TODO(unresolved: soundshare-app-id) — appId 미확정이라 StateError.
      try {
        await _applicationmanager.launchSoundSharePlay();
      } on StateError catch (e) {
        debugPrint('launchSoundSharePlay skipped: ${e.message}');
      }
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  /// 순서 1 — soundout-get / soundout-set.
  Future<void> _ensureTvSpeakerOutput() async {
    if (await _audio.isBluetoothSoundOutput()) {
      await _audio.setSoundOutputToTvSpeaker();
    }
  }

  @override
  void dispose() {
    _bluetooth2.stopPairedDevicesSubscribe();
    super.dispose();
  }
}
