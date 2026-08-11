// SoundSharePairedPage — View (5.4 · 사운드셰어 > 연결기기 있을 때)
//
// Figma 291:123810 ("사운드셰어 > 연결기기 있을 때") — 3840x2160
//   Header, webOS26  title headline/108-semibold = deviceType_01942
//                    back/close 없음 (showBack=false, showClose=false)
//   Contents         img_connect_bluetooth_01 1860x864 (r36)
//                    Text  main 66  = deviceType_01793
//                          sub  54  = 기기 이름 : {%TV_name}
//                          sub  54  = 최근 연결한 기기 : {%Mobile_name}
//   Bottom-Footer    [닫기] [연결하기]  840x132, gap 72
//
// 주의: 사용자가 준 링크 라벨과 Figma 노드 이름이 뒤바뀌어 있었다.
// Figma 노드 이름(권장, 사용자 확인)을 따른다 — 291:123810 이 '있을 때'이고
// 화면 내용(연결하기 버튼 + 최근 연결한 기기 행)도 IR 5.4 와 일치한다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/navigation/app_route.dart';
import '../../widget/guide_dialog_widget.dart';
import 'sound_share_paired_view_model.dart';

class SoundSharePairedPage extends ConsumerStatefulWidget {
  const SoundSharePairedPage({super.key, this.viewModel});

  /// 테스트에서 luna 서비스가 스텁된 ViewModel 을 주입하기 위한 훅.
  final SoundSharePairedViewModel? viewModel;

  @override
  ConsumerState<SoundSharePairedPage> createState() =>
      _SoundSharePairedPageState();
}

class _SoundSharePairedPageState extends ConsumerState<SoundSharePairedPage> {
  late final SoundSharePairedViewModel _viewModel =
      widget.viewModel ?? SoundSharePairedViewModel();

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

  /// IR exit — "Back 시, 이전 화면(메인화면)으로 이동" (target: view.5.1).
  void _backToMain() {
    ref.read(appRouteProvider.notifier).state = AppRoute.main;
  }

  @override
  Widget build(BuildContext context) {
    return EPanel(
      key: const Key('soundShareConnectedRoot'),
      // EPanel 기본 bodyPadding 은 좌우 114.h 다. GuideDialogWidget 이 이미
      // Figma Contents 의 px 324 를 적용하므로 여기서 0 으로 두어야 324 가
      // 그대로 유지된다 (그대로 두면 438 이 되어 Figma 와 어긋난다).
      customLayout: EPanelLayout(bodyPadding: EdgeInsets.zero),
      // IR accessibility#views[8].on_screen_enter —
      //   {title} + {description} + {default_focus_item_label} + "button"
      semanticsLabel: _entryAnnouncement(),
      header: EHeader(
        title: AppStrings.of(AppStringKeys.soundShareLabel),
        centered: true,
        // Figma: showBack=false, showClose=false — 버튼은 숨기지만 리모컨 Back 은
        // 동작해야 한다. onBack 이 null 이면 EPanel 의 escape 핸들러가 no-op 이라
        // (e_panel.dart:1161-1169) Back 이 완전히 죽는다.
        // IR exit: "Back 시, 이전 화면(메인화면)으로 이동" (target: view.5.1)
        noBackButton: true,
        noCloseButton: true,
        onBack: _backToMain,
        noSubtitle: true,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GuideDialogWidget(
            imageAsset: 'assets/images/guide-soundshare-paired.png',
            imageKey: const Key('guideImage'),
            descriptionKey: const Key('descriptionText'),
            // IR ux_tag 5 — 최근 연결 기기 라벨은 보조 문구의 두 번째 항목이다
            // (첫 항목은 ux_tag 4 기기 이름).
            secondaryKey: const <int, Key>{1: Key('recentDeviceLabel')},
            // IR ux_tag 3 — deviceType_01793
            description: AppStrings.of(AppStringKeys.soundShareDescription),
            secondaryDescriptions: <String>[
              // IR ux_tag 4 — "%deviceType% Name : {name}"
              //
              // TODO(unresolved: device-name-source)
              //   기기 이름 조회 API 미특정 → deviceName 이 null 이면 문구의
              //   {name} 플레이스홀더가 그대로 노출된다 (추측값 넣지 않음).
              AppStrings.of(
                AppStringKeys.deviceNameLabel,
                deviceName: _viewModel.deviceName,
              ),
              // IR ux_tag 5 — sn_home_0086 "Recently Connected Device : {...}"
              AppStrings.of(
                AppStringKeys.recentDeviceLabel,
                mobileName: _viewModel.recentDeviceName,
              ),
            ],
          ),
          SizedBox(height: 84.h),
          _buildFooter(),
        ],
      ),
    );
  }

  /// IR accessibility#views[8].on_screen_enter 의 발화 문구를 합성한다.
  ///
  /// bindings: title=ux_tag 1 (deviceType_01942), description=ux_tag 3
  /// (deviceType_01793), default_focus_item_label='Connect'.
  /// view 5 와 달리 "{total} items in total" 은 없다.
  String _entryAnnouncement() => <String>[
    AppStrings.of(AppStringKeys.soundShareLabel),
    AppStrings.of(AppStringKeys.soundShareDescription),
    AppStrings.of(AppStringKeys.connect),
    AppStrings.of(AppStringKeys.a11yButton),
  ].join(' ');

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // IR ux_tag 6 — [닫기] · navigate_back
        EButton(
          key: const Key('closeButton'),
          text: AppStrings.of(AppStringKeys.close),
          onPressed: _backToMain,
        ),
        // Figma Bottom-Footer gap: spacing/72
        SizedBox(width: 72.h),
        // IR ux_tag 7 — [연결하기] · default_focus: true
        EButton(
          key: const Key('connectButton'),
          text: AppStrings.of(AppStringKeys.connect),
          autoFocus: true,
          // 연결 진행 중에는 중복 입력을 막는다.
          disabled: _viewModel.isConnecting,
          onPressed: _viewModel.connectRecentDevice,
        ),
      ],
    );
  }
}
