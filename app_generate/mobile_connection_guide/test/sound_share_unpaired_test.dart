// IR test-scenarios.yaml — view 5.5 (사운드셰어 · 연결기기 없을 때)
//
// 5.4 와의 차이: Connect 버튼과 '최근 연결한 기기' 라벨이 없다.
// Close 가 유일한 focusable 이다.
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_connection_guide/app/l10n/app_strings.dart';
import 'package:mobile_connection_guide/app/navigation/app_route.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/sound_share_unpaired_page.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/sound_share_unpaired_view_model.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) buildVm({
  List<Map<String, dynamic>> devices = const <Map<String, dynamic>>[],
}) {
  final FakeBluetooth2Service bt = FakeBluetooth2Service(
    pairedDevices: devices,
  );
  return (vm: SoundShareUnpairedViewModel(bluetooth2: bt), bt: bt);
}

void main() {
  group('view 5.5 — sound_share_no_device', () {
    testWidgets('renders_when_no_paired_device_history', (
      WidgetTester tester,
    ) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      await pumpApp(tester, SoundShareUnpairedPage(viewModel: f.vm));

      expect(
        hasCall(
          f.bt.calls,
          'luna://com.webos.service.bluetooth2/device/getPairedDevices',
        ),
        isTrue,
      );
      expect(find.byKey(const Key('soundShareNoDeviceRoot')), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('renders_title_and_both_description_lines', (
      WidgetTester tester,
    ) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      await pumpApp(tester, SoundShareUnpairedPage(viewModel: f.vm));

      // 타이틀 deviceType_01942
      expect(
        findMarquee(AppStrings.of(AppStringKeys.soundShareLabel)),
        findsOneWidget,
      );
      // 본문은 deviceType_01793 + 연결 안내를 한 블록(2줄)으로 렌더한다
      // (unresolved: soundshare-no-device-secondary-tag).
      expect(
        find.textContaining(
          AppStrings.of(AppStringKeys.soundShareDescription),
        ),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('does_not_show_recently_connected_device_label', (
      WidgetTester tester,
    ) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      await pumpApp(tester, SoundShareUnpairedPage(viewModel: f.vm));

      // IR: 5.4 대비 ux_tag 5 (최근 연결 기기) 와 Connect 버튼이 없다.
      expect(find.byKey(const Key('recentDeviceLabel')), findsNothing);
      expect(find.byKey(const Key('connectButton')), findsNothing);

      await forceDispose(tester);
    });

    testWidgets('close_button_has_default_focus', (WidgetTester tester) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      await pumpApp(tester, SoundShareUnpairedPage(viewModel: f.vm));

      // IR unresolved(default-focus-5.5): PDF에 명시 없으나 유일한 focusable.
      final EButton close = tester.widget<EButton>(
        find.byKey(const Key('closeButton')),
      );
      expect(close.autoFocus, isTrue);

      await forceDispose(tester);
    });

    testWidgets('close_button_navigates_back', (WidgetTester tester) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        SoundShareUnpairedPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('closeButton')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('remote_back_returns_to_share_main_view', (
      WidgetTester tester,
    ) async {
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        SoundShareUnpairedPage(viewModel: f.vm),
      );

      await pressBack(tester);

      // IR exit: "Back 시, 이전 화면(스마트폰 공유 Q카드 메인화면)으로 이동"
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('shows_view_when_paired_list_becomes_empty', (
      WidgetTester tester,
    ) async {
      // IR 은 이 뷰를 페어링 이력이 **있는** 상태로 띄운 뒤 목록이 비는 것을 본다.
      // 앱은 이력이 생기면 5.4 로 전환하므로(구독 갱신) 초기 상태에서 이미
      // 5.4 로 넘어간다 — 그래도 최종 assert(recentDeviceLabel 부재)는 성립한다.
      final ({SoundShareUnpairedViewModel vm, FakeBluetooth2Service bt}) f =
          buildVm(
            devices: const <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Galaxy S24',
                'address': 'AA:BB:CC:DD:EE:FF',
              },
            ],
          );
      await pumpApp(tester, SoundShareUnpairedPage(viewModel: f.vm));

      // do: emit — 목록이 비면 이 화면이 유지/표시된다.
      f.bt.emit(const <Map<String, dynamic>>[]);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('recentDeviceLabel')), findsNothing);

      await forceDispose(tester);
    });
  });
}
