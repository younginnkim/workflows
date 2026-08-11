# IR 시나리오 → 테스트 결과

입력: `../mobileconnectionguide/groups/5-smartphone-share-guide/test-scenarios.yaml`
실행: `flutter test` (프로젝트 루트에서. `flutter analyze` 는 이 프로젝트에서 크래시함)

## 결과: 69/69 통과

| 파일 | 뷰 | 시나리오 | 통과 |
|---|---|---|---|
| `main_page_test.dart` | 5, 5.1 | 18 | 18 ✅ |
| `google_cast_test.dart` | 5.2-1/2/3 | 20 | 20 ✅ |
| `air_play_test.dart` | 5.3-1/2/3 | 14 | 14 ✅ |
| `sound_share_paired_test.dart` | 5.4 | 10 | 10 ✅ |
| `sound_share_unpaired_test.dart` | 5.5 | 7 | 7 ✅ |

IR 이 `skipped` 로 표시한 8건은 구현하지 않았다 (모두 unresolved 근거 — appId 미확정,
기기명 조회 API 미특정, 실패 감지 채널 미명세). 3-strikes 로 포기한 시나리오: **없음**.

## 고친 프로덕션 버그

1. **`test/widget_test.dart` 스테일 템플릿** — 존재하지 않는 `MyApp` 을 참조해
   `flutter test` 전체가 컴파일 실패하고 있었다. 즉 이 앱의 테스트는 한 번도 돌지
   않았다. 삭제.

2. **위저드가 luna 구독 갱신을 화면에 반영하지 못함** — `EWizardPanels` 는 패널 내용을
   `initState` 에서 한 번 캐시하고 `didUpdateWidget` 에서 **children 개수가 바뀔 때만**
   다시 뽑는다 (`e_wizard_panels.dart:206-209, 260-269`). 단계 수가 항상 3인 이
   위저드에서는 개수가 절대 안 바뀌므로, `connectionmanager/getStatus` 구독으로
   유선→무선이 바뀌어도 1단계 보조 문구가 나타나지 않았다. ViewModel 은 올바르게
   `showWiredHintText=true` 가 되는데 화면만 안 바뀌는 상태였다.
   → `WizardViewWidget(contentRevision:)` 을 추가해 그 값을 `ValueKey` 에 실었다.
   index 는 키에 넣지 않는다 (넣으면 단계 전환 애니메이션이 깨진다).
   시나리오: `secondary_hint_updates_when_network_state_changes` (5.2-1)

3. **5.4 / 5.5 에 BACK 핸들러가 없음** — `EHeader(noBackButton: true,
   noCloseButton: true)` 로 버튼만 숨기고 `onBack` 을 주지 않아, `EPanel` 의 escape
   핸들러가 `header?.onBack != null` 조건에서 no-op 이었다 (`e_panel.dart:1161-1169`).
   리모컨 Back 이 완전히 죽어 있었다. → `onBack: _backToMain` 연결.
   시나리오: `remote_back_returns_to_main_view` (5.4),
   `remote_back_returns_to_share_main_view` (5.5)

4. **view 5 BACK 미처리** — `onClose` 만 있고 `onBack` 이 없었다. IR 은
   "종료 방법 : 리모컨 [Back] 버튼, 종료 아이콘" 으로 둘을 같은 동작으로 명세한다.
   → `onBack: SystemNavigator.pop` 추가.
   시나리오: `remote_back_exits_view_same_as_exit_icon`

5. **진입 안내(on_screen_enter) 미구현** — IR accessibility 가 view 5 와 5.4 에
   합성 발화 문구를 명세하는데 앱에 코드가 없었다. → `EPanel(semanticsLabel:)` 로
   `{title} + {description} + "{total} items in total" + {label} + "button"` 합성.
   시나리오: `announces_entry_guidance_with_total_items` (5),
   `announces_entry_guidance_with_default_focus_label` (5.4)

6. **`step` 이 0-based** — IR 은 1-based `step` 과 `completedSteps` 를 요구한다.
   `stepIndex`(0-based, EWizardPanels 용) / `step`(1-based) / `completedSteps` 로 분리.
   시나리오: `renders_step_two_with_step_one_completed` 등 4건

7. **위젯 Key 전무 / ViewModel 주입 지점 없음** — 시나리오가 요구하는 21개 키를 추가하고,
   5개 Page 에 `viewModel` 옵션 생성자 파라미터를 넣었다 (테스트가 스텁 서비스를
   주입할 수 있도록).

## 하네스에서 밝혀진 elemental 제약

1. **`pumpAndSettle` 금지** — `EHeader` 타이틀의 `EMarquee(alwaysScroll: true)` 가
   1초 주기 타이머를 영구 재예약해 트리가 절대 settle 되지 않는다. 고정 시간
   `tester.pump(Duration(...))` 만 쓴다. (`forceDispose` 는 언마운트 후라 예외)
2. **뷰포트 3840x2160 필수** — 앱이 Figma 원본값(카드 984x792, gap 120 → 3192px)을
   `.h` 로 쓰므로 기본 800x600 에서는 `RenderFlex overflowed` 로 실패한다.
3. **`EApp` 사용 불가** — `LocalizationProvider.of(context)!` 가 throw
   (`e_app.dart:245`). `ETheme + ElementalApp` 을 직접 조립한다.
   `ElementalApp` 은 `package:elemental/foundation/app.dart` (배럴에 없음).
4. **`EMarquee` 로 렌더되는 텍스트** — `EHeader.title`, `ECard.cardCaption` 둘 다
   `find.text` 로 못 찾는다 (`ExcludeSemantics` 로 감싸여 `find.bySemanticsLabel` 도
   안 된다) → `findMarquee()`.
5. **keyboard mode 의 `tester.tap` 은 포커스를 옮기지 않는다** — elemental 은 탭을
   활성화로만 처리하고 포커스는 `FocusRootScope` 에 남는다. `do: focus` 는
   cursor mode + 마우스 hover 로 구현해야 한다 → `focusByHover()`.
6. **`EFocusable` 에 앱이 focusNode/id 를 주지 않는다** → 노드 동일성 비교 불가.
   `primaryFocus.context` 에서 조상을 거슬러 대상 Key 에 닿는지로 판정 →
   `isFocusInside()`. (`primaryFocus.debugLabel` 은 null 이지만 `context` 는 유효)
7. **위저드 단계 전환은 pump 2회 필요** — `EPanels` slide 400ms / fade 500ms +
   `onTransition` 250ms 지연. `EWizardPanels(noAnimation:)` 은 선언만 있고 내부
   `EPanels` 로 전달되지 않아(`e_wizard_panels.dart:206-209`) 애니메이션을 끌 수 없다
   → `settleWizard()` / `tapWizardNext()`.
8. **인라인 아이콘이 있는 문구는 `find.text` 로 못 찾는다** — `GuideDialogWidget` 이
   placeholder 를 `WidgetSpan` 으로 바꿔 `Text.rich` 로 쪼개 렌더한다
   → `findRichTextContaining()`. 해당 문구 4건 (sn_home_0026/0028/0033/0034).
9. **`%deviceType%` 치환** — 기대 문자열도 `AppStrings.of(key)` 를 거쳐야 한다
   (fallback 원문과 직접 비교하면 실패).

## 하네스 구성

```
test/support/
  harness.dart   pumpApp() · forceDispose() · sendKey/pressOk/pressBack/pressRight
                 findMarquee() · findRichTextContaining() · focusByHover()
                 isFocusInside() · settleWizard() · tapWizardNext()
                 recordSystemNavigatorCalls() · loadTestTranslations()
  fakes.dart     Fake{Connectionmanager,Bluetooth2,Audio,Applicationmanager}Service
                 각각 스텁 응답 주입 + calls 기록 + emit() (구독 푸시) · hasCall()
```

`navigated` / `no_navigation` 은 두 층으로 판정한다:
- **화면 층** — 테스트가 소유한 `ProviderContainer` 로 `appRouteProvider` 를 읽는다
  (앱의 `ProviderScope` 는 `EApp` 안에 있어 재사용 불가 → `UncontrolledProviderScope`).
- **위저드 단계 층** — ViewModel 의 `step`. `AppRoute` 에는 5.2-2 같은 값이 없다.
