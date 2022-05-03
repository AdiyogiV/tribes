import 'package:algolia/algolia.dart';

class AlgoliaService {
  static final Algolia algolia = Algolia.init(applicationId: '6DSXDB9FAZ',
      apiKey: 'ac7df942c99fdfbec8292991b50ae7ca');


  getPosts(String query) async {
    AlgoliaQuerySnapshot _querySnap =
        await algolia.instance.index('posts').query(query).setHitsPerPage(40).getObjects();
    return _querySnap.hits;
  }
}