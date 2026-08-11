# 요구사항 — 그룹 5: 스마트폰 공유 가이드

| 항목 | 값 |
|---|---|
| Group key | `5` |
| Source | `mobileconnectionguide.pdf` p.2–11 |
| Version | v1.0.0 (2025.08.12) |
| Device variant | 32" StanbyME2 |
| Views | 10 |
| Components | 61 |
| Unresolved | 16 |

---

## 1. 연결된 view 목록

| screen_id | 이름 | 페이지 | 진입 방법 | Mockup |
|---|---|---|---|---|
| 5 | 스마트폰 공유 가이드 (진입 화면) | 2 | 홈에서 "모바일 연결하기" 카드 선택 (deep_link) | [5.png](mockups/5.png) |
| 5.1 | 스마트폰 공유 카드 > 메인 화면 | 3 | 5와 동일 화면 — 카드별 동작 상세 | [5.1.png](mockups/5.1.png) |
| 5.2-1 | Google Cast > 가이드 화면(1) | 4 | 5.1 ux_tag:1 선택 | [5.2-1.png](mockups/5.2-1.png) |
| 5.2-2 | Google Cast > 가이드 화면(2) | 5 | 5.2-1 Next | [5.2-2.png](mockups/5.2-2.png) |
| 5.2-3 | Google Cast > 가이드 화면(3) | 6 | 5.2-2 Next | [5.2-3.png](mockups/5.2-3.png) |
| 5.3-1 | AirPlay > 가이드 화면(1) | 7 | 5.1 ux_tag:2 선택 | [5.3-1.png](mockups/5.3-1.png) |
| 5.3-2 | AirPlay > 가이드 화면(2) | 8 | 5.3-1 Next | [5.3-2.png](mockups/5.3-2.png) |
| 5.3-3 | AirPlay > 가이드 화면(3) | 9 | 5.3-2 Next | [5.3-3.png](mockups/5.3-3.png) |
| 5.4 | 사운드셰어 > 연결기기 있을 때 | 10 | 5.1 ux_tag:3 선택, 연결 이력 **있음** | [5.4.png](mockups/5.4.png) |
| 5.5 | 사운드셰어 > 연결기기 없을 때 | 11 | 5.1 ux_tag:3 선택, 연결 이력 **없음** | [5.5.png](mockups/5.5.png) |

**종료**: 리모컨 [Back] 버튼 또는 종료 아이콘. 각 기능 진입 후 Back 동작은 공통 UX 정책에 따름.

---

## 2. View별 컴포넌트 및 동작

### 5 — 스마트폰 공유 가이드 (진입 화면)

| ux_tag | 컴포넌트 | 동작 |
|---|---|---|
| 1 | 타이틀 : 스마트폰 연결 | render only — **선택 불가 영역** |
| 2 | 설명 문구 | render (`deviceType_01941`) |
| 3 | 기능 버튼 (카드 3개 모음) | render — Google Cast / AirPlay / Sound Share 활용 기능 모음 |
| `exit_icon` | 종료 아이콘 | on_select → navigate_back (※ 목업 번호 태그 없음, [추가 설명]에서 도출) |

### 5.1 — 스마트폰 공유 카드 > 메인 화면

카드 3개 각각의 on_select 동작이 이 view의 핵심입니다.

| ux_tag | 컴포넌트 | 조건 | 동작 |
|---|---|---|---|
| 1 | Stream content from Android device (Google Cast) | 정상 | Google Cast 연결 가이드 화면 실행 → 5.2-1 |
| | | 네트워크 미연결 | 네트워크 설정 필요 팝업 호출 |
| | | 서비스 사용 불가(미지원 국가 등) | 우측 토스트 팝업 (`deviceType_01948`) ⚠️ 판단 소스 미명세 |
| 2 | Stream content from iPhone (AirPlay) | 정상 | AirPlay 연결 가이드 화면 실행 → 5.3-1 |
| | | 네트워크 미연결 | 네트워크 설정 필요 팝업 호출 |
| | | 서비스 사용 불가 | 우측 토스트 팝업 ⚠️ |
| 3 | Cast music from smartphone to %deviceType% speaker (Sound Share) | 연결 이력 있음 | 사운드 셰어 연결 화면 → 5.4 |
| | | 연결 이력 없음 | 사운드 셰어 연결 화면 → 5.5 |
| `popup.network_required` | 네트워크 설정 필요 팝업 | Yes | 네트워크 연결 화면으로 이동 (`launch`) |
| | | No | 팝업 닫힘 |

> **중요**: 네트워크 미연결 팝업은 **카드 1/2에만** 적용됩니다. 스펙 원문이
> "특정 카드(안드로이드폰 콘텐츠 TV에서 보기, 아이폰 화면 TV에서 보기)"로 두 개만
> 명시했으므로 카드 3(Sound Share)은 대상이 아닙니다.
>
> 사운드 셰어 연결 화면에서 Back 시 → 스마트폰 공유 메인 화면으로 이동.

### 5.2-1 / 5.2-2 / 5.2-3 — Google Cast 위저드 (3단계)

동작성은 **Pattern, Component의 Wizardview**에 따름.

| ux_tag | 5.2-1 | 5.2-2 | 5.2-3 |
|---|---|---|---|
| 1 | 단계 인디케이터 (1/3) | 페이지 인디케이터 (✓/2/3) | 페이지 인디케이터 (✓/✓/3) |
| 2 | 타이틀 (`sn_home_0023`) | 동일 | 동일 |
| 3 | 설명 이미지 — 안드로이드폰 설정에서 W-Fi 메뉴로 이동 | 유튜브 앱 상단 구글캐스트 버튼 선택 | 스마트폰 기기 목록에서 기기이름 선택 |
| 4 | 설명 문구 (`sn_home_0026`) | (`sn_home_0028` + `sn_home_0029`) | (`deviceType_01801` + `deviceType_01943`) |
| 4-1 | 보조 문구 (`sn_home_0027`) — **유선 연결 시 미제공** | — | — |
| 5 | Next (**Default Focus**) → 5.2-2 | Next (**Default Focus**) → 5.2-3 | Google Cast 버튼 → 구글 캐스트 앱 |
| 6 | Previous → 이전 화면 | Previous → 이전 화면 | Done (**Default Focus**) → 가이드 종료, 이전 단계로 |
| 7 | — | — | Previous → 이전 화면 |

### 5.3-1 / 5.3-2 / 5.3-3 — AirPlay 위저드 (3단계)

| ux_tag | 5.3-1 | 5.3-2 | 5.3-3 |
|---|---|---|---|
| 1 | 단계 인디케이터 (1/3) | (✓/2/3) | (✓/✓/3) |
| 2 | 타이틀 (`sn_home_0024`) | 동일 | 동일 |
| 3 | 설명 이미지 — 아이폰 설정에서 Wi-Fi 이동 | 아이폰 제어센터 열어 아이콘 선택 | 스마트폰 기기 목록에서 기기이름 선택 |
| 4 | 설명 문구 (`sn_home_0033`) | (`sn_home_0034`) | (`deviceType_01801` + `deviceType_01944`) |
| 4-1 | 보조 문구 — **TV가 유선 연결 시 미제공** ⚠️ 문구태그 누락 | — | — |
| 5 | Next (**Default Focus**) → 5.3-2 | Next (**Default Focus**) → 5.3-3 | Done (**Default Focus**) → 가이드 종료 |
| 6 | Previous → 이전 화면 | Previous → 이전 화면 | Previous → 이전 화면 |

> Google Cast 위저드와 달리 5.3-3에는 "구글캐스트로 이동" 같은 외부 앱 버튼이 없어
> 버튼이 Done/Previous 2개뿐입니다.

### 5.4 — 사운드셰어 > 연결기기 있을 때

| ux_tag | 컴포넌트 | 동작 |
|---|---|---|
| 1 | 타이틀 (`deviceType_01942`) | render |
| 2 | 관련 이미지 (StanbyME 이름 제공) | render |
| 3 | 설명 문구 (`deviceType_01793`) | render |
| 4 | 기기 이름 — 전체 설정 메뉴에서 확인 가능한 StanbyME 이름 `{name}` | ⚠️ 조회 API 미특정 |
| 5 | 연결 이력 있는 기기 이름 — 가장 최근에 연결한 기기명 (`sn_home_0086`) | ⚠️ 최근 정렬 기준 미명세 |
| 6 | [닫기] Close | on_select → 이전 화면으로 이동 |
| 7 | [연결하기] Connect (**Default Focus**) | 아래 3단계 순차 실행 |

**[연결하기] 순차 동작**

1. 사운드 아웃 설정값이 '블루투스 기기' 또는 '블루투스 + 기기 스피커'인 경우 → **'기기 스피커'로 변경**
   (세부 내용은 Settings_Sound 시나리오 참고)
2. 연결 이력이 있으면 **가장 최근에 연결한 기기에 연결 시도**
3. **Sound Share 앱 실행 후, Play 씬으로 이동**

Back 시 → 이전 화면(메인화면)으로 이동. 그 외 상세는 Mobile Connection 시나리오 참조.

### 5.5 — 사운드셰어 > 연결기기 없을 때

**화면 표시 조건 (3가지)**

1. 연결된 기기 이력이 없는 경우
2. Sound Share 연결 상태에서 기기 연결을 끊거나 끊긴 경우 ⚠️ 감지 채널 미명세
3. 최근 연결했던 기기 자동 연결 시도하였으나 실패한 경우 — **토스트 팝업과 함께 화면 표시** ⚠️

| ux_tag | 컴포넌트 | 동작 |
|---|---|---|
| 1 | 타이틀 (`deviceType_01942`) | render |
| 2 | 관련 이미지 — 스마트폰의 블루투스 아이콘을 눌러 목록에서 기기 선택 | render |
| 3 | 설명 문구 (`deviceType_01793` + 보조 문구 ⚠️ 태그 누락) | render |
| 4 | StanbyME 이름 `{name}` | ⚠️ 조회 API 미특정 |
| 5 | [닫기] Close | on_select → 이전 화면으로 이동 |
| `toast.bluetooth_check` | 블루투스 설정 확인 토스트 (`sn_home_0088`) | 자동 연결 실패 시 표시 ⚠️ |

**5.4와의 차이**: `Connect` 버튼과 `Recently Connected Device` 라벨이 **없습니다**.
Close가 유일한 focusable 요소입니다.

Back 시 → 이전 화면(스마트폰 공유 Q카드 메인화면)으로 이동.

---

## 3. 그룹 내 내비게이션

```
        5 / 5.1  (메인)
     ┌─────┼──────────────┬──────────────────┐
     │     │              │                  │
   카드1  카드2         카드3(이력있음)     카드3(이력없음)
     │     │              │                  │
   5.2-1  5.3-1          5.4                5.5
     │Next  │Next          │Connect            │Close
   5.2-2  5.3-2      [사운드아웃 보정         └──▶ 5.1
     │Next  │Next        → a2dp 연결
   5.2-3  5.3-3        → Sound Share Play]
     │Done  │Done
     └──────┴───▶ 5.1
```

**Previous / Back**: 위저드 각 단계에서 한 단계 뒤로. Done은 위저드를 종료하고 5.1로 복귀.

**외부 진입점**: 홈의 "모바일 연결하기" 카드 (deep_link) → 5

**외부로 나가는 점프 3건**

| From | To | 상태 |
|---|---|---|
| 5.1 팝업 Yes | 설정 앱 (network) | appId 확인, target 미확정 |
| 5.2-3 "Google Cast" | 구글 캐스트 앱 | **appId 미확정** |
| 5.4 Connect | Sound Share 앱 Play 씬 | **appId 미확정** |

---

## 4. 주요 Luna 결정

전체 근거(문서 경로·라인·검색 명령)는 [`../../decisions.yaml`](../../decisions.yaml) 참조.

| 원문 | API | subscribe | 확인 |
|---|---|---|---|
| "네트워크 미연결 시… 팝업 호출" / "유선 네트워크로 연결된 상태일 때는 미제공함" | `connectionmanager/getStatus` | ✔ | 사용자 승인 |
| "연결 이력이 있을 경우 가장 최근에 연결한 기기에 연결 시도" | `bluetooth2/a2dp/connect` `{address}` | — | 사용자 승인 |
| "연결된 기기 이력이 없는 경우" / "가장 최근에 연결한 기기명 제공" | `bluetooth2/device/getPairedDevices` | ✔ | auto_resolved |
| "사운드 아웃 설정값이 '블루투스 기기'…인 경우" | `audio/getSoundOutput` | — | 사용자 승인 |
| "'기기 스피커'로 변경함" | `audio/setSoundOutput` `{soundOutput:tv_speaker}` | — | 사용자 승인 |
| "Yes 선택 시, 네트워크 연결 화면으로 이동" | `applicationmanager/launch` `{id:com.webos.app.settings}` | — | 사용자 승인 |
| "선택 시, 구글 캐스트 앱으로 이동" | `applicationmanager/launch` (appId 미정) | — | 사용자 승인 (메소드만) |
| "Sound Share 앱 실행 후, Play 씬으로 이동" | `applicationmanager/launch` (appId 미정) | — | 사용자 승인 (메소드만) |

`connectionmanager/getStatus` 한 API가 **두 요구사항**(팝업 조건 + 보조 문구 숨김 조건)을
동시에 만족하므로 wifi/getstatus를 추가로 쓰지 않았습니다.

---

## 5. 접근성

| view | Audio Guidance | Default Focus |
|---|---|---|
| 5 | 진입: `<Title> + <Description> + "{total} items in total" + <Focused item label> + "button"` / 앱 종료 버튼: `"Exit app" + "button"` | — |
| 5.2-1 | 미기재 | Next |
| 5.2-2 | `{%casting_icon}` → "Cast" (`sn_home_0117`) | Next |
| 5.2-3 | 미기재 | Done |
| 5.3-1 | 미기재 | Next |
| 5.3-2 | `{%airplay_icon}` → "AirPlay" (`sn_home_0118`) | Next |
| 5.3-3 | 미기재 | Done |
| 5.4 | 진입: `<Title> + <Description> + <Default Focus item label> + "button"` | Connect |
| 5.5 | 미기재 | Close (추정 — 명시 없음) |

Voice Foreground 영역은 이 그룹의 어떤 페이지에도 없습니다.

---

## 6. 미해결 항목 (16건)

| ID | view | 내용 |
|---|---|---|
| `view5-vs-view5.1-relation` | 5 | p.2와 p.3 목업이 동일 — 별개 화면인지 2단 명세인지 불명 |
| `service-availability-source` | 5.1 | "미지원 서비스 국가 등" 판단 데이터 소스 없음 (토스트 문구만 존재) |
| `yes-no-i18n-tags` | 5.1 | 팝업에 태그 2개(`sn_home_0020`/`0083`)만 있어 Yes/No 1:1 대응 불명 |
| `google-cast-app-id` | 5.2-3 | 구글 캐스트 appId — 문서 grep **0건** |
| `airplay-step1-secondary-tag` | 5.3-1 | 4-1 보조 문구 문구태그 미표기 (Google Cast판은 `sn_home_0027`) |
| `device-name-source` | 5.4, 5.5 | StanbyME 이름 `{name}` 조회 API 미특정 |
| `soundout-value-mapping` | 5.4 | '블루투스 기기' ↔ `soundOutput` 문자열 값 1:1 매칭 안 됨 |
| `recent-device-ordering` | 5.4 | `getPairedDevices`에 '최근 연결' 정렬/타임스탬프 필드 없음 |
| `soundshare-app-id` | 5.4 | Sound Share appId 및 Play 씬 파라미터 없음 |
| `connect-failure-handling` | 5.4 | `a2dp/connect` 실패 시 동작 미명세 |
| `disconnect-detection-channel` | 5.5 | Sound Share 연결 해제 감지 구독 채널 미명세 |
| `auto-connect-failure-channel` | 5.5 | 자동 연결 실패 감지 채널 미명세 |
| `soundshare-no-device-secondary-tag` | 5.5 | 두 번째 설명 문장 문구태그 미표기 |
| `default-focus-5.5` | 5.5 | Default Focus 명시 없음 — 유일 focusable로 추정 |
| `focus-order-derivation` | 위저드 전체 | focus_order는 목업 배치 추론값 ("Wizardview에 따름"으로 위임) |
| `audio-guidance-inheritance` | 6개 view | Audio Guidance 박스 없는 view의 상속 여부 불명 |

---

## 7. 파싱 자기검증

목업의 번호 태그 수와 IR의 `ux_tag` 항목 수를 비교했습니다 (`components.yaml` → `self_check`).

| view | 목업 번호 태그 | ux_tag 항목 | 결과 |
|---|---|---|---|
| 5 | 3 | 4 | OK — `exit_icon`은 [추가 설명]에서 도출 |
| 5.1 | 3 (①은 목업 표기 누락) | 5 | NOTE — 팝업·토스트는 [추가 설명]에서 도출 |
| 5.2-1 | 7 | 7 | OK |
| 5.2-2 | 6 | 6 | OK |
| 5.2-3 | 7 | 7 | OK |
| 5.3-1 | 7 | 7 | OK |
| 5.3-2 | 6 | 6 | OK |
| 5.3-3 | 6 | 6 | OK |
| 5.4 | 5 (⑥⑦은 스펙 표에만) | 7 | NOTE — 목업 Close/Connect 버튼에 번호 미표기 |
| 5.5 | 5 | 6 | OK — 토스트는 [추가 설명]에서 도출 |

불일치 2건(5.1, 5.4)은 모두 **목업의 번호 표기 누락**이며 스펙 표에는 해당 항목이
기술되어 있습니다. 파싱 누락은 아닙니다.
