// WizardViewWidget — Shared widget (WizardView)
//
// IR: "해당 화면 동작성은 Pattern, Component의 Wizardview에 따름"
//     (5.2-1 · 5.2-2 · 5.3-1 · 5.3-2 · 5.3-3 pattern.component: WizardView)
// → elemental 의 EWizardPanels 를 그대로 쓴다. ESteps(1/2/3, 완료는 체크
//   아이콘), 중앙 타이틀, 패널 전환 애니메이션, ESC/Back 처리가 내장이다.
//
// Figma 와 기본값이 다른 두 곳만 슬롯으로 교체한다:
//   1) prevButton — 기본은 아이콘만. Figma 는 아이콘+'Previous' 라벨
//      (Header slotBefore 420x144) → PreviousWidget 주입.
//   2) nextButton — 기본은 헤더 우측 아이콘. Figma 는 Footer 의 840x132
//      채운 버튼 → nextButton: false 로 끄고 각 스텝의 footer 로 넘긴다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

import 'previous_widget.dart';

/// 위저드 한 단계의 내용 + Footer 버튼.
class WizardStep {
  const WizardStep({required this.body, required this.footer});

  /// 본문 — 보통 [GuideDialogWidget].
  final Widget body;

  /// Footer 버튼 영역 (Next / [Google Cast][Done] / Done).
  final Widget footer;
}

/// Google Cast · AirPlay 가이드 공통 위저드 셸.
///
/// [title] 은 전 단계 공통 타이틀이다 (IR: 5.2-* 는 sn_home_0023,
/// 5.3-* 는 sn_home_0024 로 3단계 모두 동일).
class WizardViewWidget extends StatelessWidget {
  const WizardViewWidget({
    super.key,
    required this.title,
    required this.steps,
    required this.index,
    required this.onIndexChanged,
    required this.onExit,
    this.contentRevision,
  });

  /// 헤더 타이틀 — headline/108-semibold, 전 단계 공통.
  final String title;

  /// 단계 목록 (Figma/IR 기준 3단계).
  final List<WizardStep> steps;

  /// 현재 단계 (0-based).
  final int index;

  /// 단계 변경 통지 — ViewModel 의 step 을 갱신한다.
  final ValueChanged<int> onIndexChanged;

  /// 첫 단계에서 Previous/Back 시 호출 — 메인 화면으로 돌아간다.
  ///
  /// IR: 5.2-1 ux_tag 6 "선택 시, 이전 화면으로 이동" (navigate_back).
  final VoidCallback onExit;

  /// [steps] 의 **내용**이 바뀌었음을 알리는 토큰.
  ///
  /// EWizardPanels 는 패널 내용을 initState 에서 한 번 캐시하고, didUpdateWidget
  /// 에서 `children.length` 가 바뀔 때만 다시 뽑는다
  /// (`e_wizard_panels.dart:206-209, 260-269`). 단계 수가 항상 3인 이 위저드에서는
  /// 길이가 절대 변하지 않으므로, luna 구독으로 본문이 갱신돼도
  /// (5.2-1/5.3-1 의 유선 힌트) 화면에 반영되지 않는다.
  ///
  /// 그래서 내용에 영향을 주는 상태를 이 토큰으로 받아 ValueKey 에 실어, 값이
  /// 바뀌면 EWizardPanels 를 새 State 로 재생성한다. index 는 키에 넣지 않는다 —
  /// 단계 전환마다 재생성하면 전환 애니메이션이 깨진다.
  final Object? contentRevision;

  @override
  Widget build(BuildContext context) {
    return EWizardPanels(
      key: contentRevision == null
          ? null
          : ValueKey<Object>(contentRevision!),
      index: index,
      title: title,
      // Figma 헤더에 subtitle 슬롯이 없다.
      noSubtitle: true,
      onChange: onIndexChanged,
      // Figma: Next 는 Footer 버튼이므로 헤더의 기본 next 버튼을 끈다.
      nextButton: false,
      // Figma: Previous 는 아이콘+라벨 (헤더 좌측).
      prevButton: PreviousWidget(onPressed: () => _goPrevious(context)),
      // 첫 단계에서도 Previous 를 보여야 한다 (IR 5.2-1/5.3-1 ux_tag 6).
      prevButtonVisibility: ButtonVisibility.always,
      onBack: (PreventableEvent event) {
        // 첫 단계의 Back 은 위저드가 소비하지 않고 화면을 벗어난다.
        if (index == 0) {
          event.preventDefault();
          onExit();
        }
      },
      children: <Widget>[
        for (final WizardStep step in steps)
          EWizardPanel(children: step.body, footer: step.footer),
      ],
    );
  }

  /// Previous: 첫 단계면 화면을 벗어나고, 아니면 이전 단계로.
  void _goPrevious(BuildContext context) {
    if (index == 0) {
      onExit();
      return;
    }
    onIndexChanged(index - 1);
  }
}
