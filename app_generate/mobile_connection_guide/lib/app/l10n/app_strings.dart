// AppStrings — i18n 키 상수 + 번역 접근자.
//
// 키/폴백은 IR 의 shared/i18n-keys.yaml 에서 그대로 옮겼다.
// `from_pdf` 태그(sn_home_* / deviceType_*)는 PDF 표기 그대로 사용한다.
//
// 번역 파일: assets/i18n/<locale>.json (pubspec.yaml > flutter > assets)
// 런타임 조회는 flutter_translate 의 기본 namespace 를 쓴다 —
// elemental 패키지는 'elemental' namespace 를 따로 쓰므로 충돌하지 않는다.
import 'package:flutter_translate/flutter_translate.dart';

/// i18n 키. 값은 assets/i18n/*.json 의 최상위 키와 1:1 대응한다.
class AppStringKeys {
  const AppStringKeys._();

  // ---- titles / descriptions ----
  /// PDF에 문구태그 미표기 → auto_generated.
  static const String guideTitle = 'smartphone_share.guide.title';
  static const String entryDescription = 'deviceType_01941';

  // ---- feature card labels ----
  static const String googleCastLabel = 'sn_home_0023';
  static const String airPlayLabel = 'sn_home_0024';
  static const String soundShareLabel = 'deviceType_01942';

  // ---- network popup ----
  static const String networkRequiredBody = 'sn_home_0020';

  /// TODO(unresolved: yes-no-i18n-tags)
  ///   PDF에 sn_home_0020 / sn_home_0083 두 태그만 있어 Yes/No 1:1 대응이 불명.
  ///   지금은 sn_home_0083 을 Yes 로, no 는 별도 키로 둔다. 태그 확정 시 교체.
  static const String yes = 'sn_home_0083';
  static const String no = 'common.no';

  static const String serviceUnavailableToast = 'deviceType_01948';

  // ---- Google Cast guide steps ----
  static const String googleCastStep1 = 'sn_home_0026';
  static const String googleCastStep1Secondary = 'sn_home_0027';
  static const String googleCastStep2 = 'sn_home_0028';
  static const String googleCastStep2Secondary = 'sn_home_0029';
  static const String selectDeviceFromList = 'deviceType_01801';
  static const String googleCastStep3Secondary = 'deviceType_01943';
  static const String googleCastButton = 'sn_home_0032';

  // ---- AirPlay guide steps ----
  static const String airPlayStep1 = 'sn_home_0033';

  /// TODO(unresolved: airplay-step1-secondary-tag)
  ///   AirPlay 1단계 보조 문구의 태그가 PDF에 없다. Google Cast 판은
  ///   sn_home_0027 이지만 재사용 여부 불명 → 별도 키로 둔다.
  static const String airPlayStep1Secondary = 'airplay.step1.secondary';
  static const String airPlayStep2 = 'sn_home_0034';
  static const String airPlayStep3Secondary = 'deviceType_01944';

  // ---- Sound Share ----
  static const String soundShareDescription = 'deviceType_01793';

  /// TODO(unresolved: soundshare-no-device-secondary-tag)
  static const String soundShareConnectHint = 'soundshare.connect_hint';

  /// 라벨 문구태그 미표기 (i18n-keys.yaml > missing_tags).
  static const String deviceNameLabel = 'soundshare.device_name';
  static const String recentDeviceLabel = 'sn_home_0086';
  static const String connect = 'sn_home_0037';
  static const String bluetoothCheckToast = 'sn_home_0088';

  // ---- common buttons ----
  static const String next = 'sn_home_0099';
  static const String previous = 'sn_home_0100';
  static const String done = 'sn_home_0084';

  /// [닫기] 버튼 라벨 문구태그 미표기 (i18n-keys.yaml > missing_tags).
  static const String close = 'common.close';

  // ---- accessibility (Audio Guidance) ----
  static const String a11yTotalItems = 'sn_home_0096';
  static const String a11yButton = 'sn_home_0097';
  static const String a11yExitApp = 'sn_home_0098';
  static const String a11yCast = 'sn_home_0117';
  static const String a11yAirPlay = 'sn_home_0118';
}

/// 문구 조회 헬퍼.
///
/// %deviceType% 는 문구태그로 치환되는 기기 종류 문구다 (IR placeholders).
/// 이 앱의 기기 변형은 32" StanbyME2 → 'StanbyME'.
class AppStrings {
  const AppStrings._();

  /// IR placeholders: %deviceType% — "기기 종류 문구 (StanbyME)".
  static const String deviceType = 'StanbyME';

  /// 키를 번역하고 IR 플레이스홀더를 치환한다.
  ///
  /// flutter_translate 의 `{}` 보간과 별개로, PDF 문구의
  /// `%deviceType%` / `{name}` / `{%Mobile_name}` / `{%network name}` 형태는
  /// 여기서 직접 치환한다 (문구태그 원문을 보존하기 위함).
  static String of(
    String key, {
    String? deviceName,
    String? mobileName,
    String? networkName,
  }) {
    String text = translate(key);
    text = text.replaceAll('%deviceType%', deviceType);
    if (deviceName != null) {
      text = text.replaceAll('{name}', deviceName);
    }
    if (mobileName != null) {
      text = text.replaceAll('{%Mobile_name}', mobileName);
    }
    if (networkName != null) {
      text = text.replaceAll('{%network name}', networkName);
    }
    return text;
  }
}
