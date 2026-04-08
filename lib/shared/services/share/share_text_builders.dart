class ShareTextBuilders {
  static String post({
    required String shareUrl,
    String? title,
    String? authorName,
  }) {
    if (title != null && title.isNotEmpty) {
      return '$title\n\nCheck it out on Aurogram: $shareUrl';
    }
    if (authorName != null && authorName.isNotEmpty) {
      return 'Check out this post by $authorName on Aurogram: $shareUrl';
    }
    return 'Check out this post on Aurogram: $shareUrl';
  }

  static String profile({required String shareUrl, String? userName}) {
    if (userName != null && userName.isNotEmpty) {
      return 'Check out $userName\'s profile on Aurogram: $shareUrl';
    }
    return 'Check out this profile on Aurogram: $shareUrl';
  }

  static String cosmicProfile({
    required String shareUrl,
    String? userName,
    String? sunSign,
    String? moonSign,
  }) {
    if (sunSign != null &&
        sunSign.isNotEmpty &&
        moonSign != null &&
        moonSign.isNotEmpty) {
      return '✨ Check your cosmic compatibility with me!\n\n'
          '☉ $sunSign Sun • ☽ $moonSign Moon\n\n'
          'See what the stars say about us: $shareUrl';
    }
    if (userName != null && userName.isNotEmpty) {
      return '✨ Check your cosmic compatibility with $userName on Aurogram!\n\n$shareUrl';
    }
    return '✨ Check your cosmic compatibility with me on Aurogram!\n\n$shareUrl';
  }

  static String space({required String shareUrl, String? spaceName}) {
    if (spaceName != null && spaceName.isNotEmpty) {
      return 'Join $spaceName on Aurogram: $shareUrl';
    }
    return 'Join this gram on Aurogram: $shareUrl';
  }

  static String gramInvite({
    required String spaceName,
    required String shareUrl,
  }) {
    return 'Join $spaceName on Aurogram\n$shareUrl';
  }

  static String insight({
    required String title,
    String? cardType, // Kept for backward compatibility, but ignored
  }) {
    // Unified share text for all insights
    return '✨ "$title"\n\nGet your daily cosmic reading on Aurogram';
  }

  static String cosmicVibeMatch({required int score}) {
    return '✨ Our Cosmic Vibe Match is $score%! Check your compatibility on Aurogram';
  }

  static String ashtakootMatch({
    required String scoreDisplay,
    required int outOf,
  }) {
    return '🕉️ Our Ashtakoot Match is $scoreDisplay/$outOf! Check your compatibility on Aurogram';
  }

  static String lifePhaseSync({required String syncLabel}) {
    return '🌟 Our Life Phase Sync: $syncLabel! Check your compatibility on Aurogram';
  }

  static String cosmicCard({required String shareUrl}) {
    return 'Discover your cosmic blueprint on Aurogram ✨\n$shareUrl';
  }
}
