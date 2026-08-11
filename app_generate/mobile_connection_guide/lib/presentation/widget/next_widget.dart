// NextWidget — Shared widget (위저드 Next 버튼)
//
// Figma Bottom-Footer, webOS26 > Button:
//   h 132, w 840 (min 300 / max 1200), px 60, radius/button 24,
//   bg button/fill/container (#5b5d66), label body/60-semibold
//
// EButton(size: large) 기본 제약이 minWidth 840.h / minHeight 132.h 로
// Figma 값과 동일하다 → customSize 를 쓰지 않는다 (SKILL Audit 3).
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

import '../../app/l10n/app_strings.dart';

/// 다음 단계로 이동하는 Footer 버튼.
///
/// IR: ux_tag 5 · default_focus: true (5.2-1/5.2-2/5.3-1/5.3-2 공통).
class NextWidget extends StatelessWidget {
  const NextWidget({super.key, required this.onPressed, this.autoFocus = true});

  final VoidCallback onPressed;

  /// IR 'Default Focus' — 위저드 각 단계의 기본 포커스는 Next 다.
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return EButton(
      // IR test-scenarios target key.
      key: const Key('nextButton'),
      text: AppStrings.of(AppStringKeys.next),
      autoFocus: autoFocus,
      onPressed: onPressed,
    );
  }
}
