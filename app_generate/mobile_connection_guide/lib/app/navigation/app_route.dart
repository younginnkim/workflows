// AppRoute — 앱 내 화면 전환 상태.
//
// IR flows/navigation.yaml 의 화면 그래프를 그대로 옮겼다.
//   5.1 (메인) ──on_select 1──> 5.2-* Google Cast 가이드 (위저드 3단계)
//              ──on_select 2──> 5.3-* AirPlay 가이드     (위저드 3단계)
//              ──on_select 3──> 5.4 (paired) | 5.5 (unpaired)
//   각 하위 화면의 Back/Done → 5.1
//
// 위저드 내부 단계 전환은 EWizardPanels 가 담당하므로 여기서는 화면 단위만 둔다.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 화면 단위 목적지.
enum AppRoute {
  /// IR 5 / 5.1 — 스마트폰 공유 가이드 진입 = 메인 화면.
  ///
  /// IR unresolved(view5-vs-view5.1-relation): page 2(5)와 page 3(5.1)의
  /// 목업이 동일하다. 같은 화면의 2단 명세로 읽어 하나의 목적지로 둔다.
  main,

  /// IR 5.2-1 ~ 5.2-3 — Google Cast 가이드 위저드.
  googleCastGuide,

  /// IR 5.3-1 ~ 5.3-3 — AirPlay 가이드 위저드.
  airPlayGuide,

  /// IR 5.4 — 사운드셰어, 연결기기 있을 때.
  soundSharePaired,

  /// IR 5.5 — 사운드셰어, 연결기기 없을 때.
  soundShareUnpaired,
}

/// 현재 화면.
final StateProvider<AppRoute> appRouteProvider = StateProvider<AppRoute>(
  (Ref ref) => AppRoute.main,
);
