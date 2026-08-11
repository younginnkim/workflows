// AirPlayGuidePage — View (5.3-1 ~ 5.3-3 · AirPlay 가이드 위저드)
//
// Figma 291:123809 / 291:123808 / 291:123807 — 3840x2160 각 3단계
//   Header, webOS26  h 396 · Step Set(60x60 x3, gap 60, top 72)
//                    title headline/108-semibold = sn_home_0024 (3단계 공통)
//                    slotBefore = Previous (아이콘 84 + 라벨 48)
//   Contents         img_connect_airplay_0N 1860x864 (r36) + Text(66/54)
//   Bottom-Footer    h 300, pb 132 · Button 840x132 (r24)
//                      1,2단계 : [Next] · 3단계 : [완료]
//
// Google Cast 위저드와 구조가 같고, 3단계 Footer 만 버튼 1개다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/navigation/app_route.dart';
import '../../widget/done_widget.dart';
import '../../widget/guide_dialog_widget.dart';
import '../../widget/inline_guide_icon_widget.dart';
import '../../widget/next_widget.dart';
import '../../widget/wizard_view_widget.dart';
import 'air_play_1_view_model.dart';

class AirPlayGuidePage extends ConsumerStatefulWidget {
  const AirPlayGuidePage({super.key, this.viewModel});

  /// 테스트에서 luna 서비스가 스텁된 ViewModel 을 주입하기 위한 훅.
  final AirPlayViewModel? viewModel;

  @override
  ConsumerState<AirPlayGuidePage> createState() => _AirPlayGuidePageState();
}

class _AirPlayGuidePageState extends ConsumerState<AirPlayGuidePage> {
  late final AirPlayViewModel _viewModel =
      widget.viewModel ?? AirPlayViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  /// 가이드 종료 → 메인 화면 (IR 5.3-3 ux_tag 5 target: view.5.1).
  void _backToMain() {
    ref.read(appRouteProvider.notifier).state = AppRoute.main;
  }

  @override
  Widget build(BuildContext context) {
    return WizardViewWidget(
      // IR: 3단계 모두 같은 타이틀 (sn_home_0024).
      title: AppStrings.of(AppStringKeys.airPlayLabel),
      // EWizardPanels.index 는 0-based 다 (step 은 IR 의 1-based 표기).
      index: _viewModel.stepIndex,
      onIndexChanged: _viewModel.onStepChanged,
      onExit: _backToMain,
      // 1단계 보조 문구의 표시 여부가 네트워크 구독으로 바뀐다 (5.2-1 과 동일).
      contentRevision: _viewModel.showWiredHintText,
      steps: <WizardStep>[_buildStep1(), _buildStep2(), _buildStep3()],
    );
  }

  /// 1단계 — 아이폰 설정에서 Wi-Fi 켜기.
  WizardStep _buildStep1() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-airplay-1.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        secondaryKey: const <int, Key>{0: Key('secondaryHintText')},
        // IR ux_tag 4 — sn_home_0033
        description: AppStrings.of(AppStringKeys.airPlayStep1),
        inlineIconPlaceholder: '{%iphoneset_icon}',
        inlineIcon: const InlineGuideIconWidget(
          icon: LimestoneIcons.gear,
          semanticsLabel: 'Settings',
        ),
        // IR ux_tag 4-1 — 유선 연결 상태면 미제공
        //
        // TODO(unresolved: airplay-step1-secondary-tag)
        //   이 문구의 문구태그가 PDF에 없다. Google Cast 판(sn_home_0027)과
        //   동일 태그 재사용 여부가 불명이라 별도 키를 쓴다.
        secondaryDescriptions: <String>[
          if (_viewModel.showWiredHintText)
            AppStrings.of(AppStringKeys.airPlayStep1Secondary),
        ],
      ),
      footer: NextWidget(onPressed: () => _viewModel.onStepChanged(1)),
    );
  }

  /// 2단계 — 제어 센터에서 AirPlay 아이콘 선택.
  WizardStep _buildStep2() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-airplay-2.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        // IR ux_tag 4 — sn_home_0034
        description: AppStrings.of(AppStringKeys.airPlayStep2),
        inlineIconPlaceholder: '{%airplay_icon}',
        inlineIcon: InlineGuideIconWidget(
          icon: LimestoneIcons.airplay,
          // IR: Audio Guidance — {%airplay_icon} 은 'AirPlay' 로 발화
          // (sn_home_0118)
          semanticsLabel: AppStrings.of(AppStringKeys.a11yAirPlay),
        ),
        // Figma 291:123808 의 54px 보조 문구는 공백 1칸(빈 줄)이라 렌더 대상이
        // 아니다. IR 에도 5.3-2 에 text_secondary 가 없다.
      ),
      footer: NextWidget(onPressed: () => _viewModel.onStepChanged(2)),
    );
  }

  /// 3단계 — 기기 목록에서 이름 선택 + [Done].
  WizardStep _buildStep3() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-airplay-3.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        // IR ux_tag 4 — deviceType_01801
        //
        // TODO(unresolved: device-name-source) — {name} 조회 API 미특정.
        description: AppStrings.of(AppStringKeys.selectDeviceFromList),
        // IR ux_tag 4 text_secondary — deviceType_01944
        secondaryDescriptions: <String>[
          AppStrings.of(AppStringKeys.airPlayStep3Secondary),
        ],
      ),
      // IR ux_tag 5 — Done · default_focus: true
      footer: DoneWidget(onPressed: _backToMain),
    );
  }
}
