import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Platform-adaptive map launcher.
/// Opens Apple Maps on iOS, Google Maps on Android / other platforms.
class MapLauncherService {
  MapLauncherService._();

  /// Opens the native map app with the given coordinates or text query.
  ///
  /// Returns `true` if the map app was launched successfully.
  static Future<bool> openMap({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    final Uri url;

    if (Platform.isIOS) {
      url = _buildAppleMapsUrl(
        latitude: latitude,
        longitude: longitude,
        query: query,
      );
    } else {
      url = _buildGoogleMapsUrl(
        latitude: latitude,
        longitude: longitude,
        query: query,
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Apple Maps: https://maps.apple.com/?ll=LAT,LNG&q=LABEL
  static Uri _buildAppleMapsUrl({
    double? latitude,
    double? longitude,
    String? query,
  }) {
    final params = <String, String>{};
    if (latitude != null && longitude != null) {
      params['ll'] = '$latitude,$longitude';
      // Use query as the pin label; fall back to coordinates
      params['q'] = query ?? '$latitude,$longitude';
    } else if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    return Uri.https('maps.apple.com', '/', params);
  }

  /// Google Maps: https://www.google.com/maps/search/?api=1&query=...
  static Uri _buildGoogleMapsUrl({
    double? latitude,
    double? longitude,
    String? query,
  }) {
    final String queryValue;
    if (latitude != null && longitude != null) {
      queryValue = '$latitude,$longitude';
    } else if (query != null && query.isNotEmpty) {
      queryValue = query;
    } else {
      queryValue = '';
    }
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(queryValue)}',
    );
  }
}
