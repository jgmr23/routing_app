import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class InstallationPoints {
  String? latitude;
  String? longitude;
  String? localNumber;

  InstallationPoints({
    required this.latitude,
    required this.longitude,
    required this.localNumber,
  });

  InstallationPoints.fromJson(Map<String, dynamic> json) {
    latitude = json['latitude'];
    longitude = json['longitude'];
    localNumber = json['localNumber'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['localNumber'] = localNumber;
    return data;
  }

  @override
  String toString() {
    return '{"latitude": "$latitude", "longitude": "$longitude", "localNumber": "$localNumber"}';
  }
}
