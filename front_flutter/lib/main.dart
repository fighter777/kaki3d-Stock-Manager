import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
const _apiToken = String.fromEnvironment(
  'API_TOKEN',
  defaultValue: 'change_me_secure_token',
);

void main() {
  runApp(const StockManagerApp());
}

class StockManagerApp extends StatelessWidget {
  const StockManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaki3D Stock Mobile',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const NfcStockPage(),
    );
  }
}

class NfcStockPage extends StatefulWidget {
  const NfcStockPage({super.key});

  @override
  State<NfcStockPage> createState() => _NfcStockPageState();
}

class _NfcStockPageState extends State<NfcStockPage> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(text: '10');

  bool _nfcAvailable = false;
  bool _isScanning = false;
  bool _isSaving = false;
  String _status = 'Verification NFC...';
  String? _lastUid;
  Spool? _spool;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  @override
  void dispose() {
    _projectController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (!mounted) {
      return;
    }
    setState(() {
      _nfcAvailable = availability == NfcAvailability.enabled;
      _status = _nfcAvailable
          ? 'NFC disponible. Lance un scan.'
          : 'NFC indisponible ou desactive.';
    });
  }

  Future<void> _startScan() async {
    if (!_nfcAvailable || _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
      _status = 'Approche un tag NFC...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Approche ton iPhone du tag',
        onDiscovered: (NfcTag tag) async {
          final uid = _extractUid(tag);
          if (uid == null) {
            if (mounted) {
              setState(() {
                _error = 'UID non lisible pour ce type de tag.';
                _status = 'Lecture NFC echouee.';
                _isScanning = false;
              });
            }
            await NfcManager.instance.stopSession(errorMessageIos: 'Tag non compatible');
            return;
          }

          try {
            final spool = await _apiClient.getSpoolByUid(uid);
            if (!mounted) {
              return;
            }
            setState(() {
              _lastUid = uid;
              _spool = spool;
              _status = 'Tag lu avec succes.';
              _error = null;
              _isScanning = false;
              _weightController.text = '10';
            });
            await NfcManager.instance.stopSession(alertMessageIos: 'Tag lu');
          } catch (e) {
            if (!mounted) {
              return;
            }
            setState(() {
              _lastUid = uid;
              _spool = null;
              _status = 'Tag lu, mais bobine introuvable.';
              _error = e.toString();
              _isScanning = false;
            });
            await NfcManager.instance.stopSession(errorMessageIos: 'Bobine introuvable');
          }
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur session NFC: $e';
        _status = 'Echec du scan.';
        _isScanning = false;
      });
      await NfcManager.instance.stopSession(errorMessageIos: 'Erreur session');
    }
  }

  Future<void> _saveUsage() async {
    if (_spool == null || _isSaving) {
      return;
    }

    final projectName = _projectController.text.trim();
    final weightUsed = double.tryParse(_weightController.text.trim());
    if (projectName.isEmpty || weightUsed == null || weightUsed <= 0) {
      setState(() {
        _error = 'Projet et poids consomme valides requis.';
      });
      return;
    }
    if (weightUsed > _spool!.remainingWeight) {
      setState(() {
        _error = 'Poids consomme superieur au stock restant.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _apiClient.createUsage(
        spoolId: _spool!.id,
        weightUsed: weightUsed,
        projectName: projectName,
        printDate: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Consommation enregistree.';
      });
      _projectController.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur enregistrement consommation: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _extractUid(NfcTag tag) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && androidTag.id.isNotEmpty) {
        return _toUid(androidTag.id);
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final mifare = MiFareIos.from(tag);
      if (mifare != null && mifare.identifier.isNotEmpty) {
        return _toUid(mifare.identifier);
      }

      final iso15693 = Iso15693Ios.from(tag);
      if (iso15693 != null && iso15693.identifier.isNotEmpty) {
        return _toUid(iso15693.identifier);
      }

      final iso7816 = Iso7816Ios.from(tag);
      if (iso7816 != null && iso7816.identifier.isNotEmpty) {
        return _toUid(iso7816.identifier);
      }
    }

    return null;
  }

  String _toUid(List<int> bytes) {
    return bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kaki3D - Scanner NFC')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_lastUid != null) Text('UID: $_lastUid'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _nfcAvailable && !_isScanning ? _startScan : null,
              child: const Text('Scanner une bobine'),
            ),
            const SizedBox(height: 16),
            if (_spool != null) _buildSpoolCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoolCard(BuildContext context) {
    final spool = _spool!;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                '${spool.brand} - ${spool.color}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Matiere: ${spool.material}'),
              Text('Poids restant: ${spool.remainingWeight.toStringAsFixed(1)} g'),
              Text('Poids initial: ${spool.initialWeight.toStringAsFixed(1)} g'),
              const SizedBox(height: 16),
              TextField(
                controller: _projectController,
                decoration: const InputDecoration(labelText: 'Nom du projet'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Poids consomme (g)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSaving ? null : _saveUsage,
                child: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer consommation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Spool {
  const Spool({
    required this.id,
    required this.brand,
    required this.color,
    required this.material,
    required this.initialWeight,
    required this.remainingWeight,
  });

  final int id;
  final String brand;
  final String color;
  final String material;
  final double initialWeight;
  final double remainingWeight;

  factory Spool.fromJson(Map<String, dynamic> json) {
    return Spool(
      id: json['id_spools'] as int,
      brand: (json['nom_marques'] ?? '') as String,
      color: (json['color_name'] ?? '') as String,
      material: (json['type_materials'] ?? '') as String,
      initialWeight: _asDouble(json['initial_weight']),
      remainingWeight: _asDouble(json['poids_restant']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}

class ApiClient {
  final http.Client _client = http.Client();

  Uri _uri(String path) => Uri.parse('$_apiBaseUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiToken',
      };

  Future<Spool> getSpoolByUid(String uid) async {
    final response = await _client.get(_uri('/api/spools/nfc/$uid'), headers: _headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Spool.fromJson(decoded);
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<void> createUsage({
    required int spoolId,
    required double weightUsed,
    required String projectName,
    required DateTime printDate,
  }) async {
    final payload = {
      'weight_used': weightUsed,
      'print_date': printDate.toIso8601String().substring(0, 10),
      'id_spools': spoolId,
      'project_name': projectName,
    };

    final response = await _client.post(
      _uri('/api/usage-logs'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
