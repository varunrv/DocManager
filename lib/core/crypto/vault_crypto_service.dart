import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM encryption for vault file blobs.
class VaultCryptoService {
  VaultCryptoService() : _algorithm = AesGcm.with256bits();

  static const nonceLength = 12;
  static const macLength = 16;

  final AesGcm _algorithm;

  Future<Uint8List> encrypt(Uint8List plaintext, SecretKey key) async {
    final nonce = _randomNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    final out = Uint8List(nonceLength + box.cipherText.length + macLength);
    out.setRange(0, nonceLength, nonce);
    out.setRange(nonceLength, nonceLength + box.cipherText.length, box.cipherText);
    out.setRange(
      nonceLength + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );
    return out;
  }

  Future<Uint8List> decrypt(Uint8List payload, SecretKey key) async {
    if (payload.length < nonceLength + macLength + 1) {
      throw const FormatException('Encrypted payload is too short.');
    }
    final nonce = payload.sublist(0, nonceLength);
    final macStart = payload.length - macLength;
    final cipherText = payload.sublist(nonceLength, macStart);
    final mac = Mac(payload.sublist(macStart));
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    return Uint8List.fromList(await _algorithm.decrypt(box, secretKey: key));
  }

  List<int> _randomNonce() {
    final random = Random.secure();
    return List<int>.generate(nonceLength, (_) => random.nextInt(256));
  }
}
