// Connectionmanager — Entity for com.webos.service.connectionmanager
// decision: network-status (decisions.yaml)

/// getStatus 응답 매핑. return_fields 만 담는다.
class Connectionmanager {
  const Connectionmanager({
    required this.isInternetConnectionAvailable,
    this.wifiState,
    this.wiredState,
    this.wiredInterfaceName,
  });

  factory Connectionmanager.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic>? wifi = map['wifi'] as Map<String, dynamic>?;
    final Map<String, dynamic>? wired = map['wired'] as Map<String, dynamic>?;
    return Connectionmanager(
      isInternetConnectionAvailable:
          map['isInternetConnectionAvailable'] as bool? ?? false,
      wifiState: wifi?['state'] as String?,
      wiredState: wired?['state'] as String?,
      wiredInterfaceName: wired?['interfaceName'] as String?,
    );
  }

  final bool isInternetConnectionAvailable;
  final String? wifiState;
  final String? wiredState;
  final String? wiredInterfaceName;

  /// condition_expr_offline: response.isInternetConnectionAvailable == false
  bool get isOffline => !isInternetConnectionAvailable;

  /// condition_expr_wired: response.wired.state == 'connected'
  bool get isWiredConnected => wiredState == 'connected';
}
