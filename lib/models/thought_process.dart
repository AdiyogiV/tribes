/// Represents a single step in the AI's thought process
/// Simple data class - no complex filtering needed
class ThoughtStep {
  final String id;
  final String type; // 'search', 'reasoning', 'decision', 'analysis', 'thinking'
  final String message;
  final String? query;
  final List<SearchResult>? results;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final int sequence;
  final bool isComplete;

  ThoughtStep({
    required this.id,
    required this.type,
    required this.message,
    this.query,
    this.results,
    this.metadata,
    required this.timestamp,
    this.sequence = 0,
    this.isComplete = false,
  });

  factory ThoughtStep.fromJson(Map<String, dynamic> json) {
    return ThoughtStep(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      query: json['query'],
      results: json['results'] != null
          ? (json['results'] as List)
              .map((r) => SearchResult.fromJson(r))
              .toList()
          : null,
      metadata: json['metadata'],
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(
              json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      sequence: json['sequence'] ?? 0,
      isComplete: json['isComplete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'query': query,
      'results': results?.map((r) => r.toJson()).toList(),
      'metadata': metadata,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sequence': sequence,
      'isComplete': isComplete,
    };
  }

  ThoughtStep copyWith({
    String? id,
    String? type,
    String? message,
    String? query,
    List<SearchResult>? results,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    int? sequence,
    bool? isComplete,
  }) {
    return ThoughtStep(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      query: query ?? this.query,
      results: results ?? this.results,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      sequence: sequence ?? this.sequence,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Represents the AI's thought process for a response
/// Simplified - stores steps without complex filtering
class ThoughtProcess {
  final String id;
  final List<ThoughtStep> steps;
  final bool isComplete;
  final bool isExpanded;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SearchGrounding? grounding; // New: grounding info from Gemini

  ThoughtProcess({
    required this.id,
    required this.steps,
    this.isComplete = false,
    this.isExpanded = false,
    required this.startedAt,
    this.completedAt,
    this.grounding,
  });

  /// Get steps sorted by sequence
  List<ThoughtStep> get sortedSteps {
    final sorted = List<ThoughtStep>.from(steps);
    sorted.sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }

  /// For backward compatibility
  List<ThoughtStep> get filteredSteps => sortedSteps;

  /// Check if this process used Google Search grounding
  bool get usedSearch =>
      grounding?.wasUsed == true ||
      steps.any((s) => s.type == 'search' || s.type == 'searching');

  /// Get search queries used (from grounding or steps)
  List<String> get searchQueries {
    if (grounding?.queries.isNotEmpty == true) {
      return grounding!.queries;
    }
    return steps
        .where((s) => s.query != null)
        .map((s) => s.query!)
        .toList();
  }

  factory ThoughtProcess.fromJson(Map<String, dynamic> json) {
    final parsedSteps = json['steps'] != null
        ? (json['steps'] as List).map((s) => ThoughtStep.fromJson(s)).toList()
        : <ThoughtStep>[];
    parsedSteps.sort((a, b) => a.sequence.compareTo(b.sequence));

    return ThoughtProcess(
      id: json['id'] ?? '',
      steps: parsedSteps,
      isComplete: json['isComplete'] ?? false,
      isExpanded: json['isExpanded'] ?? false,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
          json['startedAt'] ?? DateTime.now().millisecondsSinceEpoch),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'])
          : null,
      grounding: json['grounding'] != null
          ? SearchGrounding.fromJson(json['grounding'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'steps': steps.map((s) => s.toJson()).toList(),
      'isComplete': isComplete,
      'isExpanded': isExpanded,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'grounding': grounding?.toJson(),
    };
  }

  ThoughtProcess copyWith({
    String? id,
    List<ThoughtStep>? steps,
    bool? isComplete,
    bool? isExpanded,
    DateTime? startedAt,
    DateTime? completedAt,
    SearchGrounding? grounding,
  }) {
    return ThoughtProcess(
      id: id ?? this.id,
      steps: steps ?? this.steps,
      isComplete: isComplete ?? this.isComplete,
      isExpanded: isExpanded ?? this.isExpanded,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      grounding: grounding ?? this.grounding,
    );
  }

  /// Add a step (simple append, no filtering)
  ThoughtProcess addStep(ThoughtStep step) {
    return copyWith(steps: [...steps, step]);
  }

  ThoughtProcess updateStep(String stepId, ThoughtStep updatedStep) {
    final updatedSteps = steps.map((step) {
      return step.id == stepId ? updatedStep : step;
    }).toList();
    return copyWith(steps: updatedSteps);
  }

  ThoughtProcess complete() {
    return copyWith(
      isComplete: true,
      completedAt: DateTime.now(),
    );
  }

  ThoughtProcess toggleExpansion() {
    return copyWith(isExpanded: !isExpanded);
  }

  /// Create from Gemini grounding metadata
  factory ThoughtProcess.fromGrounding({
    required String id,
    required List<String> queries,
    List<SearchSource>? sources,
  }) {
    return ThoughtProcess(
      id: id,
      steps: [],
      isComplete: true,
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
      grounding: SearchGrounding(
        queries: queries,
        sources: sources ?? [],
        wasUsed: queries.isNotEmpty,
      ),
    );
  }
}

/// Represents Google Search grounding information from Gemini
/// Used when Gemini searches the web to answer a question
class SearchGrounding {
  final List<String> queries;
  final List<SearchSource> sources;
  final bool wasUsed;

  SearchGrounding({
    required this.queries,
    required this.sources,
    required this.wasUsed,
  });

  factory SearchGrounding.fromJson(Map<String, dynamic> json) {
    return SearchGrounding(
      queries: (json['queries'] as List?)?.cast<String>() ?? [],
      sources: (json['sources'] as List?)
              ?.map((s) => SearchSource.fromJson(s))
              .toList() ??
          [],
      wasUsed: json['wasUsed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'queries': queries,
      'sources': sources.map((s) => s.toJson()).toList(),
      'wasUsed': wasUsed,
    };
  }

  /// Summary text for display (e.g., "Searched: topic1, topic2")
  String get summary {
    if (queries.isEmpty) return '';
    final displayQueries = queries.take(3).join(', ');
    final more = queries.length > 3 ? ' +${queries.length - 3} more' : '';
    return 'Searched: $displayQueries$more';
  }
}

/// A source from Google Search grounding
class SearchSource {
  final String title;
  final String url;

  SearchSource({required this.title, required this.url});

  factory SearchSource.fromJson(Map<String, dynamic> json) {
    return SearchSource(
      title: json['title'] ?? '',
      url: json['url'] ?? json['uri'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }
}

/// Search result from backend (legacy) or thought steps
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
