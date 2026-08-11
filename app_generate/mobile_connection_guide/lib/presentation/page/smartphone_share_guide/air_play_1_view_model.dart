// AirPlayViewModel — ViewModel (5.3-1 ~ 5.3-3 · AirPlay 가이드)
//
// 3단계가 하나의 EWizardPanels 로 묶이므로 단계별 ViewModel 을 따로 두지 않고
// 이 파일 하나가 위저드 전체 상태를 갖는다.
//
// decisions.yaml wiring:
//   network-status → 5.3-1 의 4-1 보조 문구 표시 여부 (유선이면 미제공)
//
// Google Cast 위저드와 달리 마지막 단계에 외부 앱 실행이 없다
// (IR 5.3-3: ux_tag 5 Done → view.5.1, ux_tag 6 Previous 뿐).
import 'package:flutter/foundation.dart';

import '../../../data/service/connectionmanager_service.dart';
import '../../../domain/entity/connectionmanager.dart';

class AirPlayViewModel extends ChangeNotifier {
  AirPlayViewModel({ConnectionmanagerService? connectionmanager})
    : _connectionmanager = connectionmanager ?? ConnectionmanagerService();

  final ConnectionmanagerService _connectionmanager;

  /// IR wizard: step 1..3 → 0-based index.
  static const int totalSteps = 3;

  int _step = 0;

  /// 0-based 내부 인덱스 (EWizardPanels.index 와 직접 맞물린다).
  int get stepIndex => _step;

  /// IR test-scenarios `state_changed field: step` — 1-based 단계 번호.
  int get step => _step + 1;

  /// IR test-scenarios `state_changed field: completedSteps` — 완료된 단계들.
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

  /// IR 5.3-1 ux_tag 4-1 — "TV가 유선 네트워크로 연결된 상태일 때는 미제공함"
  ///
  /// condition_expr_wired: response.wired.state == 'connected' → visible: false
  bool get showWiredHintText => !(networkStatus?.isWiredConnected ?? false);

  @override
  void dispose() {
    _connectionmanager.stopStatusSubscribe();
    super.dispose();
  }
}
