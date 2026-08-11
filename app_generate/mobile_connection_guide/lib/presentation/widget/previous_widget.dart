// PreviousWidget — Shared widget (위저드 Previous 버튼)
//
// Figma Header, webOS26 > Previous (slotBefore, 420x144):
//   Button-Icon 132x132 (icon 84) + 'Previous' 라벨 body/48-regular, gap 12
//   Figma 컴포넌트 설명: "caret_left_large U+EFFEF / Wizard Arrow"
//     → LimestoneIcons.arrowlargeleft (icons.dart 주석이 caret_left_large)
//
// EWizardPanels 의 기본 prevButton 은 아이콘만 있는 NavigationButton 이라
// Figma 의 아이콘+라벨 조합과 다르다 → prevButton 슬롯에 이 위젯을 넘긴다.
// .dh (ResponsiveScaleExtension) 는 widgets.dart 배럴에 없어서 직접 import 한다.
import 'package:elemental/foundation/responsive_screen_utils.dart';
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

import '../../app/l10n/app_strings.dart';

/// 이전 화면/단계로 돌아가는 헤더 버튼 (아이콘 + 라벨).
///
/// IR: 5.2-1 ux_tag 6 / 5.2-2 ux_tag 6 / 5.2-3 ux_tag 7 등 · focusable: true.
class PreviousWidget extends StatelessWidget {
  const PreviousWidget({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return EButton(
      // IR test-scenarios target key.
      key: const Key('previousButton'),
      text: AppStrings.of(AppStringKeys.previous),
      icon: LimestoneIcons.arrowlargeleft,
      // Figma: 아이콘이 라벨 왼쪽
      iconPosition: IconPosition.before,
      // Figma: 컨테이너 배경 없음 (헤더에 얹힌 투명 버튼)
      backgroundOpacity: EButtonBackgroundOpacity.transparent,
      // 840.h 기본 최소폭을 끄고 Figma 의 420x144 슬롯에 맞춘다.
      minWidth: false,
      // Figma Icon 84x84 — 아이콘 크기는 .dh (SKILL Audit 8)
      customIconSize: 84.dh,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
