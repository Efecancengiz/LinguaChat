import 'package:flutter/foundation.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class HmsService implements HMSUpdateListener {
  HMSSDK? _hmsSDK;
  bool isJoined = false;
  
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
      String? token = await _hmsSDK!.getAuthTokenByRoomCode(roomCode: roomCode, userId: userId);
      if (token == null) {
        throw Exception("Room Code üzerinden Token alınamadı. Lütfen Room Code'u kontrol edin.");
      }

      HMSConfig config = HMSConfig(
        authToken: token,
        userName: userName,
      );

      await _hmsSDK!.join(config: config);
      isJoined = true;
    } catch (e) {
      debugPrint('HmsService error: $e');
      rethrow;
    }
  }

  Future<void> muteMic(bool muted) async {
    if (_hmsSDK != null) {
      bool isMute = await _hmsSDK!.isAudioMute();
      if (isMute != muted) {
        await _hmsSDK!.toggleMicMuteState();
      }
    }
  }

  Future<void> leaveChannel() async {
    if (_hmsSDK != null) {
      await _hmsSDK!.leave();
      _hmsSDK!.removeUpdateListener(listener: this);
      _hmsSDK = null;
      isJoined = false;
    }
  }
  
  // -- HMSUpdateListener Implementation --
  
  @override
  void onJoin({required HMSRoom room}) {
    debugPrint("100ms Odaya Katılındı: ${room.id}");
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    debugPrint("Kullanıcı güncellendi: ${peer.name}, Durum: $update");
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    debugPrint("Ses/Video güncellendi: ${peer.name}, Durum: $trackUpdate");
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
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}
}
