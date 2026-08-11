// NetworkRequiredPopup — Popup (popup.network_required · 네트워크 설정 필요 팝업)
//
// IR 5.1 ux_tag popup.network_required · visual_role: confirm-popup (modal overlay)
//   본문   sn_home_0020
//   버튼   Yes → 네트워크 설정 화면으로 이동 (applicationmanager/launch)
//          No  → 팝업 닫힘
//
// 확인 팝업(본문 + 버튼 2개)이므로 EAlert 를 쓴다. 스크림·포커스 트랩·Back 키
// 처리가 내장이라 팝업 크롬을 직접 만들지 않는다.
// 팝업 위젯은 콜백만 받고 서비스를 직접 호출하지 않는다 (decisions.yaml wiring
// 주석: "팝업 위젯은 콜백만 받고 서비스를 직접 호출하지 않는다 — MVVM 유지").
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

import '../../app/l10n/app_strings.dart';

/// 네트워크 미연결 시 뜨는 확인 팝업.
///
/// [controller] 로 열고 닫는다. `controller.open()` 호출 시 표시된다.
class NetworkRequiredPopup extends StatelessWidget {
  const NetworkRequiredPopup({
    super.key,
    required this.controller,
    required this.onConfirm,
    required this.onCancel,
  });

  final EAlertController controller;

  /// Yes — 네트워크 설정 화면으로 이동. ViewModel 이 luna 호출을 담당한다.
  final VoidCallback onConfirm;

  /// No — 팝업 닫힘.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return EAlert(
      key: const Key('networkRequiredPopup'),
      context: context,
      controller: controller,
      body: AppStrings.of(AppStringKeys.networkRequiredBody),
      // Yes/No 두 개 → 좌우 배치.
      buttonsAxis: EAlertButtonsAxis.horizontal,
      buttons: <Widget>[
        EAlertButton(
          text: AppStrings.of(AppStringKeys.yes),
          autoFocus: true,
          onPressed: () {
            controller.close();
            onConfirm();
          },
        ),
        EAlertButton(
          text: AppStrings.of(AppStringKeys.no),
          onPressed: () {
            controller.close();
            onCancel();
          },
        ),
      ],
      // Back 키 = No 와 동일하게 닫는다.
      onClose: (EAlertInputType inputType) {
        controller.close();
        onCancel();
      },
    );
  }
}
