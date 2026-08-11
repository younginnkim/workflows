// Fake luna 서비스 — IR test-scenarios.yaml 의 `arrange.stubs` (uri → 응답) 를
// 그대로 옮기기 위한 계층.
//
// 실제 서비스들은 `WebOSServiceBridge` 를 static 으로 호출하므로 목킹할 수 없다.
// 대신 서비스 클래스를 상속해 메서드를 오버라이드한다 — ViewModel 이 이미
// 생성자 주입을 지원하므로 프로덕션 코드를 건드리지 않는다.
//
// 각 Fake 는 세 가지를 한다:
//   1) 생성자로 스텁 응답을 받는다        → arrange.stubs
//   2) 호출을 [calls] 에 기록한다          → assert service_called / service_subscribed
//   3) 구독형은 emit() 으로 새 이벤트 푸시 → act do: emit
import 'package:mobile_connection_guide/data/service/applicationmanager_service.dart';
import 'package:mobile_connection_guide/data/service/audio_service.dart';
import 'package:mobile_connection_guide/data/service/bluetooth2_service.dart';
import 'package:mobile_connection_guide/data/service/connectionmanager_service.dart';
import 'package:mobile_connection_guide/domain/entity/audio.dart';
import 'package:mobile_connection_guide/domain/entity/bluetooth2.dart';
import 'package:mobile_connection_guide/domain/entity/connectionmanager.dart';

/// 기록된 luna 호출 1건.
class ServiceCall {
  const ServiceCall(this.uri, [this.params = const <String, dynamic>{}]);

  final String uri;
  final Map<String, dynamic> params;

  @override
  String toString() => '$uri $params';
}

/// decision: network-status — `connectionmanager/getStatus` (subscribe).
class FakeConnectionmanagerService extends ConnectionmanagerService {
  FakeConnectionmanagerService(this.status);

  /// arrange.stubs["luna://com.webos.service.connectionmanager/getStatus"]
  Map<String, dynamic> status;

  final List<ServiceCall> calls = <ServiceCall>[];

  void Function(Connectionmanager status)? _onStatus;

  @override
  void startStatusSubscribe({
    required void Function(Connectionmanager status) onStatus,
  }) {
    calls.add(
      const ServiceCall(
        'luna://com.webos.service.connectionmanager/getStatus',
        <String, dynamic>{'subscribe': true},
      ),
    );
    _onStatus = onStatus;
    onStatus(Connectionmanager.fromMap(status));
  }

  @override
  void stopStatusSubscribe() {
    _onStatus = null;
  }

  /// IR `do: emit` — 구독 채널로 새 상태를 밀어넣는다.
  void emit(Map<String, dynamic> event) {
    status = event;
    _onStatus?.call(Connectionmanager.fromMap(event));
  }
}

/// decision: bt-paired-devices / bt-a2dp-connect.
class FakeBluetooth2Service extends Bluetooth2Service {
  FakeBluetooth2Service({
    this.pairedDevices = const <Map<String, dynamic>>[],
    this.connectResult = true,
  });

  /// arrange.stubs[".../device/getPairedDevices"]["devices"]
  List<Map<String, dynamic>> pairedDevices;

  /// arrange.stubs[".../a2dp/connect"]["returnValue"]
  bool connectResult;

  final List<ServiceCall> calls = <ServiceCall>[];

  void Function(List<Bluetooth2Device> devices)? _onDevices;

  @override
  void startPairedDevicesSubscribe({
    required void Function(List<Bluetooth2Device> devices) onDevices,
  }) {
    calls.add(
      const ServiceCall(
        'luna://com.webos.service.bluetooth2/device/getPairedDevices',
        <String, dynamic>{'subscribe': true},
      ),
    );
    _onDevices = onDevices;
    onDevices(pairedDevices.map(Bluetooth2Device.fromMap).toList());
  }

  @override
  void stopPairedDevicesSubscribe() {
    _onDevices = null;
  }

  @override
  Future<bool> connectA2dp({required String address}) async {
    calls.add(
      ServiceCall('luna://com.webos.service.bluetooth2/a2dp/connect', <
        String,
        dynamic
      >{'address': address}),
    );
    return connectResult;
  }

  /// IR `do: emit` — 페어링 목록 갱신.
  void emit(List<Map<String, dynamic>> devices) {
    pairedDevices = devices;
    _onDevices?.call(devices.map(Bluetooth2Device.fromMap).toList());
  }
}

/// decision: soundout-get / soundout-set.
class FakeAudioService extends AudioService {
  FakeAudioService({this.soundOutput});

  /// arrange.stubs[".../getSoundOutput"]["soundOutput"]
  String? soundOutput;

  final List<ServiceCall> calls = <ServiceCall>[];

  @override
  Future<String?> getSoundOutput() async {
    calls.add(
      const ServiceCall('luna://com.webos.service.audio/getSoundOutput'),
    );
    return soundOutput;
  }

  @override
  Future<bool> isBluetoothSoundOutput() async {
    final String? current = await getSoundOutput();
    return current != null &&
        AudioSoundOutput.bluetoothCandidates.contains(current);
  }

  @override
  Future<bool> setSoundOutputToTvSpeaker() async {
    calls.add(
      const ServiceCall(
        'luna://com.webos.service.audio/setSoundOutput',
        <String, dynamic>{'soundOutput': AudioSoundOutput.tvSpeaker},
      ),
    );
    soundOutput = AudioSoundOutput.tvSpeaker;
    return true;
  }
}

/// decision: launch-network-settings / launch-google-cast / soundshare-stream-out.
class FakeApplicationmanagerService extends ApplicationmanagerService {
  final List<ServiceCall> calls = <ServiceCall>[];

  @override
  Future<bool> launch({
    required String id,
    Map<String, dynamic>? params,
  }) async {
    calls.add(
      ServiceCall('luna://com.webos.service.applicationmanager/launch', <
        String,
        dynamic
      >{'id': id, if (params != null) 'params': params}),
    );
    return true;
  }
}

/// `service_called` / `service_subscribed` assert 헬퍼.
///
/// [params] 를 주면 기록된 호출의 params 가 그것을 **포함**하는지 본다
/// (시나리오는 관심 있는 키만 명시하므로 완전 일치를 요구하지 않는다).
bool hasCall(
  List<ServiceCall> calls,
  String uri, {
  Map<String, dynamic>? params,
}) {
  return calls.any((ServiceCall c) {
    if (c.uri != uri) {
      return false;
    }
    if (params == null) {
      return true;
    }
    return params.entries.every(
      (MapEntry<String, dynamic> e) =>
          _deepEquals(c.params[e.key], e.value),
    );
  });
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return b.entries.every(
      (dynamic e) => _deepEquals(a[e.key], e.value),
    );
  }
  return a == b;
}
