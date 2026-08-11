// SoundShareUnpairedPage — View (5.5 · 사운드셰어 > 연결기기 없을 때)
//
// Figma 291:123811 ("사운드셰어 > 연결기기 없을 때") — 3840x2160
//   Header, webOS26  title headline/108-semibold = deviceType_01942
//                    back/close 없음
//   Contents         img_connect_bluetooth_02 1860x864 (r36)
//                    Text  main 66 = deviceType_01793 + 연결 안내 (2줄)
//                          sub  54 = 기기 이름 : {%TV_name}
//   Bottom-Footer    [닫기] 840x132 (버튼 1개)
//
// Figma 의 main 문구는 2줄이 한 블록(66px)이다:
//   "블루투스로 연결된 스마트폰의 음악을 기기 스피커로 들을 수 있습니다."
//   "폰의 설정에서 블루투스 메뉴를 선택한 뒤, 이 기기와 연결하세요."
// IR 도 text + text_secondary 로 나눠 놨는데 두 번째 문구의 태그는 미확정이다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/navigation/app_route.dart';
import '../../widget/guide_dialog_widget.dart';
import 'sound_share_unpaired_view_model.dart';

class SoundShareUnpairedPage extends ConsumerStatefulWidget {
  const SoundShareUnpairedPage({super.key, this.viewModel});

  /// 테스트에서 luna 서비스가 스텁된 ViewModel 을 주입하기 위한 훅.
  final SoundShareUnpairedViewModel? viewModel;

  @override
  ConsumerState<SoundShareUnpairedPage> createState() =>
      _SoundShareUnpairedPageState();
}

class _SoundShareUnpairedPageState
    extends ConsumerState<SoundShareUnpairedPage> {
  late final SoundShareUnpairedViewModel _viewModel =
      widget.viewModel ?? SoundShareUnpairedViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (!mounted) {
      return;
    }
    // 연결 이력이 생기면 5.4 로 전환한다 (bt-paired-devices 구독 갱신).
    if (!_viewModel.hasNoHistory) {
      ref.read(appRouteProvider.notifier).state = AppRoute.soundSharePaired;
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  /// IR exit — "Back 시, 이전 화면(스마트폰 공유 Q카드 메인화면)으로 이동".
  void _backToMain() {
    ref.read(appRouteProvider.notifier).state = AppRoute.main;
  }

  /// IR accessibility#views[9].on_screen_enter — 5.4 규칙 상속
  /// (inherits_from: "5.4", confirmed_by_user: false).
  /// default focus item 은 Close 다 (5.5 의 유일한 focusable).
  String _entryAnnouncement() => <String>[
    AppStrings.of(AppStringKeys.soundShareLabel),
    AppStrings.of(AppStringKeys.soundShareDescription),
    AppStrings.of(AppStringKeys.close),
    AppStrings.of(AppStringKeys.a11yButton),
  ].join(' ');

  @override
  Widget build(BuildContext context) {
    return EPanel(
      key: const Key('soundShareNoDeviceRoot'),
      // GuideDialogWidget 이 Figma Contents 의 px 324 를 적용하므로 EPanel 의
      // 기본 bodyPadding(좌우 114.h)을 0 으로 둔다 (중복 패딩 방지).
      customLayout: EPanelLayout(bodyPadding: EdgeInsets.zero),
      // IR accessibility#views[9].on_screen_enter — 5.4 규칙을 상속한다
      // (default focus 는 Close).
      semanticsLabel: _entryAnnouncement(),
      header: EHeader(
        title: AppStrings.of(AppStringKeys.soundShareLabel),
        centered: true,
        // Figma: showBack=false, showClose=false — 버튼은 숨기지만 리모컨 Back 은
        // 동작해야 한다. onBack 이 null 이면 EPanel 의 escape 핸들러가 no-op 이다
        // (e_panel.dart:1161-1169).
        // IR exit: "Back 시, 이전 화면(스마트폰 공유 Q카드 메인화면)으로 이동"
        noBackButton: true,
        noCloseButton: true,
        onBack: _backToMain,
        noSubtitle: true,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GuideDialogWidget(
            imageAsset: 'assets/images/guide-soundshare-unpaired.png',
            imageKey: const Key('guideImage'),
            descriptionKey: const Key('descriptionText'),
            // IR ux_tag 3 — deviceType_01793 + 연결 안내를 한 블록으로 렌더한다
            // (Figma 의 66px 문구가 2줄 한 덩어리).
            //
            // TODO(unresolved: soundshare-no-device-secondary-tag)
            //   두 번째 문장의 문구태그가 PDF에 없어 별도 키를 쓴다.
            description:
                '${AppStrings.of(AppStringKeys.soundShareDescription)}\n'
                '${AppStrings.of(AppStringKeys.soundShareConnectHint)}',
            secondaryDescriptions: <String>[
              // IR ux_tag 4 — "%deviceType% Name : {name}"
              //
              // TODO(unresolved: device-name-source) — 조회 API 미특정.
              AppStrings.of(
                AppStringKeys.deviceNameLabel,
                deviceName: _viewModel.deviceName,
              ),
            ],
          ),
          SizedBox(height: 84.h),
          // IR ux_tag 5 — [닫기] · default_focus: true
          //
          // IR unresolved(default-focus-5.5): PDF에 'Default Focus' 명시가 없으나
          // 이 화면의 유일한 focusable 이므로 Close 로 둔다.
          EButton(
            key: const Key('closeButton'),
            text: AppStrings.of(AppStringKeys.close),
            autoFocus: true,
            onPressed: _backToMain,
          ),
        ],
      ),
    );
  }
}
