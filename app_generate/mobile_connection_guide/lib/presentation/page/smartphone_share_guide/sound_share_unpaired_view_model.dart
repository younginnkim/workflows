// SoundShareUnpairedViewModel — ViewModel (5.5 · 사운드셰어 > 연결기기 없을 때)
//
// decisions.yaml wiring:
//   bt-paired-devices → devices.length == 0 이 이 화면의 표시 조건.
//                       이력이 생기면(구독 갱신) 5.4 로 전환한다.
//
// IR display_conditions 는 3가지인데 2가지는 감지 채널이 미명세다:
//   1) 연결된 기기 이력이 없는 경우            → bt-paired-devices (구현)
//   2) Sound Share 연결이 끊긴 경우            → unresolved
//   3) 최근 기기 자동 연결 실패 (+토스트)      → unresolved
import 'package:flutter/foundation.dart';

import '../../../data/service/bluetooth2_service.dart';
import '../../../domain/entity/bluetooth2.dart';

class SoundShareUnpairedViewModel extends ChangeNotifier {
  SoundShareUnpairedViewModel({Bluetooth2Service? bluetooth2})
    : _bluetooth2 = bluetooth2 ?? Bluetooth2Service();

  final Bluetooth2Service _bluetooth2;

  List<Bluetooth2Device> pairedDevices = const <Bluetooth2Device>[];

  void init() {
    _bluetooth2.startPairedDevicesSubscribe(
      onDevices: (List<Bluetooth2Device> devices) {
        pairedDevices = devices;
        notifyListeners();
      },
    );
  }

  /// condition_expr_no_history: devices.length == 0
  ///
  /// false 가 되면(이력 생김) View 가 5.4 로 전환한다.
  bool get hasNoHistory => pairedDevices.isEmpty;

  /// IR ux_tag 4 — "전체 설정 메뉴에서 확인 가능한 StanbyME 이름" ({name}).
  ///
  /// TODO(unresolved: device-name-source) — 조회 API 미특정 (5.4 와 동일).
  String? get deviceName => null;

  /// IR ux_tag toast.bluetooth_check — sn_home_0088.
  ///
  /// TODO(unresolved: auto-connect-failure-channel)
  ///   "최근 연결했던 기기 자동 연결 시도하였으나 실패한 경우 토스트 팝업과
  ///    함께 화면 표시" — 실패를 감지할 채널/이벤트가 명세에 없다.
  ///   감지 채널이 확정되면 이 값을 true 로 만들고 View 가 토스트를 띄운다.
  bool get shouldShowBluetoothCheckToast => false;

  @override
  void dispose() {
    _bluetooth2.stopPairedDevicesSubscribe();
    super.dispose();
  }
}
