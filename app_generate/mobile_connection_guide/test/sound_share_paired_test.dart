// IR test-scenarios.yaml — view 5.4 (사운드셰어 · 연결기기 있을 때)
//
// [연결하기] 는 IR 이 정한 3단계 순서를 지켜야 한다:
//   1) 사운드 아웃이 블루투스 계열이면 'tv_speaker' 로 보정 (soundout-get/set)
//   2) 가장 최근 기기에 a2dp/connect
//   3) Sound Share 앱 Play 씬으로 이동 (skipped — appId 미확정)
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_connection_guide/app/l10n/app_strings.dart';
import 'package:mobile_connection_guide/app/navigation/app_route.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/sound_share_paired_page.dart';
import 'package:mobile_connection_guide/presentation/page/smartphone_share_guide/sound_share_paired_view_model.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

/// IR 시나리오의 공통 스텁: 페어링 이력 1건 (Galaxy S24).
const List<Map<String, dynamic>> kGalaxyS24 = <Map<String, dynamic>>[
  <String, dynamic>{'name': 'Galaxy S24', 'address': 'AA:BB:CC:DD:EE:FF'},
];

({
  SoundSharePairedViewModel vm,
  FakeBluetooth2Service bt,
  FakeAudioService audio,
  FakeApplicationmanagerService app,
})
buildVm({
  List<Map<String, dynamic>> devices = kGalaxyS24,
  String? soundOutput,
  bool connectResult = true,
}) {
  final FakeBluetooth2Service bt = FakeBluetooth2Service(
    pairedDevices: devices,
    connectResult: connectResult,
  );
  final FakeAudioService audio = FakeAudioService(soundOutput: soundOutput);
  final FakeApplicationmanagerService app = FakeApplicationmanagerService();
  return (
    vm: SoundSharePairedViewModel(
      bluetooth2: bt,
      audio: audio,
      applicationmanager: app,
    ),
    bt: bt,
    audio: audio,
    app: app,
  );
}

void main() {
  group('view 5.4 — sound_share_connected', () {
    testWidgets('renders_title_and_description_from_i18n', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      // 타이틀 deviceType_01942 — EHeader 는 EMarquee.
      expect(
        findMarquee(AppStrings.of(AppStringKeys.soundShareLabel)),
        findsOneWidget,
      );
      // 본문 deviceType_01793
      expect(
        find.text(AppStrings.of(AppStringKeys.soundShareDescription)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('guideImage')), findsOneWidget);

      await forceDispose(tester);
    });

    testWidgets('shows_recently_connected_device_name', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      expect(
        hasCall(
          f.bt.calls,
          'luna://com.webos.service.bluetooth2/device/getPairedDevices',
        ),
        isTrue,
      );
      expect(find.byKey(const Key('recentDeviceLabel')), findsOneWidget);
      // sn_home_0086 의 {%Mobile_name} 이 스텁 기기명으로 치환된다.
      expect(
        find.text(
          AppStrings.of(
            AppStringKeys.recentDeviceLabel,
            mobileName: 'Galaxy S24',
          ),
        ),
        findsOneWidget,
      );

      await forceDispose(tester);
    });

    testWidgets('connect_button_has_default_focus', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      final EButton connect = tester.widget<EButton>(
        find.byKey(const Key('connectButton')),
      );
      expect(connect.autoFocus, isTrue);
      expect(connect.text, AppStrings.of(AppStringKeys.connect));

      await forceDispose(tester);
    });

    testWidgets('announces_entry_guidance_with_default_focus_label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final ({
          SoundSharePairedViewModel vm,
          FakeBluetooth2Service bt,
          FakeAudioService audio,
          FakeApplicationmanagerService app,
        })
        f = buildVm();
        await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

        // IR accessibility#views[8].on_screen_enter
        final String label = tester
            .getSemantics(find.byKey(const Key('soundShareConnectedRoot')))
            .label;
        expect(label, contains('Cast music from smartphone'));
        expect(label, contains('Connect'));
        expect(label, contains('button'));

        await forceDispose(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('connect_switches_soundout_to_device_speaker_when_bluetooth_selected', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm(soundOutput: 'bt_soundbar');
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      await tester.tap(find.byKey(const Key('connectButton')));
      await tester.pump(const Duration(seconds: 1));

      // 순서 1 — 블루투스 계열이면 기기 스피커로 보정한다.
      expect(
        hasCall(
          f.audio.calls,
          'luna://com.webos.service.audio/getSoundOutput',
        ),
        isTrue,
      );
      expect(
        hasCall(
          f.audio.calls,
          'luna://com.webos.service.audio/setSoundOutput',
          params: const <String, dynamic>{'soundOutput': 'tv_speaker'},
        ),
        isTrue,
      );

      await forceDispose(tester);
    });

    testWidgets('connect_keeps_soundout_when_already_device_speaker', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm(soundOutput: 'tv_speaker');
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      await tester.tap(find.byKey(const Key('connectButton')));
      await tester.pump(const Duration(seconds: 1));

      expect(
        hasCall(
          f.audio.calls,
          'luna://com.webos.service.audio/getSoundOutput',
        ),
        isTrue,
      );
      // 이미 기기 스피커면 setSoundOutput 없이 바로 연결로 넘어간다.
      expect(
        hasCall(
          f.audio.calls,
          'luna://com.webos.service.audio/setSoundOutput',
        ),
        isFalse,
      );
      expect(
        hasCall(
          f.bt.calls,
          'luna://com.webos.service.bluetooth2/a2dp/connect',
          params: const <String, dynamic>{'address': 'AA:BB:CC:DD:EE:FF'},
        ),
        isTrue,
      );

      await forceDispose(tester);
    });

    testWidgets('connect_calls_a2dp_connect_with_recent_device_address', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm(soundOutput: 'tv_speaker');
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      await tester.tap(find.byKey(const Key('connectButton')));
      await tester.pump(const Duration(seconds: 1));

      // 순서 2 — decision: bt-a2dp-connect
      expect(
        hasCall(
          f.bt.calls,
          'luna://com.webos.service.bluetooth2/a2dp/connect',
          params: const <String, dynamic>{'address': 'AA:BB:CC:DD:EE:FF'},
        ),
        isTrue,
      );

      await forceDispose(tester);
    });

    testWidgets('close_button_navigates_back', (WidgetTester tester) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        SoundSharePairedPage(viewModel: f.vm),
      );

      await tester.tap(find.byKey(const Key('closeButton')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('remote_back_returns_to_main_view', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      final ProviderContainer container = await pumpApp(
        tester,
        SoundSharePairedPage(viewModel: f.vm),
      );

      await pressBack(tester);

      // IR exit: "Back 시, 이전 화면(메인화면)으로 이동" → view.5.1
      expect(container.read(appRouteProvider), AppRoute.main);

      await forceDispose(tester);
    });

    testWidgets('focus_order_is_close_then_connect', (
      WidgetTester tester,
    ) async {
      final ({
        SoundSharePairedViewModel vm,
        FakeBluetooth2Service bt,
        FakeAudioService audio,
        FakeApplicationmanagerService app,
      })
      f = buildVm();
      await pumpApp(tester, SoundSharePairedPage(viewModel: f.vm));

      // accessibility#views[8].focus_order — Close(1) → Connect(2), 좌→우.
      final double close = tester
          .getTopLeft(find.byKey(const Key('closeButton')))
          .dx;
      final double connect = tester
          .getTopLeft(find.byKey(const Key('connectButton')))
          .dx;
      expect(close, lessThan(connect));

      await forceDispose(tester);
    });
  });
}
