// IR test-scenarios.yaml — view 5.3-1 / 5.3-2 / 5.3-3 (AirPlay 가이드 위저드)
//
// Google Cast 위저드와 구조가 같다 (하나의 EWizardPanels = AirPlayGuidePage).
// 차이: 3단계 Footer 가 Done 하나뿐이고 외부 앱 실행 버튼이 없다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_connection_guide/app/l10n/app_strings.dart';
import 'package:mobile_connection_guide/app/navigation/app_route.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/air_play_1_page.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/air_play_1_view_model.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

({AirPlayViewModel vm, FakeConnectionmanagerService net}) buildVm({
  bool wired = false,
}) {
  final FakeConnectionmanagerService net = FakeConnectionmanagerService(
    <String, dynamic>{
      'isInternetConnectionAvailable': true,
      'wifi': <String, dynamic>{'state': wired ? 'disconnected' : 'connected'},
      'wired': <String, dynamic>{
        'state': wired ? 'connected' : 'disconnected',
        if (wired) 'interfaceName': 'eth0',
      },
    },
  );
  return (vm: AirPlayViewModel(connectionmanager: net), net: net);
}

void main() {
  group('view 5.3-1 — airplay_guide_step1', () {
    testWidgets('renders_step_one_title_and_description', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, AirPlayGuidePage(viewModel: f.vm));

      expect(f.vm.step, 1);
      // sn_home_0024 — 타이틀은 EMarquee.
      expect(
        findMarquee(AppStrings.of(AppStringKeys.airPlayLabel)),
        findsOneWidget,
      );
      // sn_home_0033 은 {%iphoneset_icon} 로 쪼개진다 → RichText 평문 검사.
      expect(findRichTextContaining('Go to Settings'), findsWidgets);

      await forceDispose(tester);
    });

    testWidgets('shows_secondary_hint_when_not_wired', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm(wired: false);
      await pumpApp(tester, AirPlayGuidePage(viewModel: f.vm));

      expect(
        hasCall(
          f.net.calls,
          'luna://com.webos.service.connectionmanager/getStatus',
          params: const <String, dynamic>{'subscribe': true},
        ),
        isTrue,
      );
      expect(find.byKey(const Key('secondaryHintText')), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('hides_secondary_hint_when_wired_connected', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm(wired: true);
      await pumpApp(tester, AirPlayGuidePage(viewModel: f.vm));

      // IR: "TV가 유선 네트워크로 연결된 상태일 때는 미제공함"
      expect(find.byKey(const Key('secondaryHintText')), findsNothing);

      await forceDispose(tester);
    });

    testWidgets('next_button_has_default_focus', (WidgetTester tester) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, AirPlayGuidePage(viewModel: f.vm));

      final EButton next = tester.widget<EButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(next.autoFocus, isTrue);

      await forceDispose(tester);
    });

    testWidgets('next_navigates_to_step2', (WidgetTester tester) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, AirPlayGuidePage(viewModel: f.vm));

      await tapWizardNext(tester);

      expect(f.vm.step, 2);

      await forceDispose(tester);
    });

    testWidgets('previous_navigates_back', (WidgetTester tester) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        AirPlayGuidePage(viewModel: f.vm),
      );

      // IR 은 이 시나리오를 BACK 키로 명세한다.
      await pressBack(tester);

      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });
  });

  group('view 5.3-2 — airplay_guide_step2', () {
    Future<({AirPlayViewModel vm, ProviderContainer container})> atStep2(
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        AirPlayGuidePage(viewModel: f.vm),
      );
      await tapWizardNext(tester);
      return (vm: f.vm, container: container);
    }

    testWidgets('renders_step_two_with_step_one_completed', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, ProviderContainer container}) s =
          await atStep2(tester);

      expect(s.vm.step, 2);
      expect(s.vm.completedSteps, <int>[1]);

      await forceDispose(tester);
    });

    testWidgets('renders_control_center_description_from_i18n', (
      WidgetTester tester,
    ) async {
      await atStep2(tester);

      // sn_home_0034 은 {%airplay_icon} 로 쪼개진다.
      expect(findRichTextContaining('Open Control Center'), findsWidgets);

      await forceDispose(tester);
    });

    testWidgets('airplay_icon_announced_as_airplay', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await atStep2(tester);

        // IR accessibility#views[6].icon_utterance (sn_home_0118 = 'AirPlay').
        final String label = tester
            .getSemantics(find.byKey(const Key('descriptionText')))
            .label;
        expect(label, contains(AppStrings.of(AppStringKeys.a11yAirPlay)));

        await forceDispose(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('next_navigates_to_step3', (WidgetTester tester) async {
      final ({AirPlayViewModel vm, ProviderContainer container}) s =
          await atStep2(tester);

      // IR 은 이 시나리오에 initial_focus 도 함께 assert 한다 — act 전 상태다.
      final EButton next = tester.widget<EButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(next.autoFocus, isTrue);

      await tapWizardNext(tester);

      expect(s.vm.step, 3);

      await forceDispose(tester);
    });
  });

  group('view 5.3-3 — airplay_guide_step3', () {
    Future<({AirPlayViewModel vm, ProviderContainer container})> atStep3(
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        AirPlayGuidePage(viewModel: f.vm),
      );
      for (int i = 0; i < 2; i++) {
        await tapWizardNext(tester);
      }
      return (vm: f.vm, container: container);
    }

    testWidgets('renders_step_three_with_passcode_description', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, ProviderContainer container}) s =
          await atStep3(tester);

      expect(s.vm.step, 3);
      expect(
        find.text(AppStrings.of(AppStringKeys.selectDeviceFromList)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.of(AppStringKeys.airPlayStep3Secondary)),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('done_button_has_default_focus', (WidgetTester tester) async {
      await atStep3(tester);

      final EButton done = tester.widget<EButton>(
        find.byKey(const Key('doneButton')),
      );
      expect(done.autoFocus, isTrue);

      await forceDispose(tester);
    });

    testWidgets('done_closes_guide_and_returns_to_main', (
      WidgetTester tester,
    ) async {
      final ({AirPlayViewModel vm, ProviderContainer container}) s =
          await atStep3(tester);

      await tester.tap(find.byKey(const Key('doneButton')));
      await settleWizard(tester);

      // IR: Done 은 navigate_internal → view.5.1
      expect(s.container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('previous_navigates_back', (WidgetTester tester) async {
      final ({AirPlayViewModel vm, ProviderContainer container}) s =
          await atStep3(tester);

      await tester.tap(find.byKey(const Key('previousButton')));
      await settleWizard(tester);

      // navigated_back → 2단계 (위저드 단계 층)
      expect(s.vm.step, 2);

      await forceDispose(tester);
    });
  });
}
