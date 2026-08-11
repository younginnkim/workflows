// Audio — Entity for com.webos.service.audio
// decision: soundout-get / soundout-set (decisions.yaml)

/// getSoundOutput / setSoundOutput 의 soundOutput 값.
///
/// 문서(API_Docs/com.webos.service.audio_v1.14.md)에서 확인된 값만 담는다.
class AudioSoundOutput {
  const AudioSoundOutput._();

  /// '기기 스피커' — setSoundOutput 대상값. 문서의 TV 적용 값 목록에서 확인.
  static const String tvSpeaker = 'tv_speaker';

  /// TODO(unresolved: soundout-value-mapping)
  ///   '블루투스 기기' / '블루투스 + 기기 스피커' 에 1:1 대응하는 soundOutput
  ///   값 이름이 문서에 없다. 아래는 후보값이며 Settings_Sound 시나리오로
  ///   확인 후 확정할 것. 임의 추가/추측 금지.
  static const List<String> bluetoothCandidates = <String>[
    'bt_soundbar',
    'lgSoundSync',
    'tv_external_speaker',
  ];
}
