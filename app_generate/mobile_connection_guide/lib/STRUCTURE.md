# MVVM 구조 — mobile_connection_guide

> mvvm-structure 생성. **폴더 분리 + 빈 파일만** (스켈레톤·본문 제외).

- 페이지(View+ViewModel) 10 · 팝업 1 · 알럿 0 · 공통위젯 5 · 서비스 4
- 그룹별 페이지 수: smartphone_share_guide(10)

## 트리
```
app/navigation/.gitkeep
app/popup/.gitkeep
data/mock/.gitkeep
data/provider/.gitkeep
data/repository_impl/.gitkeep
data/service/applicationmanager_service.dart
data/service/audio_service.dart
data/service/bluetooth2_service.dart
data/service/connectionmanager_service.dart
domain/entity/.gitkeep
domain/entity/applicationmanager.dart
domain/entity/audio.dart
domain/entity/bluetooth2.dart
domain/entity/connectionmanager.dart
domain/repository/.gitkeep
domain/usecase/.gitkeep
presentation/alert/.gitkeep
presentation/page/smartphone_share_guide/air_play_1_page.dart
presentation/page/smartphone_share_guide/air_play_1_view_model.dart
presentation/page/smartphone_share_guide/air_play_2_page.dart
presentation/page/smartphone_share_guide/air_play_2_view_model.dart
presentation/page/smartphone_share_guide/air_play_3_page.dart
presentation/page/smartphone_share_guide/air_play_3_view_model.dart
presentation/page/smartphone_share_guide/entry_page.dart
presentation/page/smartphone_share_guide/entry_view_model.dart
presentation/page/smartphone_share_guide/google_cast_1_page.dart
presentation/page/smartphone_share_guide/google_cast_1_view_model.dart
presentation/page/smartphone_share_guide/google_cast_2_page.dart
presentation/page/smartphone_share_guide/google_cast_2_view_model.dart
presentation/page/smartphone_share_guide/google_cast_3_page.dart
presentation/page/smartphone_share_guide/google_cast_3_view_model.dart
presentation/page/smartphone_share_guide/main_page.dart
presentation/page/smartphone_share_guide/main_view_model.dart
presentation/page/smartphone_share_guide/sound_share_paired_page.dart
presentation/page/smartphone_share_guide/sound_share_paired_view_model.dart
presentation/page/smartphone_share_guide/sound_share_unpaired_page.dart
presentation/page/smartphone_share_guide/sound_share_unpaired_view_model.dart
presentation/popup/network_required_popup.dart
presentation/widget/done_widget.dart
presentation/widget/guide_dialog_widget.dart
presentation/widget/next_widget.dart
presentation/widget/previous_widget.dart
presentation/widget/wizard_view_widget.dart
```

## Step 3 수동 보정 내역
structure.mjs 자동 생성 결과에서 아래 3건을 IR 기준으로 고쳤다.

1. **페이지 파일명 충돌** — 한글 화면명이 슬러그화에 실패해 view `5`·`5.1`·`5.4`·`5.5` 가
   모두 `x_page.dart` / `x_view_model.dart` 한 쌍으로 뭉쳤다. 화면 의미대로 분리:
   `entry` / `main` / `sound_share_paired` / `sound_share_unpaired`.
2. **팝업이 위젯으로 분류** — `네트워크 설정 필요 팝업`(components.yaml
   `ux_tag: popup.network_required`, `visual_role: confirm-popup`, modal overlay)이
   `presentation/widget/x_widget.dart` 로 생성돼 있었다 →
   `presentation/popup/network_required_popup.dart` 로 이동하고 structure.json `popups` 에 등록.
3. **서비스 목록 오류(양방향)** — decisions.yaml 에서 `chosen:` 과
   `alternative_considered:` 를 구분하지 않아, IR 이 `why_not` 으로 **기각한**
   `com.webos.service.soundshare` 가 생성되고(삭제함), 두 결정에서 실제 채택된
   `com.webos.service.bluetooth2`(`a2dp/connect`, `device/getPairedDevices`)가 빠져 있었다(추가함).

## 구현 완료 (widget-from-figma + decisions.yaml)

`data/service` · `domain/entity` 는 decisions.yaml 의 `generated_code` 를,
`presentation` 은 Figma 11개 노드를 근거로 채웠다.

### 위저드 3단계 → 파일 1개로 합침
IR 의 `pattern.component: WizardView` 에 따라 Google Cast(5.2-*)와
AirPlay(5.3-*)를 각각 **EWizardPanels 1개 + 3 패널**로 구현했다.
ESteps(1/2/3, 완료는 체크 아이콘)·Previous·패널 전환이 위젯 내장이라
화면마다 반복 구현하지 않는다. 스켈레톤의 `*_2_*` / `*_3_*` 파일은
구현 위치를 가리키는 주석만 남겼다.

| IR view | 구현 파일 |
| --- | --- |
| 5 / 5.1 | `entry_page.dart` → `main_page.dart` (목업 동일, unresolved 참고) |
| 5.2-1~3 | `google_cast_1_page.dart` (`GoogleCastGuidePage`) |
| 5.3-1~3 | `air_play_1_page.dart` (`AirPlayGuidePage`) |
| 5.4 | `sound_share_paired_page.dart` |
| 5.5 | `sound_share_unpaired_page.dart` |

### 추가한 파일 (스켈레톤에 없던 것)
- `app/l10n/app_strings.dart` — i18n 키 상수 + `%deviceType%` 치환
- `app/navigation/app_route.dart` — 화면 그래프(Riverpod)
- `presentation/widget/inline_guide_icon_widget.dart` — 문구 중간 아이콘
- `assets/i18n/{en,ko}.json` · `assets/images/*.png` (Figma export 11장)

### Figma 노드 이름 vs 링크 라벨 불일치
사운드셰어 2개 화면에서 사용자가 준 링크 라벨과 Figma 노드 이름이
뒤바뀌어 있었다. **Figma 노드 이름을 따랐다**(사용자 확인):
`291:123810` = 연결기기 있을 때(닫기+연결하기) → 5.4,
`291:123811` = 없을 때(닫기) → 5.5. 화면 내용도 IR 과 일치한다.

## 남은 작업
- `flutter analyze` 미실행 — 환경 문제로 analysis server 가 죽는다
  (`fs.inotify.max_user_instances=128` 고갈, 155개 사용 중).
  `sudo sysctl -w fs.inotify.max_user_instances=512` 후 재실행 필요.
- 코드 내 `TODO(unresolved: *)` 6건 — appId 2개, 기기이름 조회 API,
  soundOutput 값 매핑, 최근기기 정렬, 서비스 가용성 판단 소스.
