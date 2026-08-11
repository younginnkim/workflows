// IR test-scenarios.yaml — view 5.2-1 / 5.2-2 / 5.2-3 (Google Cast 가이드 위저드)
//
// 앱은 IR 의 "동작성은 Wizardview 에 따름" 에 맞춰 3단계를 하나의 EWizardPanels
// (GoogleCastGuidePage) 로 구현했으므로 세 뷰의 시나리오가 같은 파일에 온다.
//
// 단계 전환(`navigated → view.5.2-2`)은 화면 라우트가 아니라 위저드 index 다 —
// AppRoute 에는 5.2-2 에 해당하는 값이 없다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_connection_guide/app/l10n/app_strings.dart';
import 'package:mobile_connection_guide/app/navigation/app_route.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/google_cast_1_page.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/google_cast_1_view_model.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

/// 스텁된 네트워크 상태로 위저드 ViewModel 을 만든다.
({GoogleCastViewModel vm, FakeConnectionmanagerService net}) buildVm({
  bool wired = false,
  bool online = true,
}) {
  final FakeConnectionmanagerService net = FakeConnectionmanagerService(
    <String, dynamic>{
      'isInternetConnectionAvailable': online,
      'wifi': <String, dynamic>{'state': wired ? 'disconnected' : 'connected'},
      'wired': <String, dynamic>{
        'state': wired ? 'connected' : 'disconnected',
        if (wired) 'interfaceName': 'eth0',
      },
    },
  );
  return (
    vm: GoogleCastViewModel(connectionmanager: net),
    net: net,
  );
}

void main() {
  group('view 5.2-1 — google_cast_guide_step1', () {
    testWidgets('renders_step_indicator_at_step_one_of_three', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      // ESteps 는 EWizardPanels 가 내부 생성해 Key 를 못 붙인다 → 타입으로 찾는다.
      expect(find.byType(ESteps), findsOneWidget);
      // state_changed field: step, value: 1 (IR 은 1-based)
      expect(f.vm.step, 1);

      await forceDispose(tester);
    });

    testWidgets('renders_title_and_primary_description_from_i18n', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      // 타이틀 sn_home_0023 — EHeader 는 EMarquee 로 렌더한다.
      expect(
        findMarquee(AppStrings.of(AppStringKeys.googleCastLabel)),
        findsOneWidget,
      );
      // sn_home_0026 은 {%androidset_icon} 를 WidgetSpan 으로 쪼개 Text.rich 로
      // 렌더하므로 단일 Text 가 없다 → RichText 평문에서 부분 문자열을 본다.
      expect(
        findRichTextContaining('Go to Settings'),
        findsWidgets,
      );
      expect(find.byKey(const Key('guideImage')), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('shows_secondary_hint_when_not_wired', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm(wired: false);
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      expect(
        hasCall(
          f.net.calls,
          'luna://com.webos.service.connectionmanager/getStatus',
          params: const <String, dynamic>{'subscribe': true},
        ),
        isTrue,
      );
      expect(find.byKey(const Key('secondaryHintText')), findsOneWidget);
      expect(
        find.text(AppStrings.of(AppStringKeys.googleCastStep1Secondary)),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('hides_secondary_hint_when_wired_connected', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm(wired: true);
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      // IR: "기기가 유선 네트워크로 연결된 상태일 때는 미제공함"
      expect(find.byKey(const Key('secondaryHintText')), findsNothing);

      await forceDispose(tester);
    });

    testWidgets('secondary_hint_updates_when_network_state_changes', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm(wired: true);
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));
      expect(find.byKey(const Key('secondaryHintText')), findsNothing);

      // do: emit — 유선이 끊기고 무선이 붙으면 보조 문구가 나타난다.
      f.net.emit(<String, dynamic>{
        'isInternetConnectionAvailable': true,
        'wired': <String, dynamic>{'state': 'disconnected'},
        'wifi': <String, dynamic>{'state': 'connected'},
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('secondaryHintText')), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('next_button_has_default_focus', (WidgetTester tester) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      // IR accessibility#views[2].initial_focus — Next 가 Default Focus.
      final EButton next = tester.widget<EButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(next.autoFocus, isTrue);
      expect(next.text, AppStrings.of(AppStringKeys.next));

      await forceDispose(tester);
    });

    testWidgets('next_navigates_to_step2', (WidgetTester tester) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      await pumpApp(tester, GoogleCastGuidePage(viewModel: f.vm));

      await tapWizardNext(tester);

      // navigated → view.5.2-2 (위저드 단계 층)
      expect(f.vm.step, 2);

      await forceDispose(tester);
    });

    testWidgets('previous_button_navigates_back', (WidgetTester tester) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        GoogleCastGuidePage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('previousButton')));
      await settleWizard(tester);

      // 첫 단계의 Previous 는 위저드를 벗어나 5.1 로 돌아간다.
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('remote_back_matches_previous_button', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        GoogleCastGuidePage(viewModel: f.vm),
      );

      await pressBack(tester);

      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });
  });

  group('view 5.2-2 — google_cast_guide_step2', () {
    /// 2단계로 진입한 상태를 만든다 (Next 한 번).
    Future<({GoogleCastViewModel vm, ProviderContainer container})> atStep2(
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        GoogleCastGuidePage(viewModel: f.vm),
      );
      await tapWizardNext(tester);
      return (vm: f.vm, container: container);
    }

    testWidgets('renders_step_two_with_step_one_completed', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, ProviderContainer container}) s =
          await atStep2(tester);

      expect(s.vm.step, 2);
      expect(s.vm.completedSteps, <int>[1]);

      await forceDispose(tester);
    });

    testWidgets('renders_both_description_lines_from_i18n', (
      WidgetTester tester,
    ) async {
      await atStep2(tester);

      // sn_home_0028 은 {%casting_icon} 로 쪼개진다 → RichText 평문 검사.
      expect(findRichTextContaining('after opening YouTube app'), findsWidgets);
      // sn_home_0029 는 보조 문구(단일 Text).
      expect(
        find.text(AppStrings.of(AppStringKeys.googleCastStep2Secondary)),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('casting_icon_announced_as_cast', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await atStep2(tester);

        // IR accessibility#views[3].icon_utterance (sn_home_0117 = 'Cast').
        // 아이콘은 descriptionText 안의 WidgetSpan → Semantics(label: 'Cast').
        final String label = tester
            .getSemantics(find.byKey(const Key('descriptionText')))
            .label;
        expect(label, contains(AppStrings.of(AppStringKeys.a11yCast)));

        await forceDispose(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('next_button_has_default_focus', (WidgetTester tester) async {
      await atStep2(tester);

      final EButton next = tester.widget<EButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(next.autoFocus, isTrue);

      await forceDispose(tester);
    });

    testWidgets('next_navigates_to_step3', (WidgetTester tester) async {
      final ({GoogleCastViewModel vm, ProviderContainer container}) s =
          await atStep2(tester);

      await tapWizardNext(tester);

      expect(s.vm.step, 3);

      await forceDispose(tester);
    });

    testWidgets('previous_navigates_back_to_step1', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, ProviderContainer container}) s =
          await atStep2(tester);

      expect(
        find.text(AppStrings.of(AppStringKeys.previous)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('previousButton')));
      await settleWizard(tester);

      // navigated_back → 1단계 (위저드 단계 층)
      expect(s.vm.step, 1);

      await forceDispose(tester);
    });
  });

  group('view 5.2-3 — google_cast_guide_step3', () {
    /// 3단계로 진입한 상태 (Next 두 번).
    Future<({GoogleCastViewModel vm, ProviderContainer container})> atStep3(
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, FakeConnectionmanagerService net}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        GoogleCastGuidePage(viewModel: f.vm),
      );
      for (int i = 0; i < 2; i++) {
        await tapWizardNext(tester);
      }
      return (vm: f.vm, container: container);
    }

    testWidgets('renders_step_three_with_two_completed', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, ProviderContainer container}) s =
          await atStep3(tester);

      expect(s.vm.step, 3);
      expect(s.vm.completedSteps, <int>[1, 2]);

      await forceDispose(tester);
    });

    testWidgets('renders_device_selection_description_from_i18n', (
      WidgetTester tester,
    ) async {
      await atStep3(tester);

      expect(
        find.text(AppStrings.of(AppStringKeys.selectDeviceFromList)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.of(AppStringKeys.googleCastStep3Secondary)),
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
      expect(done.text, AppStrings.of(AppStringKeys.done));

      await forceDispose(tester);
    });

    testWidgets('done_closes_guide_and_returns_to_main', (
      WidgetTester tester,
    ) async {
      final ({GoogleCastViewModel vm, ProviderContainer container}) s =
          await atStep3(tester);

      await tester.tap(find.byKey(const Key('doneButton')));
      await settleWizard(tester);

      // IR: Done 은 navigate_internal → view.5.1 (위저드 전체를 빠져나온다).
      expect(s.container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('focus_order_is_previous_googlecast_done', (
      WidgetTester tester,
    ) async {
      await atStep3(tester);

      // accessibility#views[4].focus_order — Previous(헤더 좌측) →
      // Google Cast → Done (Footer 좌→우).
      final Offset previous = tester.getTopLeft(
        find.byKey(const Key('previousButton')),
      );
      final Offset cast = tester.getTopLeft(
        find.byKey(const Key('googleCastButton')),
      );
      final Offset done = tester.getTopLeft(
        find.byKey(const Key('doneButton')),
      );
      // Previous 는 헤더에 있어 y 가 가장 작다.
      expect(previous.dy, lessThan(cast.dy));
      // Footer 안에서는 Google Cast 가 Done 보다 왼쪽이다.
      expect(cast.dx, lessThan(done.dx));

      await forceDispose(tester);
    });
  });
}
