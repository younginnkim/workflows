// App — 앱 루트 + 화면 전환.
//
// IR flows/navigation.yaml 의 화면 그래프를 AppRoute 로 옮겨 두고, 여기서
// 목적지별 페이지를 렌더한다. 위저드 내부 단계 전환은 EWizardPanels 담당.
//
// i18n: EAppMain.run 이 assets/i18n 을 스캔해 LocalizedApp 으로 감싸므로
// AppStrings.of() 의 translate() 가 그대로 동작한다 (main.dart 참고).
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/navigation/app_route.dart';
import 'presentation/page/smartphone_share_guide/air_play_1_page.dart';
import 'presentation/page/smartphone_share_guide/entry_page.dart';
import 'presentation/page/smartphone_share_guide/google_cast_1_page.dart';
import 'presentation/page/smartphone_share_guide/sound_share_paired_page.dart';
import 'presentation/page/smartphone_share_guide/sound_share_unpaired_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: EApp(child: _RootView()));
  }
}

/// 현재 [AppRoute] 에 해당하는 화면을 렌더한다.
class _RootView extends ConsumerWidget {
  const _RootView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRoute route = ref.watch(appRouteProvider);

    return switch (route) {
      // IR 5 / 5.1 — 진입 화면 = 메인 화면 (동일 목업).
      AppRoute.main => const EntryPage(),
      // IR 5.2-1 ~ 5.2-3 — Google Cast 가이드 위저드.
      AppRoute.googleCastGuide => const GoogleCastGuidePage(),
      // IR 5.3-1 ~ 5.3-3 — AirPlay 가이드 위저드.
      AppRoute.airPlayGuide => const AirPlayGuidePage(),
      // IR 5.4 — 사운드셰어, 연결기기 있을 때.
      AppRoute.soundSharePaired => const SoundSharePairedPage(),
      // IR 5.5 — 사운드셰어, 연결기기 없을 때.
      AppRoute.soundShareUnpaired => const SoundShareUnpairedPage(),
    };
  }
}
