import 'package:cloud_functions/cloud_functions.dart';

class HmsApiService {
  /// 100ms room code creation runs on Cloud Functions so secrets never ship to clients.
  static Future<String> getOrCreateHmsRoom(String roomId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getOrCreateHmsRoom');
      final result = await callable.call(<String, dynamic>{'roomId': roomId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final roomCode = data['roomCode']?.toString();
      if (roomCode == null || roomCode.isEmpty) {
        throw Exception('Cloud Function geçerli bir roomCode döndürmedi.');
      }
      return roomCode;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Sesli oda kodu alınamadı.');
    } catch (e) {
      throw Exception('Sesli oda kodu alınamadı: $e');
    }
  }
}
