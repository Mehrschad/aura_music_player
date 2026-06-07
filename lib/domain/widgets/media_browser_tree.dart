import '../library/library_grouping.dart';
import '../models/song.dart';

/// A node in the media-browser hierarchy served to Android Auto / a system
/// `MediaBrowserService`. Either [browsable] (a category the user drills into)
/// or [playable] (a track).
class MediaNode {
  const MediaNode({
    required this.id,
    required this.title,
    this.subtitle,
    this.browsable = false,
    this.playable = false,
    this.artworkSeed,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool browsable;
  final bool playable;
  final String? artworkSeed;
}

/// Stable parent ids.
abstract final class MediaIds {
  static const root = 'root';
  static const library = 'tab:library';
  static const albums = 'tab:albums';
  static const artists = 'tab:artists';
  static const albumPrefix = 'album:';
  static const artistPrefix = 'artist:';
  static const songPrefix = 'song:';
}

MediaNode _songNode(Song s) => MediaNode(
      id: '${MediaIds.songPrefix}${s.id}',
      title: s.title,
      subtitle: s.artist,
      playable: true,
      artworkSeed: s.artworkSeed,
    );

/// The top-level browse categories.
List<MediaNode> mediaRoot() => const [
      MediaNode(id: MediaIds.library, title: 'Library', browsable: true),
      MediaNode(id: MediaIds.albums, title: 'Albums', browsable: true),
      MediaNode(id: MediaIds.artists, title: 'Artists', browsable: true),
    ];

/// Resolves the children of [parentId] against the library [songs]. Pure — this
/// is exactly what an `audio_service` handler's `getChildren` delegates to.
List<MediaNode> mediaChildren(String parentId, List<Song> songs) {
  if (parentId == MediaIds.root) return mediaRoot();

  if (parentId == MediaIds.library) {
    return [for (final s in songs) _songNode(s)];
  }

  if (parentId == MediaIds.albums) {
    return [
      for (final a in groupAlbums(songs))
        MediaNode(
          id: '${MediaIds.albumPrefix}${a.id}',
          title: a.name,
          subtitle: a.artist,
          browsable: true,
          artworkSeed: a.id,
        ),
    ];
  }

  if (parentId == MediaIds.artists) {
    return [
      for (final ar in groupArtists(songs))
        MediaNode(
          id: '${MediaIds.artistPrefix}${ar.id}',
          title: ar.name,
          browsable: true,
        ),
    ];
  }

  if (parentId.startsWith(MediaIds.albumPrefix)) {
    final id = parentId.substring(MediaIds.albumPrefix.length);
    return [for (final s in songs.where((s) => s.albumId == id)) _songNode(s)];
  }

  if (parentId.startsWith(MediaIds.artistPrefix)) {
    final id = parentId.substring(MediaIds.artistPrefix.length);
    return [for (final s in songs.where((s) => s.artistId == id)) _songNode(s)];
  }

  return const [];
}

/// Extracts a song id from a playable node id (`song:<id>` → `<id>`).
String? songIdFromNode(String nodeId) => nodeId.startsWith(MediaIds.songPrefix)
    ? nodeId.substring(MediaIds.songPrefix.length)
    : null;
