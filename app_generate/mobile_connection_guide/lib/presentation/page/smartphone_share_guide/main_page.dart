// MainPage — View (5 / 5.1 · 스마트폰 공유 가이드 진입 = 메인 화면)
//
// Figma 274:116181 (기본) · 2154:16824 (Focused) — 3840x2160
//   Header, webOS26   h 396, pt 156, px 300 · title headline/108-semibold
//                     close 버튼 132x132 (top 102, right 132)
//   설명 문구          body/66-semibold, bodytext/label-main, 중앙
//   Menu              Card Item-Vertical 984x792 x3, gap 120
//                       Image  984x552 (radius/container 36, border 2 → 6 focused)
//                       Bottom 984x240 · label body/60-semibold, 중앙
//
// Focused 변형(2154:16824)은 카드의 border 6/white + scale + shadow-medium 인데,
// 이는 ECard 의 런타임 포커스 상태이므로 별도 위젯을 만들지 않는다 (P2).
//
// 프레임이 뷰포트(2160)에 들어오고 스크롤 인디케이터가 없으므로 스크롤하지
// 않는다 (P5).
import 'package:elemental/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/navigation/app_route.dart';
import '../../popup/network_required_popup.dart';
import 'main_view_model.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key, this.viewModel});

  /// 테스트에서 luna 서비스가 스텁된 ViewModel 을 주입하기 위한 훅.
  /// 프로덕션에서는 null 이고 [_MainPageState] 가 기본 ViewModel 을 만든다.
  final MainViewModel? viewModel;

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late final MainViewModel _viewModel = widget.viewModel ?? MainViewModel();
  final EAlertController _networkPopupController = EAlertController();

  /// Figma Card Item-Vertical, webOS26 (984x792).
  static const double _cardWidth = 984;
  static const double _cardHeight = 792;

  /// Image 영역 984x552 · Bottom 984x240 (Figma 245:25232 metadata).
  static const double _cardImageHeight = 552;

  /// IR ux_tag 3 child_count — 기능 카드 3개. a11y 발화의 {total} 이기도 하다.
  static const int _cardCount = 3;

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
    _networkPopupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        EPanel(
          key: const Key('smartphoneShareGuideRoot'),
          // Figma Contents 는 px 324 이고 Menu(984*3 + gap120*2 = 3192)가
          // 정확히 3840-648 이다. EPanel 기본 bodyPadding(좌우 114.h)을 두면
          // 3612 로 좁아져 카드가 눌리므로 0 으로 둔다.
          customLayout: EPanelLayout(bodyPadding: EdgeInsets.zero),
          // IR accessibility#views[0].on_screen_enter —
          //   {title} + {description} + "{total} items in total"
          //   + {focused_item_label} + "button"
          // EPanel 이 이 라벨을 루트 Semantics 에 씌우므로 진입 시 그대로 발화된다.
          semanticsLabel: _entryAnnouncement(),
          header: EHeader(
            title: AppStrings.of(AppStringKeys.guideTitle),
            centered: true,
            // Figma: 진입 화면에는 back 없이 close(종료 아이콘)만 있다.
            noBackButton: true,
            // IR ux_tag exit_icon: "종료 방법 : 리모컨 [Back] 버튼, 종료 아이콘"
            //   → 종료 아이콘과 리모컨 Back 이 같은 동작이다.
            onClose: SystemNavigator.pop,
            onBack: SystemNavigator.pop,
            closeButtonSemanticsLabel: AppStrings.of(AppStringKeys.a11yExitApp),
            // Figma: 헤더에 subtitle 슬롯 없음 — 설명 문구는 body 최상단.
            noSubtitle: true,
          ),
          body: _buildBody(),
        ),
        // EAlert(useDialog: true) 는 showDialog 로 뜨므로 트리 위치는
        // 레이아웃에 영향을 주지 않는다.
        NetworkRequiredPopup(
          controller: _networkPopupController,
          onConfirm: _viewModel.onNetworkSettingsConfirmed,
          onCancel: () {},
        ),
      ],
    );
  }

  /// IR accessibility#views[0].on_screen_enter 의 발화 문구를 합성한다.
  ///
  /// bindings: title=ux_tag 1, description=ux_tag 2, total=카드 개수(3),
  /// focused_item_label=첫 포커스 카드 라벨(Google Cast).
  String _entryAnnouncement() {
    final String total = AppStrings.of(
      AppStringKeys.a11yTotalItems,
    ).replaceAll('{total}', '$_cardCount');
    return <String>[
      AppStrings.of(AppStringKeys.guideTitle),
      AppStrings.of(AppStringKeys.entryDescription),
      total,
      AppStrings.of(AppStringKeys.googleCastLabel),
      AppStrings.of(AppStringKeys.a11yButton),
    ].join(' ');
  }

  Widget _buildBody() {
    final EFontStyleToken description = EFontTokens.semantic.body66.semibold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // IR ux_tag 2 — 설명 문구 (deviceType_01941).
        Text(
          AppStrings.of(AppStringKeys.entryDescription),
          key: const Key('descriptionText'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EColorTokens.bodyText.labelMain,
            fontSize: description.fontSize.sp,
            fontWeight: description.fontWeight,
            height: 90 / 66, // Figma line-height 90 on fontSize 66
          ),
        ),
        // Figma: 설명 문구 baseline(126) → Menu top(336) 사이 여백.
        SizedBox(height: 210.h),
        _buildMenu(),
      ],
    );
  }

  /// IR ux_tag 3 — 기능 버튼 3개 (Google Cast / AirPlay / Sound Share).
  ///
  /// Figma 가 고정 3개를 명시하므로 데이터 기반 반복이 아니다 → EVirtualList 가
  /// 아니라 Row + 개별 ECard 다 (SKILL Audit 7 의 "data-driven repeat" 아님).
  Widget _buildMenu() {
    return Row(
      key: const Key('featureCardList'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildCard(
          // IR: sn_home_0023 · icon google_cast_icon
          cardKey: const Key('cardGoogleCast'),
          label: AppStrings.of(AppStringKeys.googleCastLabel),
          imageAsset: 'assets/images/card-google-cast.png',
          autoFocus: true,
          onTap: () => _onShareCardSelected(AppRoute.googleCastGuide),
        ),
        // Figma Menu gap: spacing/120
        SizedBox(width: 120.h),
        _buildCard(
          // IR: sn_home_0024 · icon airplay_icon
          cardKey: const Key('cardAirPlay'),
          label: AppStrings.of(AppStringKeys.airPlayLabel),
          imageAsset: 'assets/images/card-airplay.png',
          onTap: () => _onShareCardSelected(AppRoute.airPlayGuide),
        ),
        SizedBox(width: 120.h),
        _buildCard(
          // IR: deviceType_01942 · icon sound_share_icon
          cardKey: const Key('cardSoundShare'),
          label: AppStrings.of(AppStringKeys.soundShareLabel),
          imageAsset: 'assets/images/card-sound-share.png',
          onTap: _onSoundShareCardSelected,
        ),
      ],
    );
  }

  Widget _buildCard({
    required Key cardKey,
    required String label,
    required String imageAsset,
    required VoidCallback onTap,
    bool autoFocus = false,
  }) {
    return SizedBox(
      key: cardKey,
      width: _cardWidth.h,
      height: _cardHeight.h,
      child: ECard(
        cardImage: imageAsset,
        // Figma Image 영역 = 984x636. ECard 기본값(768x432)을 덮어쓴다.
        imageSize: Size(_cardWidth.h, _cardImageHeight.h),
        // Figma: radius/container 36 — roundedImage 가 true 여야 적용된다.
        roundedImage: true,
        cardCaption: label,
        // Figma Bottom: 라벨 중앙 정렬.
        centered: true,
        autoFocus: autoFocus,
        // 보이스/스크린리더 라벨 — 카드 라벨을 그대로 읽는다.
        label: label,
        onTap: onTap,
      ),
    );
  }

  /// 카드 1/2 — 네트워크 상태에 따라 팝업 또는 가이드 진행.
  void _onShareCardSelected(AppRoute guide) {
    switch (_viewModel.resolveShareCardAction()) {
      case MainCardAction.showNetworkRequiredPopup:
        _networkPopupController.open();
      case MainCardAction.showServiceUnavailableToast:
        // TODO(unresolved: service-availability-source)
        //   판단 근거가 확정되면 여기서 토스트를 띄운다:
        //   EToast().show(message: AppStrings.of(
        //       AppStringKeys.serviceUnavailableToast));
        break;
      case MainCardAction.openGuide:
        ref.read(appRouteProvider.notifier).state = guide;
    }
  }

  /// 카드 3 — 연결 이력 유무로 5.4 / 5.5 분기.
  void _onSoundShareCardSelected() {
    final AppRoute target = switch (_viewModel.resolveSoundShareTarget()) {
      SoundShareTarget.paired => AppRoute.soundSharePaired,
      SoundShareTarget.unpaired => AppRoute.soundShareUnpaired,
    };
    ref.read(appRouteProvider.notifier).state = target;
  }
}
