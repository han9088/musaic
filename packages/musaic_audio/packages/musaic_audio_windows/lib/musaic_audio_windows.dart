import 'package:flutter/services.dart';
import 'package:musaic_audio_platform_interface/method_channel_musaic_audio.dart';
import 'package:musaic_audio_platform_interface/musaic_audio_platform_interface.dart';

const _channelName = 'com.deskbtm.musaic.audio.methods';

/// The Windows implementation of the Musaic audio platform interface.
final class MusaicAudioWindows extends MethodChannelMusaicAudio {
  static void registerWith() {
    MusaicAudioPlatform.instance = MusaicAudioWindows();
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    await const MethodChannel(_channelName)
        .invokeMethod<void>('init', request.toMap());
    return _WindowsAudioPlayer(request.id);
  }
}

final class _WindowsAudioPlayer extends MethodChannelAudioPlayer {
  _WindowsAudioPlayer(String id)
      : _channel = MethodChannel('$_channelName.$id'),
        super(id);

  final MethodChannel _channel;
  _PlaylistNode? _playlist;
  Future<void> _pendingEdit = Future.value();
  int _loadGeneration = 0;
  int _nextItemId = 0;

  int _allocateId() => _nextItemId++;

  // Windows owns playback progress. The Dart player owns playback intent.
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final playlist =
        _PlaylistNode.decode(request.audioSourceMessage, _allocateId);
    final arguments = {
      ...playlist.toMap(),
      'initialIndex': request.initialIndex,
      'initialPosition': request.initialPosition?.inMicroseconds,
    };
    _loadGeneration++;
    _playlist = playlist;
    final response =
        await _channel.invokeMapMethod<String, dynamic>('load', arguments);
    return LoadResponse.fromMap(response!);
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    await _edit(request.id, request.shuffleOrder, (children) {
      children.insertAll(
        request.index,
        request.children
            .map((source) => _PlaylistNode.decode(source, _allocateId)),
      );
    });
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    await _edit(request.id, request.shuffleOrder, (children) {
      children.removeRange(request.startIndex, request.endIndex);
    });
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async {
    await _edit(request.id, request.shuffleOrder, (children) {
      children.insert(
        request.newIndex,
        children.removeAt(request.currentIndex),
      );
    });
    return ConcatenatingMoveResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async {
    final orders = <String, List<int>>{};

    void collect(AudioSourceMessage source) {
      if (source is ConcatenatingAudioSourceMessage) {
        orders[source.id] = source.shuffleOrder;
        source.children.forEach(collect);
      } else if (source is LoopingAudioSourceMessage) {
        collect(source.child);
      }
    }

    collect(request.audioSourceMessage);
    await _replacePlaylist((playlist) => playlist.edit(orders));
    return SetShuffleOrderResponse();
  }

  Future<void> _edit(
    String id,
    List<int> order,
    void Function(List<_PlaylistNode>) edit,
  ) {
    return _replacePlaylist((playlist) => playlist.edit({id: order}, edit));
  }

  Future<void> _replacePlaylist(_PlaylistNode Function(_PlaylistNode) update) {
    final generation = _loadGeneration;
    final edit = _pendingEdit.then((_) async {
      final previous = _playlist;
      if (previous == null || generation != _loadGeneration) return;
      final playlist = update(previous);
      await _channel.invokeMethod<void>('setPlaylist', playlist.toMap());
      if (identical(_playlist, previous)) _playlist = playlist;
    });
    _pendingEdit = edit.then<void>((_) {}, onError: (Object _) {});
    return edit;
  }
}

/// Each occurrence gets its own native item, even when several entries share
/// one source ID. Edits retain the identity of every surviving occurrence.
final class _PlaylistNode {
  _PlaylistNode.group(this.sourceId, this.children, this.shuffleOrder)
      : item = null;

  _PlaylistNode.item(this.sourceId, this.item)
      : children = const [],
        shuffleOrder = const [];

  final String sourceId;
  final Map<String, Object?>? item;
  final List<_PlaylistNode> children;
  final List<int> shuffleOrder;

  factory _PlaylistNode.decode(
    AudioSourceMessage source,
    int Function() allocateId,
  ) {
    if (source is ConcatenatingAudioSourceMessage) {
      return _PlaylistNode.group(
        source.id,
        source.children
            .map((child) => _PlaylistNode.decode(child, allocateId))
            .toList(),
        source.shuffleOrder,
      );
    }
    if (source is LoopingAudioSourceMessage) {
      return _PlaylistNode.group(
        source.id,
        List.generate(
          source.count,
          (_) => _PlaylistNode.decode(source.child, allocateId),
        ),
        List.generate(source.count, (index) => index),
      );
    }

    final clip = source is ClippingAudioSourceMessage ? source : null;
    final uriSource = clip?.child ?? source;
    final uri = uriSource is UriAudioSourceMessage ? uriSource : null;
    return _PlaylistNode.item(source.id, {
      'id': allocateId(),
      'uri': uri?.uri,
      'adaptive': uri is HlsAudioSourceMessage || uri is DashAudioSourceMessage,
      'start': clip?.start?.inMicroseconds,
      'end': clip?.end?.inMicroseconds,
      'headers': uri?.headers,
    });
  }

  _PlaylistNode edit(
    Map<String, List<int>> orders, [
    void Function(List<_PlaylistNode>)? editChildren,
  ]) {
    if (item != null) return this;
    final updated =
        children.map((child) => child.edit(orders, editChildren)).toList();
    final order = orders[sourceId];
    if (order != null) editChildren?.call(updated);
    return _PlaylistNode.group(sourceId, updated, order ?? shuffleOrder);
  }

  Map<String, Object?> toMap() {
    final items = <Map<String, Object?>>[];
    List<int> flatten(_PlaylistNode node) {
      final item = node.item;
      if (item != null) {
        items.add(item);
        return [items.length - 1];
      }
      final childOrders = node.children.map(flatten).toList();
      return [for (final index in node.shuffleOrder) ...childOrders[index]];
    }

    return {'items': items, 'shuffleOrder': flatten(this)};
  }
}
