// DoneWidget — Shared widget (위저드 마지막 단계 Done 버튼)
//
// Figma Bottom-Footer, webOS26 > Button (2번째 슬롯, gap 72):
//   h 132, w 840, radius/button 24, label body/60-semibold '완료'
//
// EButton(size: large) 기본 제약이 Figma 값과 동일 → customSize 미사용.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

import '../../app/l10n/app_strings.dart';

/// 가이드를 종료하고 메인 화면으로 돌아가는 Footer 버튼.
///
/// IR: 5.2-3 ux_tag 6 / 5.3-3 ux_tag 5 · default_focus: true.
class DoneWidget extends StatelessWidget {
  const DoneWidget({super.key, required this.onPressed, this.autoFocus = true});

  final VoidCallback onPressed;

  /// IR 'Default Focus' — 마지막 단계의 기본 포커스는 Done 이다.
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return EButton(
      // IR test-scenarios target key.
      key: const Key('doneButton'),
      text: AppStrings.of(AppStringKeys.done),
      autoFocus: autoFocus,
      onPressed: onPressed,
    );
  }
}
