import 'package:algolia/algolia.dart';

class AlgoliaService {
  static final Algolia algolia = Algolia.init(
      applicationId: '4Z1B2G5TBF', apiKey: '1c29aa20f350b0d06aa6ea12e1625114');

  getPosts(String query) async {
    AlgoliaQuerySnapshot _querySnap = await algolia.instance
        .index('posts')
        .query(query)
        .setHitsPerPage(40)
        .getObjects();
    return _querySnap.hits;
  }
}
