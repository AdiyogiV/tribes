import 'package:aurogram/core/config/api_endpoints.dart';

class ShareLinks {
  static const String baseUrl = ApiEndpoints.appBaseUrl;

  static String profile(String userId) => '${ShareLinks.baseUrl}/u/$userId';

  static String cosmicProfile(String userId) =>
      '${ShareLinks.baseUrl}/cosmic/$userId';

  static String post(String postId) => '${ShareLinks.baseUrl}/p/$postId';

  static String space(String spaceId,
      {String? gramName, String? inviterName, String? inviterId}) {
    final uri = Uri.parse('${ShareLinks.baseUrl}/s/$spaceId');
    final params = <String, String>{};
    if (gramName != null && gramName.isNotEmpty) {
      params['name'] = gramName;
    }
    if (inviterName != null && inviterName.isNotEmpty) {
      params['by'] = inviterName;
    }
    if (inviterId != null && inviterId.isNotEmpty) {
      params['inv'] = inviterId;
    }
    if (params.isNotEmpty) {
      return uri.replace(queryParameters: params).toString();
    }
    return uri.toString();
  }
}
