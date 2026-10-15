import 'package:flutter/foundation.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class HmsService implements HMSUpdateListener {
  HMSSDK? _hmsSDK;
  bool isJoined = false;
  bool _isLocalMicMuted = false;
  
  Future<void> initializeAndJoin(String roomCode, String userName, String userId) async {
    try {
      if (kIsWeb) {
        throw Exception("Sesli odalar şu an sadece mobil (Android/iOS) uygulamalarımızda desteklenmektedir.");
      }

      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception("Mikrofon izni verilmedi. Kanala katılmak için mikrofon izni gereklidir.");
      }

      _hmsSDK = HMSSDK();
      await _hmsSDK!.build();
      _hmsSDK!.addUpdateListener(listener: this);
      
      // Get auth token from Room Code
      dynamic token = await _hmsSDK!.getAuthTokenByRoomCode(roomCode: roomCode, userId: userId);
      if (token is! String) {
        if (token is HMSException) {
          throw Exception("Token hatası: ${token.message}");
        }
        throw Exception("Room Code üzerinden Token alınamadı. Lütfen Room Code'u kontrol edin.");
      }

      HMSConfig config = HMSConfig(
        authToken: token,
        userName: userName,
      );

      await _hmsSDK!.join(config: config);
      isJoined = true;
      
      // Default to speakerphone for voice rooms
      try {
        _hmsSDK!.switchAudioOutput(audioDevice: HMSAudioDevice.SPEAKER_PHONE);
      } catch (e) {
        debugPrint('Failed to set default audio output to speaker: $e');
      }
    } catch (e) {
      debugPrint('HmsService error: $e');
      rethrow;
    }
  }

  Future<void> switchAudioOutput(bool toSpeaker) async {
    if (_hmsSDK != null) {
      try {
        _hmsSDK!.switchAudioOutput(
          audioDevice: toSpeaker
              ? HMSAudioDevice.SPEAKER_PHONE
              : HMSAudioDevice.EARPIECE,
        );
      } catch (e) {
        debugPrint('HmsService.switchAudioOutput error: $e');
      }
    }
  }

  Future<void> muteMic(bool muted) async {
    if (_hmsSDK != null) {
      if (_isLocalMicMuted != muted) {
        await _hmsSDK!.toggleMicMuteState();
        _isLocalMicMuted = muted;
      }
    }
  }

  // UI callbacks
  void Function()? onUpdate;
  void Function(List<HMSSpeaker> speakers)? onSpeakersUpdate;

  Future<List<HMSPeer>> getPeers() async {
    if (_hmsSDK != null) {
      try {
        final peers = await _hmsSDK!.getPeers();
        return peers ?? [];
      } catch (e) {
        debugPrint('HmsService.getPeers error: $e');
      }
    }
    return [];
  }

  Future<void> leaveChannel() async {
    if (_hmsSDK != null) {
      await _hmsSDK!.leave();
      _hmsSDK!.removeUpdateListener(listener: this);
      _hmsSDK = null;
      isJoined = false;
      onUpdate = null;
      onSpeakersUpdate = null;
    }
  }
  
  // -- HMSUpdateListener Implementation --
  
  @override
  void onJoin({required HMSRoom room}) {
    debugPrint("100ms Odaya Katılındı: ${room.id}");
    onUpdate?.call();
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    debugPrint("Kullanıcı güncellendi: ${peer.name}, Durum: $update");
    onUpdate?.call();
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    debugPrint("Ses/Video güncellendi: ${peer.name}, Durum: $trackUpdate");
    if (peer.isLocal && track.kind == HMSTrackKind.kHMSTrackKindAudio) {
      _isLocalMicMuted = track.isMute;
      debugPrint("Local mic track updated: isMute = $_isLocalMicMuted");
    }
    onUpdate?.call();
  }

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {}

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}

  @override
  void onHMSError({required HMSException error}) {
    debugPrint("100ms Hatası: ${error.message}");
  }

  @override
  void onMessage({required HMSMessage message}) {}

  @override
  void onReconnected() {}

  @override
  void onReconnecting() {}

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    isJoined = false;
    onUpdate?.call();
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    onUpdate?.call();
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {
    onSpeakersUpdate?.call(updateSpeakers);
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    onUpdate?.call();
  }
}
