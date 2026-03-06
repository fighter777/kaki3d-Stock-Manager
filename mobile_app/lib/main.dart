import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

void main() {
  runApp(const NfcReaderApp());
}

class NfcReaderApp extends StatelessWidget {
  const NfcReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const NfcReaderPage(),
    );
  }
}

class NfcReaderPage extends StatefulWidget {
  const NfcReaderPage({super.key});

  @override
  State<NfcReaderPage> createState() => _NfcReaderPageState();
}

class _NfcReaderPageState extends State<NfcReaderPage> {
  static const _readingPlaceholder = 'Lecture en cours...';
  DateTime? _lastReadAt;
  DateTime? _lastSeenAt;
  bool _waitingTagRemoval = false;
  Timer? _removalCheckTimer;

  bool _isAvailable = false;
  bool _isScanning = false;
  bool _expertMode = false;
  String _status = 'Verification du NFC...';
  String _tagData = 'Aucun tag lu.';
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _removalCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final availability = await NfcManager.instance.checkAvailability();
    final isAvailable = availability == NfcAvailability.enabled;
    if (!mounted) {
      return;
    }

    setState(() {
      _isAvailable = isAvailable;
      _status = isAvailable
          ? 'NFC disponible. Pret pour un scan.'
          : 'NFC indisponible ou desactive.';
    });
    _log('Disponibilite NFC: $availability');
  }

  Future<void> _startScan() async {
    if (!_isAvailable || _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Approche un tag NFC...';
      _tagData = _readingPlaceholder;
    });
    _lastReadAt = null;
    _lastSeenAt = null;
    _waitingTagRemoval = false;
    _log('Session NFC demarree');

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Approche ton iPhone du tag NFC',
        onDiscovered: (NfcTag tag) async {
          final now = DateTime.now();

          if (_waitingTagRemoval) {
            _lastSeenAt = now;
            return;
          }

          if (_lastReadAt != null &&
              now.difference(_lastReadAt!).inMilliseconds < 1200) {
            return;
          }
          _lastReadAt = now;

          if (!mounted) {
            return;
          }

          setState(() {
            _status = 'Tag detecte, lecture des donnees...';
          });
          _log('Tag detecte');

          try {
            final data = _formatTag(tag);

            if (!mounted) {
              return;
            }

            setState(() {
              _tagData = data;
              if (defaultTargetPlatform == TargetPlatform.android) {
                _status = 'Tag lu. Retire le tag pour terminer.';
                _isScanning = true;
                _waitingTagRemoval = true;
              } else {
                _status = 'Tag detecte.';
                _isScanning = false;
              }
            });
            _log('Lecture du tag reussie');

            if (defaultTargetPlatform == TargetPlatform.iOS) {
              await NfcManager.instance.stopSession(
                alertMessageIos: 'Tag lu avec succes',
              );
              _log('Session NFC arretee (succes)');
            } else {
              _lastSeenAt = now;
              _startRemovalWatcher();
            }
          } catch (e) {
            if (!mounted) {
              return;
            }

            setState(() {
              _tagData = 'Erreur pendant le traitement du tag.';
              _status = 'Tag detecte, mais lecture echouee: $e';
              _isScanning = false;
              _waitingTagRemoval = false;
            });
            _log('Erreur parsing tag: $e');

            await NfcManager.instance.stopSession(
              errorMessageIos: 'Erreur de lecture',
            );
            _log('Session NFC arretee (erreur)');
          }
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Erreur NFC: $e';
        _tagData = 'Aucune donnee disponible.';
        _isScanning = false;
        _waitingTagRemoval = false;
      });
      _log('Erreur session NFC: $e');
      await NfcManager.instance.stopSession(
        errorMessageIos: 'Erreur de lecture',
      );
    }
  }

  Future<void> _stopScan() async {
    if (!_isScanning) {
      return;
    }

    await NfcManager.instance.stopSession();
    if (!mounted) {
      return;
    }

    _removalCheckTimer?.cancel();
    _waitingTagRemoval = false;
    setState(() {
      _isScanning = false;
      _status = 'Scan arrete.';
      if (_tagData == _readingPlaceholder) {
        _tagData = 'Lecture interrompue. Aucun tag lu.';
      }
    });
    _log('Session NFC arretee manuellement');
  }

  void _startRemovalWatcher() {
    _removalCheckTimer?.cancel();
    _removalCheckTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) {
        if (!_waitingTagRemoval || _lastSeenAt == null) {
          return;
        }
        final inactiveFor = DateTime.now().difference(_lastSeenAt!);
        if (inactiveFor > const Duration(milliseconds: 1100)) {
          _finalizeAfterTagRemoval();
        }
      },
    );
    _log('Attente du retrait du tag...');
  }

  Future<void> _finalizeAfterTagRemoval() async {
    _removalCheckTimer?.cancel();
    _waitingTagRemoval = false;

    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Session may already be invalidated.
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isScanning = false;
      _status = 'Tag retire. Session terminee.';
    });
    _log('Retrait du tag detecte, session arretee');
  }

  String _formatTag(NfcTag tag) {
    final lines = <String>[];
    NdefMessage? detectedNdefMessage;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null) {
        lines.add('Plateforme: Android');
        lines.add('UID: ${_toHex(androidTag.id)}');
        lines.add('Technologies: ${androidTag.techList.join(', ')}');

        final ndef = NdefAndroid.from(tag);
        if (ndef != null) {
          lines.add('NDEF: oui');
          lines.add('Verrouille: ${ndef.isWritable ? 'non' : 'oui'}');
          lines.add(
            'Peut etre verrouille en lecture seule: ${ndef.canMakeReadOnly ? 'oui' : 'non'}',
          );
          lines.add('Type NDEF: ${ndef.type}');
          lines.add('Capacite max: ${ndef.maxSize} octets');
          detectedNdefMessage = ndef.cachedNdefMessage;
        } else {
          lines.add('NDEF: non');
        }

        if (_expertMode) {
          _appendAndroidExpert(lines, tag);
        }
      } else {
        lines.add('Tag Android detecte, infos indisponibles.');
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      lines.add('Plateforme: iOS');

      final mifareIos = MiFareIos.from(tag);
      if (mifareIos != null) {
        lines.add('UID: ${_toHex(mifareIos.identifier)}');
      }

      final iso15693Ios = Iso15693Ios.from(tag);
      if (iso15693Ios != null) {
        lines.add('UID: ${_toHex(iso15693Ios.identifier)}');
      }

      final iso7816Ios = Iso7816Ios.from(tag);
      if (iso7816Ios != null) {
        lines.add('UID: ${_toHex(iso7816Ios.identifier)}');
      }

      final ndefIos = NdefIos.from(tag);
      if (ndefIos != null) {
        lines.add('NDEF: oui');
        final isReadOnly = ndefIos.status == NdefStatusIos.readOnly;
        lines.add('Verrouille: ${isReadOnly ? 'oui' : 'non'}');
        lines.add('Statut NDEF iOS: ${ndefIos.status.name}');
        lines.add('Capacite max: ${ndefIos.capacity} octets');
        detectedNdefMessage = ndefIos.cachedNdefMessage;
      } else {
        lines.add('NDEF: non');
      }

      if (_expertMode) {
        _appendIosExpert(lines, tag);
      }
    }

    if (detectedNdefMessage != null) {
      _appendNdef(lines, detectedNdefMessage);
      lines.add('Taille utilisee: ${detectedNdefMessage.byteLength} octets');
      final mainKind = _mainNdefKind(detectedNdefMessage);
      if (mainKind != null) {
        lines.add('Type principal: $mainKind');
      }
      lines.add(
        detectedNdefMessage.records.isEmpty
            ? 'Tag NDEF: vide'
            : 'Tag NDEF: non vide',
      );
    }

    if (lines.isEmpty) {
      lines.add('Tag detecte, mais informations limitees pour ce type de tag.');
    }

    return lines.join('\n');
  }

  void _appendNdef(List<String> lines, NdefMessage? message) {
    if (message == null || message.records.isEmpty) {
      lines.add('Aucun enregistrement NDEF.');
      return;
    }

    for (var i = 0; i < message.records.length; i++) {
      final record = message.records[i];
      final type = _decodeType(record.type);
      final decoded = _tryDecodeRecord(record);
      final payloadHex = _toHex(record.payload);
      lines.add(
        'Record ${i + 1}: tnf=${record.typeNameFormat}, type=$type',
      );
      if (decoded != null) {
        lines.add('  Valeur: $decoded');
      }
      lines.add('  Payload (hex): $payloadHex');
    }
  }

  String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  void _log(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final line = '[$hh:$mm:$ss] $message';
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(0, line);
      if (_logs.length > 30) {
        _logs.removeLast();
      }
    });
  }

  String _decodeType(List<int> typeBytes) {
    if (typeBytes.isEmpty) {
      return '(vide)';
    }
    return ascii.decode(typeBytes, allowInvalid: true);
  }

  String? _tryDecodeRecord(NdefRecord record) {
    if (record.typeNameFormat != TypeNameFormat.wellKnown ||
        record.type.isEmpty ||
        record.payload.isEmpty) {
      return null;
    }

    if (record.type.length == 1 && record.type.first == 0x54) {
      return _decodeTextPayload(record.payload);
    }

    if (record.type.length == 1 && record.type.first == 0x55) {
      return _decodeUriPayload(record.payload);
    }

    return null;
  }

  String _decodeTextPayload(List<int> payload) {
    final status = payload.first;
    final isUtf16 = (status & 0x80) != 0;
    final languageLength = status & 0x3F;

    if (payload.length <= 1 + languageLength) {
      return '(texte invalide)';
    }

    final textBytes = payload.sublist(1 + languageLength);
    if (isUtf16) {
      return '(texte UTF-16 non decode, consulte le payload hex)';
    }

    return utf8.decode(textBytes, allowMalformed: true);
  }

  String _decodeUriPayload(List<int> payload) {
    const prefixes = <String>[
      '',
      'http://www.',
      'https://www.',
      'http://',
      'https://',
      'tel:',
      'mailto:',
      'ftp://anonymous:anonymous@',
      'ftp://ftp.',
      'ftps://',
      'sftp://',
      'smb://',
      'nfs://',
      'ftp://',
      'dav://',
      'news:',
      'telnet://',
      'imap:',
      'rtsp://',
      'urn:',
      'pop:',
      'sip:',
      'sips:',
      'tftp:',
      'btspp://',
      'btl2cap://',
      'btgoep://',
      'tcpobex://',
      'irdaobex://',
      'file://',
      'urn:epc:id:',
      'urn:epc:tag:',
      'urn:epc:pat:',
      'urn:epc:raw:',
      'urn:epc:',
      'urn:nfc:',
    ];

    final prefixIndex = payload.first;
    final suffix = utf8.decode(payload.sublist(1), allowMalformed: true);
    final prefix = prefixIndex < prefixes.length ? prefixes[prefixIndex] : '';
    return '$prefix$suffix';
  }

  String? _mainNdefKind(NdefMessage message) {
    if (message.records.isEmpty) {
      return null;
    }
    return _recordKind(message.records.first);
  }

  String _recordKind(NdefRecord record) {
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        record.type.length == 1 &&
        record.type.first == 0x54) {
      return 'Texte';
    }
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        record.type.length == 1 &&
        record.type.first == 0x55) {
      return 'URL';
    }
    if (record.typeNameFormat == TypeNameFormat.media) {
      return 'MIME';
    }
    if (record.typeNameFormat == TypeNameFormat.external) {
      return 'Externe';
    }
    return record.typeNameFormat.name;
  }

  void _appendAndroidExpert(List<String> lines, NfcTag tag) {
    final nfcA = NfcAAndroid.from(tag);
    if (nfcA != null) {
      lines.add('NfcA: atqa=${_toHex(nfcA.atqa)}, sak=${nfcA.sak}');
    }

    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep != null) {
      lines.add(
        'IsoDep: extendedApdu=${isoDep.isExtendedLengthApduSupported ? 'oui' : 'non'}',
      );
      if (isoDep.historicalBytes != null) {
        lines.add('IsoDep historicalBytes: ${_toHex(isoDep.historicalBytes!)}');
      }
      if (isoDep.hiLayerResponse != null) {
        lines.add('IsoDep hiLayerResponse: ${_toHex(isoDep.hiLayerResponse!)}');
      }
    }

    final nfcB = NfcBAndroid.from(tag);
    if (nfcB != null) {
      lines.add('NfcB applicationData: ${_toHex(nfcB.applicationData)}');
      lines.add('NfcB protocolInfo: ${_toHex(nfcB.protocolInfo)}');
    }

    final nfcF = NfcFAndroid.from(tag);
    if (nfcF != null) {
      lines.add('NfcF manufacturer: ${_toHex(nfcF.manufacturer)}');
      lines.add('NfcF systemCode: ${_toHex(nfcF.systemCode)}');
    }

    final nfcV = NfcVAndroid.from(tag);
    if (nfcV != null) {
      lines.add('NfcV dsfId=${nfcV.dsfId}, responseFlags=${nfcV.responseFlags}');
    }

    final mifareClassic = MifareClassicAndroid.from(tag);
    if (mifareClassic != null) {
      lines.add(
        'MifareClassic: type=${mifareClassic.type.name}, size=${mifareClassic.size}, sectors=${mifareClassic.sectorCount}, blocks=${mifareClassic.blockCount}',
      );
    }

    final mifareUltralight = MifareUltralightAndroid.from(tag);
    if (mifareUltralight != null) {
      lines.add('MifareUltralight: type=${mifareUltralight.type.name}');
    }
  }

  void _appendIosExpert(List<String> lines, NfcTag tag) {
    final mifare = MiFareIos.from(tag);
    if (mifare != null) {
      lines.add('MiFare family: ${mifare.mifareFamily.name}');
      if (mifare.historicalBytes != null) {
        lines.add('MiFare historicalBytes: ${_toHex(mifare.historicalBytes!)}');
      }
    }

    final iso15693 = Iso15693Ios.from(tag);
    if (iso15693 != null) {
      lines.add(
        'Iso15693 manufacturerCode=${iso15693.icManufacturerCode}, serial=${_toHex(iso15693.icSerialNumber)}',
      );
    }

    final iso7816 = Iso7816Ios.from(tag);
    if (iso7816 != null) {
      lines.add('Iso7816 AID: ${iso7816.initialSelectedAID}');
      if (iso7816.applicationData != null) {
        lines.add('Iso7816 applicationData: ${_toHex(iso7816.applicationData!)}');
      }
      if (iso7816.historicalBytes != null) {
        lines.add('Iso7816 historicalBytes: ${_toHex(iso7816.historicalBytes!)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Reader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _status,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Mode expert'),
              value: _expertMode,
              onChanged: (value) {
                setState(() {
                  _expertMode = value;
                });
                _log('Mode expert: ${value ? 'active' : 'desactive'}');
              },
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? const Text('Logs NFC vides.')
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _logs[index],
                          style: const TextStyle(fontFamily: 'monospace'),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _tagData,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isAvailable && !_isScanning ? _startScan : null,
              child: const Text('Lire un tag NFC'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isScanning ? _stopScan : null,
              child: const Text('Arreter le scan'),
            ),
          ],
        ),
      ),
    );
  }
}
