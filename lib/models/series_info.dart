class Episode {
  final String id;
  final String name;
  final int episodeNum;
  final int seasonNum;
  final String cmd;

  Episode({
    required this.id,
    required this.name,
    required this.episodeNum,
    required this.seasonNum,
    required this.cmd,
  });
}

class Season {
  final String id;
  final String name;
  final int seasonNumber;
  final String cmd;
  final List<Episode> episodes;

  Season({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.cmd,
    required this.episodes,
  });
}
