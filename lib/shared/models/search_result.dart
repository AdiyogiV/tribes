/// A web search result surfaced alongside an AI chat message.
class SearchResult {
  final String title;
  final String snippet;
  final String link;
  final String displayLink;
  final String? favicon;
  final bool isReferenced;

  SearchResult({
    required this.title,
    required this.snippet,
    required this.link,
    required this.displayLink,
    this.favicon,
    this.isReferenced = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      snippet: json['snippet'] ?? '',
      link: json['link'] ?? '',
      displayLink: json['displayLink'] ?? '',
      favicon: json['favicon'],
      isReferenced: json['isReferenced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'snippet': snippet,
      'link': link,
      'displayLink': displayLink,
      'favicon': favicon,
      'isReferenced': isReferenced,
    };
  }

  SearchResult copyWith({
    String? title,
    String? snippet,
    String? link,
    String? displayLink,
    String? favicon,
    bool? isReferenced,
  }) {
    return SearchResult(
      title: title ?? this.title,
      snippet: snippet ?? this.snippet,
      link: link ?? this.link,
      displayLink: displayLink ?? this.displayLink,
      favicon: favicon ?? this.favicon,
      isReferenced: isReferenced ?? this.isReferenced,
    );
  }
}
