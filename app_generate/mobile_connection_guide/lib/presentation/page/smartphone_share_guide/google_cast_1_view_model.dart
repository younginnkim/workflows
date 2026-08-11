// GoogleCastViewModel — ViewModel (5.2-1 ~ 5.2-3 · Google Cast 가이드)
//
// 3단계가 하나의 EWizardPanels 로 묶이므로 단계별 ViewModel 을 따로 두지 않고
// 이 파일 하나가 위저드 전체 상태를 갖는다.
// (google_cast_2_view_model.dart / google_cast_3_view_model.dart 는 이 클래스를
//  가리키는 포인터 주석만 남겨 둔다.)
//
// decisions.yaml wiring:
//   network-status      → 5.2-1 의 4-1 보조 문구 표시 여부 (유선이면 미제공)
//   launch-google-cast  → 5.2-3 의 [Google Cast] 버튼
import 'package:flutter/foundation.dart';

import '../../../data/service/applicationmanager_service.dart';
import '../../../data/service/connectionmanager_service.dart';
import '../../../domain/entity/connectionmanager.dart';

class GoogleCastViewModel extends ChangeNotifier {
  GoogleCastViewModel({
    ConnectionmanagerService? connectionmanager,
    ApplicationmanagerService? applicationmanager,
  }) : _connectionmanager = connectionmanager ?? ConnectionmanagerService(),
       _applicationmanager = applicationmanager ?? ApplicationmanagerService();

  final ConnectionmanagerService _connectionmanager;
  final ApplicationmanagerService _applicationmanager;

  /// IR wizard: step 1..3 → 0-based index.
  static const int totalSteps = 3;

  int _step = 0;

  /// 0-based 내부 인덱스 (EWizardPanels.index 와 직접 맞물린다).
  int get stepIndex => _step;

  /// IR test-scenarios `state_changed field: step` — 1-based 단계 번호.
  ///
  /// ESteps 도 `current: index + 1` 로 1-based 를 쓴다 (e_wizard_panels.dart:527).
  int get step => _step + 1;

  /// IR test-scenarios `state_changed field: completedSteps` — 완료된 단계들.
  ///
  /// 위저드는 앞 단계를 모두 거쳐야 다음 단계에 오므로 1..step-1 이 완료다.
  List<int> get completedSteps =>
      List<int>.generate(_step, (int i) => i + 1);

  Connectionmanager? networkStatus;

  void init() {
    _connectionmanager.startStatusSubscribe(
      onStatus: (Connectionmanager status) {
        networkStatus = status;
        notifyListeners();
      },
    );
  }

  void onStepChanged(int index) {
    if (index == _step) {
      return;
    }
    _step = index;
    notifyListeners();
  }

  /// IR 5.2-1 ux_tag 4-1 — "기기가 유선 네트워크로 연결된 상태일 때는 미제공함"
  ///
  /// condition_expr_wired: response.wired.state == 'connected' → visible: false
  bool get showWiredHintText => !(networkStatus?.isWiredConnected ?? false);

  /// IR 5.2-3 ux_tag 5 — 선택 시 구글 캐스트 앱으로 이동.
  ///
  /// TODO(unresolved: google-cast-app-id) — appId 미확정이라 StateError 가 난다.
  /// 확정 전까지 호출 결과를 로그로만 남기고 화면은 유지한다.
  Future<void> onGoogleCastSelected() async {
    try {
      await _applicationmanager.launchGoogleCast();
    } on StateError catch (e) {
      debugPrint('launchGoogleCast skipped: ${e.message}');
    }
  }

  @override
  void dispose() {
    _connectionmanager.stopStatusSubscribe();
    super.dispose();
  }
}
