// Applicationmanager — Entity for com.webos.service.applicationmanager
// decision: launch-network-settings / launch-google-cast / soundshare-stream-out

/// launch 대상 appId 상수.
///
/// 확인되지 않은 appId 는 절대 추측하지 않는다 (decisions.yaml unresolved).
class ApplicationmanagerAppId {
  const ApplicationmanagerAppId._();

  /// API_Docs 예제(com.webos.notification_v2.2.md:735)에서 확인된 값.
  static const String settings = 'com.webos.app.settings';

  /// TODO(unresolved: google-cast-app-id)
  ///   luna-api-docs 전체 grep 0건 — appId 를 절대 추측하지 않는다.
  ///   실제 appId 확인 후 채울 것. 그 전에는 호출 시 StateError.
  static const String? googleCast = null;

  /// TODO(unresolved: soundshare-app-id)
  ///   Sound Share appId 가 PDF/문서에 없다 — 추측 금지.
  ///   확인된 appId 로 채우기 전까지는 호출 시 StateError.
  static const String? soundShare = null;
}
