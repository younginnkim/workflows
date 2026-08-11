// 테스트 하네스 — IR test-scenarios.yaml 을 실행 가능한 위젯 테스트로 옮기기 위한 공통 셸.
//
// elemental 패키지의 test/test_helpers/{test_properties_helper,test_page_mixin}.dart
// 패턴을 그대로 따른다. 그 패턴이어야 하는 이유:
//
//   1) EApp 을 쓸 수 없다. e_app.dart 가 LocalizationProvider.of(context)! 를 무조건
//      역참조하므로 LocalizedApp 조상(= EAppMain.run 이 만든다) 없이는 throw 한다.
//      → ETheme + ElementalApp 을 직접 조립한다.
//   2) ElementalApp 이 Navigator/Overlay 를 제공해야 EAlert(useDialog: true) 가 뜬다.
//   3) EHeader 타이틀은 EMarquee(alwaysScroll: true) 라 1초 반복 타이머가 멈추지 않는다.
//      테스트 끝에 반드시 forceDispose() 로 언마운트해야 pumpAndSettle 이 pending timer
//      로 실패하지 않는다.
//
// ETheme 은 settingsservice luna 구독을 걸지만 테스트에서는 PloverPlatform 기본
// 구현이 Stream.empty() 를 주므로 즉시 기본값으로 build 된다 (hang 없음).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;


import 'package:elemental/foundation/app.dart';
import 'package:elemental/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// assets/i18n/en.json 을 flutter_translate 에 직접 적재한다.
///
/// LocalizationDelegate.create() 는 asset bundle 과 device locale 을 타므로
/// 위젯 테스트에서 쓰기 무겁다. Localization.load() 는 순수 정적 함수라 맵만 주면
/// translate() 가 바로 동작한다 (namespace 'default' = AppStrings 가 쓰는 것).
void loadTestTranslations() {
  final File file = File('assets/i18n/en.json');
  final Map<String, dynamic> map =
      json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  Localization.load(map);
}

/// [page] 를 elemental 이 요구하는 최소 트리로 감싸 pump 한다.
///
/// 반환된 [ProviderContainer] 로 테스트가 appRouteProvider 를 직접 읽어
/// `navigated` / `no_navigation` assert 를 판정한다 (앱의 ProviderScope 는
/// app.dart 의 EApp 안에 있어 테스트에서 재사용할 수 없다).
Future<ProviderContainer> pumpApp(WidgetTester tester, Widget page) async {
  loadTestTranslations();

  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);

  // FocusRootScope.onKeyEvent 는 resumed 상태에서만 키를 받는다.
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  // 이 앱은 Figma 3840x2160 원본값을 .h/.sp 로 그대로 쓴다 (예: MainPage 카드
  // 984x792, gap 120 → 3192px). 테스트 뷰포트를 기본 800x600 으로 두면 Row 가
  // 오버플로해 RenderFlex 예외가 난다. 실제 화면 크기를 그대로 준다.
  tester.view.physicalSize = const Size(3840, 2160);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        // 앱 위젯들이 Figma 원본 좌표를 .h 로 쓰므로 designSize 도 같아야 1:1 이 된다.
        designSize: const Size(3840, 2160),
        builder: (_, __) => Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            // EPanel 이 FocusRootScope 를 자체 포함하므로 여기서 감싸지 않는다.
            child: ETheme(child: ElementalApp(home: page)),
          ),
        ),
      ),
    ),
  );
  // EMarquee 가 영구 타이머를 잡으므로 pumpAndSettle 은 쓰지 않는다.
  // 초기 레이아웃·이미지 로드가 끝날 만큼만 고정 시간으로 pump 한다.
  await tester.pump(const Duration(milliseconds: 500));

  return container;
}

/// 테스트별 정리 — EMarquee 등 무한 타이머를 끊는다. 모든 테스트 끝에 호출.
Future<void> forceDispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// TV 리모컨 키 전송.
///
/// 물리 기기에서는 키 입력이 keyboard mode 를 자동 활성화하지만 테스트에서는
/// 일관되지 않아 명시적으로 전환한다 (elemental TestPageMixin 과 동일).
Future<void> sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  if (!FocusNavigationMode.instance.isKeyboardMode) {
    FocusNavigationMode.instance.switchToKeyboardMode();
    // pumpAndSettle 을 쓰면 안 된다: EHeader 타이틀의 EMarquee(alwaysScroll: true)
    // 가 1초 주기 타이머를 영구히 재예약하므로 트리가 절대 settle 되지 않는다.
    // 모드 전환 애니메이션이 끝날 만큼만 고정 시간으로 pump 한다.
    await tester.pump(const Duration(seconds: 2));
  }
  await tester.sendKeyEvent(key);
  await tester.pump(const Duration(milliseconds: 300));
}

/// IR `do: press, key: OK`
Future<void> pressOk(WidgetTester tester) =>
    sendKey(tester, LogicalKeyboardKey.enter);

/// IR `do: press, key: BACK` — elemental 컨테이너들은 escape 를 back 으로 받는다.
///
/// escape 핸들러는 EPanel 을 감싸는 EFocusable 의 onKeyEvent 에 있으므로
/// (`e_panel.dart:1161-1169`) 그 노드가 포커스를 갖고 있어야 키가 도달한다.
/// 앞선 테스트가 포커스를 다른 곳에 두었을 수 있어 매번 명시적으로 탭한다
/// (elemental 자체 위저드 테스트가 쓰는 방식).
Future<void> pressBack(WidgetTester tester) async {
  final Finder panelFocusable = find.ancestor(
    of: find.byType(EPanel),
    matching: find.byType(EFocusable),
  );
  if (panelFocusable.evaluate().isNotEmpty) {
    await tester.tap(panelFocusable.first);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await sendKey(tester, LogicalKeyboardKey.escape);
}

Future<void> pressRight(WidgetTester tester) =>
    sendKey(tester, LogicalKeyboardKey.arrowRight);

Future<void> pressLeft(WidgetTester tester) =>
    sendKey(tester, LogicalKeyboardKey.arrowLeft);

/// EHeader 타이틀 파인더.
///
/// EHeader 는 타이틀을 `EMarquee(alwaysScroll: true)` 로 렌더하고 그 안의 Text 를
/// ExcludeSemantics 로 감싼다 → `find.text` 도 `find.bySemanticsLabel` 도 못 찾는다.
Finder findMarquee(String text) => find.byWidgetPredicate(
  (Widget w) => w is EMarquee && w.text == text,
);

/// `SystemNavigator.pop()` 호출을 가로채 기록한다.
///
/// view 5 의 종료(`navigated_back`)는 앱 라우트 변경이 아니라 앱 자체를 닫는
/// SystemNavigator.pop 이므로, 플랫폼 채널을 목킹해 호출 여부를 본다.
/// 반환된 리스트에 'SystemNavigator.pop' 이 쌓인다.
List<String> recordSystemNavigatorCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// 위저드 단계 전환을 기다린다.
///
/// EWizardPanels → EPanels 전환은 slide 400ms / fade 500ms 이고, 그 위에
/// `onTransition` 250ms 지연 콜백이 얹힌다 (`e_wizard_panels.dart:516-520`).
/// `EWizardPanels(noAnimation:)` 은 선언만 있고 내부 EPanels 로 전달되지 않아
/// (`e_wizard_panels.dart:206-209`) 애니메이션을 끌 수 없다 → 넉넉히 pump 한다.
/// (pumpAndSettle 은 EMarquee 타이머 때문에 못 쓴다)
Future<void> settleWizard(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 2));
}

/// 위저드 Next 를 눌러 다음 단계로 간다.
Future<void> tapWizardNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nextButton')));
  await settleWizard(tester);
}

/// IR `do: focus, target: {by: key, ...}` — 대상에 포커스를 준다.
///
/// keyboard mode 에서 `tester.tap` 은 포커스를 옮기지 않는다 (elemental 은 탭을
/// 활성화로만 처리하고 포커스는 FocusRootScope 에 남는다). elemental 자체 테스트와
/// 같이 cursor mode 로 바꾼 뒤 마우스를 올려 포커스를 만든다.
Future<void> focusByHover(WidgetTester tester, Finder target) async {
  if (FocusNavigationMode.instance.isKeyboardMode) {
    FocusNavigationMode.instance.switchToCursorMode();
    await tester.pump(const Duration(seconds: 1));
  }
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(seconds: 1));
}

/// 현재 포커스가 [key] 위젯의 서브트리 안에 있는지.
///
/// `focus_moved` / `initial_focus` assert 용. elemental 의 EFocusNode 는 앱이
/// 직접 만들지 않으므로 FocusManager 의 primaryFocus 위치를 트리에서 확인한다.
bool isFocusInside(WidgetTester tester, Key key) {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  // 앱은 EFocusable 에 focusNode/id 를 주지 않아 내부 노드가 쓰인다. 노드 동일성
  // 대신 포커스 노드의 context 에서 조상을 거슬러 올라가 대상 Key 에 닿는지 본다.
  final Element target = tester.element(find.byKey(key));
  bool reached = false;
  focusedContext.visitAncestorElements((Element ancestor) {
    if (ancestor == target) {
      reached = true;
      return false;
    }
    return true;
  });
  return reached;
}

/// `Text.rich` 로 쪼개 렌더된 문구의 부분 문자열 검사.
///
/// GuideDialogWidget 은 인라인 아이콘 placeholder 를 WidgetSpan 으로 바꿔
/// TextSpan+WidgetSpan+TextSpan 으로 렌더하므로 단일 Text 위젯이 없다.
/// 따라서 `find.text(전체문구)` 는 실패하고, RichText 의 평문을 봐야 한다.
Finder findRichTextContaining(String fragment) => find.byWidgetPredicate(
  (Widget w) =>
      w is RichText && w.text.toPlainText().contains(fragment),
);
