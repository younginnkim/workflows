// Bluetooth2 — Entity for com.webos.service.bluetooth2
// decision: bt-paired-devices / bt-a2dp-connect (decisions.yaml)

/// device/getPairedDevices 응답의 devices[] 항목.
class Bluetooth2Device {
  const Bluetooth2Device({required this.address, required this.name});

  factory Bluetooth2Device.fromMap(Map<String, dynamic> map) =>
      Bluetooth2Device(
        address: map['address'] as String? ?? '',
        name: map['name'] as String? ?? '',
      );

  /// a2dp/connect 의 address 파라미터로 사용.
  final String address;

  /// 화면에 표시할 기기명 ({%Mobile_name}).
  final String name;
}
