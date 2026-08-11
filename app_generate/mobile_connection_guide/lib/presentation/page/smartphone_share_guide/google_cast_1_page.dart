// GoogleCastGuidePage — View (5.2-1 ~ 5.2-3 · Google Cast 가이드 위저드)
//
// Figma 274:116823 / 291:123805 / 291:123806 — 3840x2160 각 3단계
//   Header, webOS26  h 396 · Step Set(60x60 x3, gap 60, top 72)
//                    title headline/108-semibold = sn_home_0023 (3단계 공통)
//                    slotBefore = Previous (아이콘 84 + 라벨 48)
//   Contents         img_connect_googlecast_0N 1860x864 (r36) + Text(66/54)
//   Bottom-Footer    h 300, pb 132 · Button 840x132 (r24)
//                      1,2단계 : [Next]
//                      3단계   : [Google Cast] [완료]  (gap 72)
//
// IR: "해당 화면 동작성은 Pattern, Component의 Wizardview에 따름"
//   → 3단계를 EWizardPanels 로 묶는다 (ESteps·전환 애니메이션·Back 내장).
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/navigation/app_route.dart';
import '../../widget/done_widget.dart';
import '../../widget/guide_dialog_widget.dart';
import '../../widget/inline_guide_icon_widget.dart';
import '../../widget/next_widget.dart';
import '../../widget/wizard_view_widget.dart';
import 'google_cast_1_view_model.dart';

class GoogleCastGuidePage extends ConsumerStatefulWidget {
  const GoogleCastGuidePage({super.key, this.viewModel});

  /// 테스트에서 luna 서비스가 스텁된 ViewModel 을 주입하기 위한 훅.
  final GoogleCastViewModel? viewModel;

  @override
  ConsumerState<GoogleCastGuidePage> createState() =>
      _GoogleCastGuidePageState();
}

class _GoogleCastGuidePageState extends ConsumerState<GoogleCastGuidePage> {
  late final GoogleCastViewModel _viewModel =
      widget.viewModel ?? GoogleCastViewModel();

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

  /// 가이드 종료 → 메인 화면 (IR 5.2-3 ux_tag 6 target: view.5.1).
  void _backToMain() {
    ref.read(appRouteProvider.notifier).state = AppRoute.main;
  }

  @override
  Widget build(BuildContext context) {
    return WizardViewWidget(
      // IR: 3단계 모두 같은 타이틀 (sn_home_0023).
      title: AppStrings.of(AppStringKeys.googleCastLabel),
      // EWizardPanels.index 는 0-based 다 (step 은 IR 의 1-based 표기).
      index: _viewModel.stepIndex,
      onIndexChanged: _viewModel.onStepChanged,
      onExit: _backToMain,
      // 1단계 보조 문구(sn_home_0027)의 표시 여부가 네트워크 구독으로 바뀐다.
      // EWizardPanels 는 패널 내용을 캐시하므로 이 값을 키에 실어야 반영된다.
      contentRevision: _viewModel.showWiredHintText,
      steps: <WizardStep>[_buildStep1(), _buildStep2(), _buildStep3()],
    );
  }

  /// 1단계 — 폰 설정에서 Wi-Fi 켜기.
  WizardStep _buildStep1() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-googlecast-1.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        secondaryKey: const <int, Key>{0: Key('secondaryHintText')},
        // IR ux_tag 4 — sn_home_0026
        description: AppStrings.of(AppStringKeys.googleCastStep1),
        inlineIconPlaceholder: '{%androidset_icon}',
        inlineIcon: const InlineGuideIconWidget(
          icon: LimestoneIcons.gear,
          semanticsLabel: 'Settings',
          // Figma ic_setting_aos: bg #4298fd
          backgroundColor: Color(0xFF4298FD),
        ),
        // IR ux_tag 4-1 — 유선 연결 상태면 미제공 (sn_home_0027)
        secondaryDescriptions: <String>[
          if (_viewModel.showWiredHintText)
            AppStrings.of(AppStringKeys.googleCastStep1Secondary),
        ],
      ),
      footer: NextWidget(onPressed: () => _viewModel.onStepChanged(1)),
    );
  }

  /// 2단계 — 유튜브에서 캐스팅 아이콘 선택.
  WizardStep _buildStep2() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-googlecast-2.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        // IR ux_tag 4 — sn_home_0028
        description: AppStrings.of(AppStringKeys.googleCastStep2),
        inlineIconPlaceholder: '{%casting_icon}',
        inlineIcon: InlineGuideIconWidget(
          icon: LimestoneIcons.screenshare,
          // IR: Audio Guidance — {%casting_icon} 은 'Cast' 로 발화 (sn_home_0117)
          semanticsLabel: AppStrings.of(AppStringKeys.a11yCast),
        ),
        // IR ux_tag 4 text_secondary — sn_home_0029
        secondaryDescriptions: <String>[
          AppStrings.of(AppStringKeys.googleCastStep2Secondary),
        ],
      ),
      footer: NextWidget(onPressed: () => _viewModel.onStepChanged(2)),
    );
  }

  /// 3단계 — 기기 목록에서 이름 선택 + [Google Cast] / [Done].
  WizardStep _buildStep3() {
    return WizardStep(
      body: GuideDialogWidget(
        imageAsset: 'assets/images/guide-googlecast-3.png',
        imageKey: const Key('guideImage'),
        descriptionKey: const Key('descriptionText'),
        // IR ux_tag 4 — deviceType_01801
        //
        // TODO(unresolved: device-name-source)
        //   {name} 자리에 넣을 기기 이름 조회 API 가 특정되지 않았다.
        //   확정되면 AppStrings.of(..., deviceName: ...) 로 치환한다.
        description: AppStrings.of(AppStringKeys.selectDeviceFromList),
        // IR ux_tag 4 text_secondary — deviceType_01943
        secondaryDescriptions: <String>[
          AppStrings.of(AppStringKeys.googleCastStep3Secondary),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // IR ux_tag 5 — 구글캐스트로 이동 (sn_home_0032)
          EButton(
            key: const Key('googleCastButton'),
            text: AppStrings.of(AppStringKeys.googleCastButton),
            onPressed: _viewModel.onGoogleCastSelected,
          ),
          // Figma Bottom-Footer gap: spacing/72
          SizedBox(width: 72.h),
          // IR ux_tag 6 — Done · default_focus: true
          DoneWidget(onPressed: _backToMain),
        ],
      ),
    );
  }
}
