// MainViewModel — ViewModel (5.1 · 스마트폰 공유 카드 > 메인 화면)
//
// decisions.yaml wiring:
//   network-status          → 진입 시 getStatus 구독, isOffline 이면 팝업
//   launch-network-settings → 팝업 Yes 시 설정앱 실행
//   bt-paired-devices       → Sound Share 카드의 5.4 / 5.5 분기
import 'package:flutter/foundation.dart';

import '../../../data/service/applicationmanager_service.dart';
import '../../../data/service/bluetooth2_service.dart';
import '../../../data/service/connectionmanager_service.dart';
import '../../../domain/entity/bluetooth2.dart';
import '../../../domain/entity/connectionmanager.dart';

/// 카드 1/2 선택 결과 — View 가 이 값을 보고 다음 동작을 정한다.
enum MainCardAction {
  /// 정상 상태 — 가이드 화면으로 진행.
  openGuide,

  /// 네트워크 미연결 — 네트워크 설정 필요 팝업.
  showNetworkRequiredPopup,

  /// 서비스 사용 불가 — 미지원 국가 토스트.
  ///
  /// TODO(unresolved: service-availability-source)
  ///   사용 가능 여부를 판단할 데이터 소스(국가 설정 키 / 서비스 상태 API)가
  ///   명세에 없다. 판단 근거가 확정될 때까지 이 분기는 발생하지 않는다.
  showServiceUnavailableToast,
}

/// Sound Share 카드 선택 시 이동 대상.
enum SoundShareTarget {
  /// IR 5.4 — 연결 이력 있음 (devices.length > 0).
  paired,

  /// IR 5.5 — 연결 이력 없음 (devices.length == 0).
  unpaired,
}

class MainViewModel extends ChangeNotifier {
  MainViewModel({
    ConnectionmanagerService? connectionmanager,
    Bluetooth2Service? bluetooth2,
    ApplicationmanagerService? applicationmanager,
  }) : _connectionmanager = connectionmanager ?? ConnectionmanagerService(),
       _bluetooth2 = bluetooth2 ?? Bluetooth2Service(),
       _applicationmanager = applicationmanager ?? ApplicationmanagerService();

  final ConnectionmanagerService _connectionmanager;
  final Bluetooth2Service _bluetooth2;
  final ApplicationmanagerService _applicationmanager;

  Connectionmanager? networkStatus;
  List<Bluetooth2Device> pairedDevices = const <Bluetooth2Device>[];

  /// 진입 시 1회 구독 시작 — 이후 상태 변화가 그대로 반영된다.
  void init() {
    _connectionmanager.startStatusSubscribe(
      onStatus: (Connectionmanager status) {
        networkStatus = status;
        notifyListeners();
      },
    );
    _bluetooth2.startPairedDevicesSubscribe(
      onDevices: (List<Bluetooth2Device> devices) {
        pairedDevices = devices;
        notifyListeners();
      },
    );
  }

  /// condition_expr_offline: response.isInternetConnectionAvailable == false
  ///
  /// 구독 응답이 아직 없으면(null) 보수적으로 미연결로 본다.
  bool get isOffline => networkStatus?.isOffline ?? true;

  /// 카드 1(Google Cast) / 카드 2(AirPlay) 선택 시 판정.
  ///
  /// IR: 네트워크 미연결 팝업은 카드 1/2 에만 적용된다 (카드 3 은 명세 제외).
  MainCardAction resolveShareCardAction() {
    if (isOffline) {
      return MainCardAction.showNetworkRequiredPopup;
    }
    return MainCardAction.openGuide;
  }

  /// 카드 3(Sound Share) 선택 시 이동할 화면.
  ///
  /// condition_expr_has_history: devices.length > 0
  SoundShareTarget resolveSoundShareTarget() {
    return pairedDevices.isEmpty
        ? SoundShareTarget.unpaired
        : SoundShareTarget.paired;
  }

  /// 네트워크 설정 필요 팝업에서 Yes 선택 시.
  Future<void> onNetworkSettingsConfirmed() {
    return _applicationmanager.launchNetworkSettings();
  }

  @override
  void dispose() {
    _connectionmanager.stopStatusSubscribe();
    _bluetooth2.stopPairedDevicesSubscribe();
    super.dispose();
  }
}
