// IR test-scenarios.yaml — view 5 (진입 화면) · view 5.1 (메인 화면)
//
// 앱은 IR unresolved(view5-vs-view5.1-relation) 에 따라 두 뷰를 하나의 MainPage 로
// 구현했으므로 두 뷰의 시나리오가 같은 파일에 온다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_connection_guide/app/l10n/app_strings.dart';
import 'package:mobile_connection_guide/app/navigation/app_route.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/main_page.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/main_view_model.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  group('view 5 — smartphone_share_guide', () {
    testWidgets('renders_title_and_description_from_i18n', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const MainPage());

      // ux_tag 1 — 타이틀. EHeader 는 EMarquee 로 렌더하므로 find.text 가 아니다.
      expect(
        findMarquee(AppStrings.of(AppStringKeys.guideTitle)),
        findsOneWidget,
      );
      // ux_tag 2 — deviceType_01941. %deviceType% 치환 후 문구와 비교한다.
      expect(
        find.text(AppStrings.of(AppStringKeys.entryDescription)),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('renders_three_feature_cards', (WidgetTester tester) async {
      await pumpApp(tester, const MainPage());

      expect(find.byKey(const Key('featureCardList')), findsOneWidget);
      // ECard 의 cardCaption 도 EHeader 타이틀과 같이 EMarquee 로 렌더된다.
      expect(
        findMarquee(AppStrings.of(AppStringKeys.googleCastLabel)),
        findsOneWidget,
      );
      expect(
        findMarquee(AppStrings.of(AppStringKeys.airPlayLabel)),
        findsOneWidget,
      );
      expect(
        findMarquee(AppStrings.of(AppStringKeys.soundShareLabel)),
        findsOneWidget,
      );
      // widget_at_index / count_eq 3 — 카드가 정확히 3개다.
      expect(
        find.descendant(
          of: find.byKey(const Key('featureCardList')),
          matching: find.byType(ECard),
        ),
        findsNWidgets(3),
      );

      await forceDispose(tester);
    });

    testWidgets('title_is_not_focusable', (WidgetTester tester) async {
      await pumpApp(tester, const MainPage());

      // IR: ux_tag 1 은 "선택 불가 영역". 타이틀은 EHeader 안의 EMarquee 로만
      // 렌더되므로 그 서브트리에 focusable 이 없어야 한다.
      final Finder title = findMarquee(AppStrings.of(AppStringKeys.guideTitle));
      expect(title, findsOneWidget);
      expect(
        find.descendant(of: title, matching: find.byType(EFocusable)),
        findsNothing,
      );

      await forceDispose(tester);
    });

    testWidgets('announces_entry_guidance_with_total_items', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpApp(tester, const MainPage());

        // IR accessibility#views[0].on_screen_enter (sn_home_0096/0097)
        final String label = tester
            .getSemantics(find.byKey(const Key('smartphoneShareGuideRoot')))
            .label;
        expect(label, contains('Enjoy Smartphone Content'));
        expect(label, contains('3 items in total'));
        expect(label, contains('button'));

        await forceDispose(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('exit_icon_announces_exit_app', (WidgetTester tester) async {
      await pumpApp(tester, const MainPage());

      // IR accessibility#views[0].on_focus[1] (sn_home_0098).
      // EHeader 의 close 버튼은 내부 생성이라 Key 를 못 붙인다 → semanticsLabel
      // 프로퍼티로 찾는다 (elemental 자체 테스트와 같은 방식).
      expect(findExitIcon(), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('exit_icon_navigates_back', (WidgetTester tester) async {
      final List<String> calls = recordSystemNavigatorCalls(tester);
      await pumpApp(tester, const MainPage());

      await tester.tap(findExitIcon());
      await tester.pumpAndSettle();

      // IR behaviors#views[0].components[3] — 종료 아이콘 선택 시 앱을 벗어난다.
      expect(calls, contains('SystemNavigator.pop'));

      await forceDispose(tester);
    });

    testWidgets('remote_back_exits_view_same_as_exit_icon', (
      WidgetTester tester,
    ) async {
      final List<String> calls = recordSystemNavigatorCalls(tester);
      await pumpApp(tester, const MainPage());

      await pressBack(tester);

      // IR behaviors#views[0].screen.exit — 리모컨 [Back] 이 종료 아이콘과 같다.
      expect(calls, contains('SystemNavigator.pop'));

      await forceDispose(tester);
    });
  });

  group('view 5.1 — smartphone_share_main', () {
    /// 5.1 은 카드별 분기가 핵심이라 매 시나리오가 스텁을 갖는다.
    ({
      MainViewModel vm,
      FakeConnectionmanagerService net,
      FakeBluetooth2Service bt,
      FakeApplicationmanagerService app,
    })
    build({
      required bool online,
      List<Map<String, dynamic>> pairedDevices = const <Map<String, dynamic>>[],
    }) {
      final FakeConnectionmanagerService net = FakeConnectionmanagerService(
        <String, dynamic>{
          'isInternetConnectionAvailable': online,
          'wifi': <String, dynamic>{'state': online ? 'connected' : 'disconnected'},
          'wired': const <String, dynamic>{'state': 'disconnected'},
        },
      );
      final FakeBluetooth2Service bt = FakeBluetooth2Service(
        pairedDevices: pairedDevices,
      );
      final FakeApplicationmanagerService app = FakeApplicationmanagerService();
      return (
        vm: MainViewModel(
          connectionmanager: net,
          bluetooth2: bt,
          applicationmanager: app,
        ),
        net: net,
        bt: bt,
        app: app,
      );
    }

    testWidgets('cast_card_opens_google_cast_guide_when_network_ok', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: true);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardGoogleCast')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        hasCall(
          f.net.calls,
          'luna://com.webos.service.connectionmanager/getStatus',
          params: const <String, dynamic>{'subscribe': true},
        ),
        isTrue,
      );
      // navigated → view.5.2-1 (화면 층 = appRouteProvider)
      expect(container.read(appRouteProvider), AppRoute.googleCastGuide);

      await forceDispose(tester);
    });

    testWidgets('cast_card_shows_network_popup_when_offline', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: false);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardGoogleCast')));
      await tester.pump(const Duration(milliseconds: 500));

      // 팝업 본문 (sn_home_0020) 이 보이고, 화면 전환은 없다.
      expect(
        find.text(AppStrings.of(AppStringKeys.networkRequiredBody)),
        findsOneWidget,
      );
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('airplay_card_opens_airplay_guide_when_network_ok', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: true);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardAirPlay')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(appRouteProvider), AppRoute.airPlayGuide);

      await forceDispose(tester);
    });

    testWidgets('airplay_card_shows_network_popup_when_offline', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: false);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardAirPlay')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(AppStrings.of(AppStringKeys.networkRequiredBody)),
        findsOneWidget,
      );
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('soundshare_card_opens_connected_view_when_paired_history_exists', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(
        online: true,
        pairedDevices: const <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Galaxy S24', 'address': 'AA:BB:CC:DD:EE:FF'},
        ],
      );
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardSoundShare')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        hasCall(
          f.bt.calls,
          'luna://com.webos.service.bluetooth2/device/getPairedDevices',
        ),
        isTrue,
      );
      expect(container.read(appRouteProvider), AppRoute.soundSharePaired);

      await forceDispose(tester);
    });

    testWidgets('soundshare_card_opens_no_device_view_when_no_paired_history', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: true);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardSoundShare')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(appRouteProvider), AppRoute.soundShareUnpaired);

      await forceDispose(tester);
    });

    testWidgets('soundshare_card_skips_network_popup_when_offline', (
      WidgetTester tester,
    ) async {
      // IR: 네트워크 팝업은 카드 1/2 에만 적용된다 — 카드 3 은 오프라인이어도
      // 팝업 없이 바로 5.5 로 간다.
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: false);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardSoundShare')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(AppStrings.of(AppStringKeys.networkRequiredBody)),
        findsNothing,
      );
      expect(container.read(appRouteProvider), AppRoute.soundShareUnpaired);

      await forceDispose(tester);
    });

    testWidgets('popup_yes_launches_network_settings', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: false);
      await pumpApp(tester, MainPage(viewModel: f.vm));

      await tester.tap(find.byKey(const Key('cardGoogleCast')));
      await tester.pump(const Duration(milliseconds: 500));
      // do: select, item: "Yes" — EAlertButton 은 내부 EButton 으로 렌더된다.
      await tester.tap(findButtonWithText(AppStrings.of(AppStringKeys.yes)));
      await tester.pump(const Duration(milliseconds: 500));

      // decision: launch-network-settings
      expect(
        hasCall(
          f.app.calls,
          'luna://com.webos.service.applicationmanager/launch',
          params: const <String, dynamic>{
            'id': 'com.webos.app.settings',
            'params': <String, dynamic>{'target': 'network'},
          },
        ),
        isTrue,
      );

      await forceDispose(tester);
    });

    testWidgets('popup_no_closes_popup_without_navigating', (
      WidgetTester tester,
    ) async {
      final ({
        MainViewModel vm,
        FakeConnectionmanagerService net,
        FakeBluetooth2Service bt,
        FakeApplicationmanagerService app,
      })
      f = build(online: false);
      final ProviderContainer container = await pumpApp(
        tester,
        MainPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('cardGoogleCast')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(findButtonWithText(AppStrings.of(AppStringKeys.no)));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(AppStrings.of(AppStringKeys.networkRequiredBody)),
        findsNothing,
      );
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('card_focus_order_is_cast_airplay_soundshare', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const MainPage());

      // components#views[1] focus_order 1,2,3 — 좌→우 배치가 곧 포커스 순서다.
      final double cast = tester
          .getTopLeft(find.byKey(const Key('cardGoogleCast')))
          .dx;
      final double airplay = tester
          .getTopLeft(find.byKey(const Key('cardAirPlay')))
          .dx;
      final double sound = tester
          .getTopLeft(find.byKey(const Key('cardSoundShare')))
          .dx;
      expect(cast, lessThan(airplay));
      expect(airplay, lessThan(sound));

      await forceDispose(tester);
    });

    testWidgets('focus_moves_right_from_cast_to_airplay', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const MainPage());

      // do: focus, target: cardGoogleCast → do: press, key: RIGHT
      await focusByHover(tester, find.byKey(const Key('cardGoogleCast')));
      expect(isFocusInside(tester, const Key('cardGoogleCast')), isTrue);

      await pressRight(tester);

      expect(isFocusInside(tester, const Key('cardAirPlay')), isTrue);

      await forceDispose(tester);
    });
  });
}

/// EButton 을 라벨로 찾는다 (EAlertButton 은 내부 EButton 으로 렌더된다).
Finder findButtonWithText(String text) => find.byWidgetPredicate(
  (Widget w) => w is EButton && w.text == text,
);

/// EHeader 의 종료(close) 아이콘 — 내부 생성이라 Key 를 붙일 수 없다.
Finder findExitIcon() => find.byWidgetPredicate(
  (Widget w) =>
      w is EButton &&
      w.icon == LimestoneIcons.closex &&
      w.semanticsLabel == AppStrings.of(AppStringKeys.a11yExitApp),
);
