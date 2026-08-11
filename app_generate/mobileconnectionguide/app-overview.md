# 스마트폰 공유 가이드 — 앱 전체 개요

| 항목 | 값 |
|---|---|
| Source PDF | `mobileconnectionguide.pdf` |
| Version | v1.0.0 (2025.08.12) |
| 변경 내역 | 스마트폰 공유 가이드 내 TV 문구 StanbyME 로 변경 |
| Device variant | 32" StanbyME2 |
| 총 페이지 | 11 (표지 1p + 분석 대상 10p) |
| 연결된 view 그룹 | 1개 (chapter 5) |
| view 수 | 10 |
| Luna 서비스 | 4개 (connectionmanager, bluetooth2, audio, applicationmanager) |
| 미해결 항목 | 16 |

> **범위 주의**: 이 PDF는 상위 UX 시나리오 문서의 **chapter 5 발췌본**입니다. 모든 페이지가
> 단일 top-level 챕터(`5`)에 속하므로 **하나의 연결된 view 그룹**을 이루며, chapter 1~4 및
> 이후 챕터는 이 PDF에 없습니다.

---

## 전체 흐름

```
[홈] "모바일 연결하기" 카드 선택        ← deep_link (그룹 외부 진입)
   │
   ▼
5 / 5.1  스마트폰 공유 메인 (카드 3개)   ← 리모컨 Back / 종료 아이콘으로 앱 종료
   │
   ├─ 카드1 Google Cast ──▶ 5.2-1 ─Next─▶ 5.2-2 ─Next─▶ 5.2-3 ─Done─▶ 5.1
   │                                                      └─"Google Cast"─▶ 구글 캐스트 앱
   │
   ├─ 카드2 AirPlay ──────▶ 5.3-1 ─Next─▶ 5.3-2 ─Next─▶ 5.3-3 ─Done─▶ 5.1
   │
   └─ 카드3 Sound Share ──▶ 연결 이력 있음 ─▶ 5.4 ─Connect─▶ Sound Share 앱 (Play 씬)
                          └ 연결 이력 없음 ─▶ 5.5 ─Close──▶ 5.1

   ※ 카드1/2는 네트워크 미연결 시 → [네트워크 설정 필요 팝업] → Yes ─▶ 설정 앱(network)
   ※ 카드3(Sound Share)은 네트워크 팝업 대상이 아님 (명세상 카드1/2만 해당)
```

**3개 기능 분기의 성격 차이**

| 기능 | 화면 수 | 패턴 | 네트워크 필요 | 상태 분기 |
|---|---|---|---|---|
| Google Cast | 3 (위저드) | WizardView | O | — |
| AirPlay | 3 (위저드) | WizardView | O | — |
| Sound Share | 1 | GuideDialog | X | 연결 이력 유무 → 5.4 / 5.5 |

---

## 그룹 인덱스

| Key | 이름 | 폴더 | Views | 페이지 |
|---|---|---|---|---|
| 5 | 스마트폰 공유 가이드 | [`groups/5-smartphone-share-guide/`](groups/5-smartphone-share-guide/requirements.md) | 5, 5.1, 5.2-1~3, 5.3-1~3, 5.4, 5.5 | 2–11 |

### View 목록

| screen_id | 이름 | 페이지 | 진입 경로 |
|---|---|---|---|
| 5 | 스마트폰 공유 가이드 (진입 화면) | 2 | 홈 카드 선택 (deep_link) |
| 5.1 | 스마트폰 공유 카드 > 메인 화면 | 3 | 5와 동일 화면 (카드별 상세 명세) |
| 5.2-1 | Google Cast > 가이드 화면(1) | 4 | 5.1 카드1 선택 |
| 5.2-2 | Google Cast > 가이드 화면(2) | 5 | 5.2-1 Next |
| 5.2-3 | Google Cast > 가이드 화면(3) | 6 | 5.2-2 Next |
| 5.3-1 | AirPlay > 가이드 화면(1) | 7 | 5.1 카드2 선택 |
| 5.3-2 | AirPlay > 가이드 화면(2) | 8 | 5.3-1 Next |
| 5.3-3 | AirPlay > 가이드 화면(3) | 9 | 5.3-2 Next |
| 5.4 | 사운드셰어 > 연결기기 있을 때 | 10 | 5.1 카드3 선택 (이력 있음) |
| 5.5 | 사운드셰어 > 연결기기 없을 때 | 11 | 5.1 카드3 선택 (이력 없음) |

---

## 전역 공유 컴포넌트

그룹이 1개뿐이므로 아래 컴포넌트는 **그룹 내 여러 view가 공유**하는 구조입니다.
각 그룹 IR에 복제하지 않고 여기서 한 번만 기록합니다.

| 컴포넌트 | visual_role | 사용 view | 비고 |
|---|---|---|---|
| **WizardView** | wizard-page | 5.2-1~3, 5.3-1~3 (6개) | "Pattern, Component의 Wizardview에 따름" — 외부 패턴 문서 위임 |
| **GuideDialog** | fullscreen-dialog | 5, 5.1, 5.4, 5.5 | 타이틀 + 설명 + 콘텐츠 + 버튼 행 |
| Previous 버튼 | button-with-chevron | 위저드 6개 view | `sn_home_0100`, 항상 좌상단 |
| Next 버튼 | button | 5.2-1, 5.2-2, 5.3-1, 5.3-2 | `sn_home_0099`, 항상 Default Focus |
| Done 버튼 | button | 5.2-3, 5.3-3 | `sn_home_0084`, 마지막 단계 Default Focus |
| 네트워크 설정 필요 팝업 | confirm-popup | 5.1 (카드1/2에서만) | `sn_home_0020` |

**위저드 구조 (6개 view 공통)**

```
        ① 단계 인디케이터 (완료 단계는 체크 아이콘)
⑥Previous      ② 타이틀
        ┌──────────────────────┐
        │  ③ 설명 이미지        │
        └──────────────────────┘
          ④ 설명 문구
          ④-1 보조 문구 (유선 연결 시 미제공)
              ⑤ [Next | Done] ← Default Focus
```

**문구 재사용** — 카드 라벨이 해당 기능의 가이드 화면 타이틀로 그대로 재사용됩니다.

| i18n key | 사용처 |
|---|---|
| `sn_home_0023` | Google Cast 카드 라벨 + 가이드 3화면 타이틀 |
| `sn_home_0024` | AirPlay 카드 라벨 + 가이드 3화면 타이틀 |
| `deviceType_01942` | Sound Share 카드 라벨 + 5.4/5.5 타이틀 |
| `deviceType_01801` | 5.2-3 / 5.3-3 3단계 공통 문구 |
| `deviceType_01793` | 5.4 / 5.5 설명 문구 첫 문장 |

---

## 그룹 외부로의 점프 (cross-group)

| From | To | 방식 | 상태 |
|---|---|---|---|
| (홈) | 5 | deep_link | 진입점 |
| 5.1 팝업 Yes | 설정 앱 (network) | `applicationmanager/launch` | appId 확인됨, `params.target` 미확정 |
| 5.2-3 "Google Cast" 버튼 | 구글 캐스트 앱 | `applicationmanager/launch` | **appId 미확정** (문서 grep 0건) |
| 5.4 Connect | Sound Share 앱 Play 씬 | `applicationmanager/launch` | **appId 미확정** |

---

## Luna 서비스 사용 요약

| 서비스 | 메소드 | subscribe | 사용 view | 용도 |
|---|---|---|---|---|
| `com.webos.service.connectionmanager` | `getStatus` | ✔ | 5.1, 5.2-1, 5.3-1 | 인터넷 연결 여부(팝업 조건) + 유선 여부(보조 문구 숨김) |
| `com.webos.service.bluetooth2` | `device/getPairedDevices` | ✔ | 5.1, 5.4, 5.5 | 연결 이력 유무 → 5.4/5.5 분기, 최근 기기명 |
| `com.webos.service.bluetooth2` | `a2dp/connect` | — | 5.4 | 최근 기기 음악 스트리밍 연결 |
| `com.webos.service.audio` | `getSoundOutput` / `setSoundOutput` | — | 5.4 | 연결 전 사운드 아웃 보정 (→ `tv_speaker`) |
| `com.webos.service.applicationmanager` | `launch` | — | 5.1, 5.2-3, 5.4 | 외부 앱/설정 이동 |

> 모든 API는 로컬 `luna-api-docs/API_Docs/` grep으로 확인했고, 근거 문서 경로와 라인은
> [`decisions.yaml`](decisions.yaml)의 `doc_source` 필드에 기록했습니다.

**5.4 [연결하기] 버튼의 호출 순서** (behaviors.yaml의 `sequence` 필드)

```
1. getSoundOutput  → 값이 블루투스류면 setSoundOutput{tv_speaker}
2. a2dp/connect{address: 최근 기기}
3. launch{Sound Share 앱, scene:play}
```

---

## 외부 문서 참조 (이 PDF 범위 밖)

| 참조 문서 | 참조하는 view | 원문 |
|---|---|---|
| Mobile Connection 시나리오 | 5.4, 5.5 | "그 외 동작 관련 상세 내용은 Mobile Connection 시나리오 참조" |
| Settings_Sound 시나리오 | 5.4 | "세부 내용은 Settings_Sound 시나리오 참고" |
| Pattern, Component - Wizardview | 5.2-1, 5.2-3 | "해당 화면 동작성은 Pattern, Component의 Wizardview에 따름" |
| 공통 UX 정책 (Back 동작) | 5 | "각 기능 진입 후 Back 동작은 공통 UX 정책에 따름" |

---

## 접근성 (Audio Guidance)

Voice Foreground(음성 명령) 영역은 **이 PDF의 어느 페이지에도 없습니다** —
`shared/voice-patterns.yaml`은 빈 목록입니다.

Audio Guidance(TTS)는 4개 페이지에만 기재되어 있습니다.

| view | 기재 내용 |
|---|---|
| 5 | 진입 시 발화 템플릿, 버튼 포커스, 앱 종료 버튼 |
| 5.2-2 | `{%casting_icon}` → "Cast" |
| 5.3-2 | `{%airplay_icon}` → "AirPlay" |
| 5.4 | 진입 시 발화 템플릿, 버튼 포커스 |

나머지 6개 view는 미기재 → 상속 여부가 불명확 (`unresolved: audio-guidance-inheritance`).

---

## 미해결 항목 (16건)

| 분류 | 항목 | 영향 |
|---|---|---|
| **appId 미확정** | google-cast-app-id, soundshare-app-id, settings-deeplink-target | 화면 전환 3건 — 메소드는 확정, 대상 ID 미정 |
| **감지 채널 미명세** | service-availability-source, disconnect-detection-channel, auto-connect-failure-channel | 5.1 토스트, 5.5 표시 조건 2건 |
| **데이터 소스 미특정** | device-name-source, recent-device-ordering, soundout-value-mapping | `{name}`, `{%Mobile_name}`, 사운드 아웃 값 매핑 |
| **문구태그 누락** | airplay-step1-secondary-tag, soundshare-no-device-secondary-tag, yes-no-i18n-tags | i18n 바인딩 |
| **명세 자체 부재** | connect-failure-handling, view5-vs-view5.1-relation | 연결 실패 동작, 5/5.1 관계 |
| **추론값** | focus-order-derivation, audio-guidance-inheritance, default-focus-5.5 | 목업 배치에서 추론 (`confirmed_by_user: false`) |

각 항목의 전체 설명은 [`groups/5-smartphone-share-guide/behaviors.yaml`](groups/5-smartphone-share-guide/behaviors.yaml)의
`unresolved` 섹션에 있습니다.
