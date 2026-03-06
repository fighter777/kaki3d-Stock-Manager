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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(text: '10');
  final TextEditingController _spoolIdController = TextEditingController();
  final TextEditingController _spoolNfcController = TextEditingController();
  final TextEditingController _spoolBrandController = TextEditingController();
  final TextEditingController _spoolMaterialController = TextEditingController();
  final TextEditingController _spoolColorController = TextEditingController();
  final TextEditingController _spoolInitialController = TextEditingController(text: '1000');
  final TextEditingController _spoolEmptyController = TextEditingController(text: '200');

  bool _nfcAvailable = false;
  bool _isAuthLoading = false;
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isInventoryLoading = false;
  bool _isSpoolCrudLoading = false;
  bool _isStatsLoading = false;
  String _status = 'Verification NFC...';
  String? _authToken;
  String? _lastUid;
  Spool? _spool;
  List<Spool> _inventory = const [];
  List<Map<String, dynamic>> _statsMaterials = const [];
  List<Map<String, dynamic>> _statsProjects = const [];
  List<Map<String, dynamic>> _statsMonthly = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _projectController.dispose();
    _weightController.dispose();
    _spoolIdController.dispose();
    _spoolNfcController.dispose();
    _spoolBrandController.dispose();
    _spoolMaterialController.dispose();
    _spoolColorController.dispose();
    _spoolInitialController.dispose();
    _spoolEmptyController.dispose();
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

  Future<void> _register() => _auth(mode: 'register');
  Future<void> _login() => _auth(mode: 'login');

  Future<void> _auth({required String mode}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      setState(() {
        _error = 'Email requis et mot de passe >= 8 caracteres.';
      });
      return;
    }

    setState(() {
      _isAuthLoading = true;
      _error = null;
    });

    try {
      final token = mode == 'register'
          ? await _apiClient.register(email: email, password: password)
          : await _apiClient.login(email: email, password: password);
      if (!mounted) {
        return;
      }
      setState(() {
        _authToken = token;
        _status = mode == 'register' ? 'Compte cree.' : 'Connecte.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur auth: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
        });
      }
    }
  }

  Future<void> _changePasswordDialog() async {
    if (_authToken == null || _isAuthLoading) {
      return;
    }

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Modifier le mot de passe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(localError!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final currentPassword = currentCtrl.text;
                    final newPassword = newCtrl.text;
                    if (newPassword.length < 8) {
                      setLocalState(() {
                        localError = 'Nouveau mot de passe >= 8 caracteres';
                      });
                      return;
                    }

                    try {
                      final newToken = await _apiClient.changePassword(
                        token: _authToken!,
                        currentPassword: currentPassword,
                        newPassword: newPassword,
                      );
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _authToken = newToken;
                        _status = 'Mot de passe modifie.';
                        _error = null;
                      });
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop();
                    } catch (e) {
                      setLocalState(() {
                        localError = 'Erreur: $e';
                      });
                    }
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _logout() async {
    if (_authToken == null || _isAuthLoading) {
      return;
    }

    setState(() {
      _isAuthLoading = true;
      _error = null;
    });

    try {
      await _apiClient.logout(_authToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _authToken = null;
        _spool = null;
        _lastUid = null;
        _status = 'Deconnecte.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur logout: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (!_nfcAvailable || _isScanning || _authToken == null) {
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
            final spool = await _apiClient.getSpoolByUid(uid, _authToken!);
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
    if (_spool == null || _isSaving || _authToken == null) {
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
        token: _authToken!,
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

  Future<void> _loadInventory() async {
    if (_authToken == null || _isInventoryLoading) {
      return;
    }
    setState(() {
      _isInventoryLoading = true;
      _error = null;
    });
    try {
      final data = await _apiClient.getInventory(_authToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _inventory = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur inventaire: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInventoryLoading = false;
        });
      }
    }
  }

  Future<void> _createSpool() async {
    if (_authToken == null || _isSpoolCrudLoading) {
      return;
    }
    final brand = _spoolBrandController.text.trim();
    final material = _spoolMaterialController.text.trim();
    final color = _spoolColorController.text.trim();
    final initialWeight = double.tryParse(_spoolInitialController.text.trim());
    final emptyWeight = double.tryParse(_spoolEmptyController.text.trim());
    if (brand.isEmpty || material.isEmpty || color.isEmpty || initialWeight == null) {
      setState(() {
        _error = 'Champs requis spool: marque, matiere, couleur, poids initial.';
      });
      return;
    }

    setState(() {
      _isSpoolCrudLoading = true;
      _error = null;
    });

    try {
      final created = await _apiClient.createSpool(
        token: _authToken!,
        payload: {
          'nfc_id': _spoolNfcController.text.trim(),
          'brand_name': brand,
          'material_name': material,
          'color_name': color,
          'initial_weight': initialWeight,
          'empty_spool_weight': emptyWeight ?? 200,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Bobine creee (id ${created.id}).';
      });
      await _loadInventory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur creation spool: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSpoolCrudLoading = false;
        });
      }
    }
  }

  Future<void> _updateSpool() async {
    if (_authToken == null || _isSpoolCrudLoading) {
      return;
    }
    final id = int.tryParse(_spoolIdController.text.trim());
    if (id == null || id <= 0) {
      setState(() {
        _error = 'ID spool invalide pour update.';
      });
      return;
    }

    setState(() {
      _isSpoolCrudLoading = true;
      _error = null;
    });
    try {
      await _apiClient.updateSpool(
        token: _authToken!,
        id: id,
        payload: {
          if (_spoolNfcController.text.trim().isNotEmpty) 'nfc_id': _spoolNfcController.text.trim(),
          if (_spoolBrandController.text.trim().isNotEmpty) 'brand_name': _spoolBrandController.text.trim(),
          if (_spoolMaterialController.text.trim().isNotEmpty) 'material_name': _spoolMaterialController.text.trim(),
          if (_spoolColorController.text.trim().isNotEmpty) 'color_name': _spoolColorController.text.trim(),
          if (_spoolInitialController.text.trim().isNotEmpty)
            'initial_weight': double.tryParse(_spoolInitialController.text.trim()),
          if (_spoolEmptyController.text.trim().isNotEmpty)
            'empty_spool_weight': double.tryParse(_spoolEmptyController.text.trim()),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Bobine mise a jour.';
      });
      await _loadInventory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur update spool: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSpoolCrudLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSpool() async {
    if (_authToken == null || _isSpoolCrudLoading) {
      return;
    }
    final id = int.tryParse(_spoolIdController.text.trim());
    if (id == null || id <= 0) {
      setState(() {
        _error = 'ID spool invalide pour delete.';
      });
      return;
    }

    setState(() {
      _isSpoolCrudLoading = true;
      _error = null;
    });
    try {
      await _apiClient.deleteSpool(token: _authToken!, id: id);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Bobine supprimee.';
      });
      await _loadInventory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur delete spool: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSpoolCrudLoading = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    if (_authToken == null || _isStatsLoading) {
      return;
    }
    setState(() {
      _isStatsLoading = true;
      _error = null;
    });
    try {
      final materials = await _apiClient.getStatsMaterials(_authToken!);
      final projects = await _apiClient.getStatsProjects(_authToken!);
      final monthly = await _apiClient.getStatsMonthly(_authToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _statsMaterials = materials;
        _statsProjects = projects;
        _statsMonthly = monthly;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur stats: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStatsLoading = false;
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
        child: ListView(
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_lastUid != null) Text('UID: $_lastUid'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            _buildAuthCard(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _nfcAvailable && !_isScanning && _authToken != null ? _startScan : null,
              child: const Text('Scanner une bobine'),
            ),
            const SizedBox(height: 12),
            if (_spool != null) _buildSpoolCard(context),
            const SizedBox(height: 12),
            _buildSpoolCrudCard(),
            const SizedBox(height: 12),
            _buildInventoryCard(),
            const SizedBox(height: 12),
            _buildStatsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(_authToken == null ? 'Authentification requise' : 'Authentifie'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isAuthLoading ? null : _register,
                    child: const Text('Creer compte'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _isAuthLoading ? null : _login,
                    child: const Text('Connexion'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _authToken != null && !_isAuthLoading ? _changePasswordDialog : null,
                    child: const Text('Changer mot de passe'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _authToken != null && !_isAuthLoading ? _logout : null,
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoolCard(BuildContext context) {
    final spool = _spool!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }

  Widget _buildSpoolCrudCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gestion Bobines (Create/Update/Delete)'),
            const SizedBox(height: 8),
            TextField(
              controller: _spoolIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID spool (update/delete)'),
            ),
            TextField(
              controller: _spoolNfcController,
              decoration: const InputDecoration(labelText: 'NFC ID'),
            ),
            TextField(
              controller: _spoolBrandController,
              decoration: const InputDecoration(labelText: 'Marque'),
            ),
            TextField(
              controller: _spoolMaterialController,
              decoration: const InputDecoration(labelText: 'Matiere'),
            ),
            TextField(
              controller: _spoolColorController,
              decoration: const InputDecoration(labelText: 'Couleur'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolInitialController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Poids initial'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolEmptyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Poids bobine vide'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _authToken != null && !_isSpoolCrudLoading ? _createSpool : null,
                  child: const Text('Create'),
                ),
                OutlinedButton(
                  onPressed: _authToken != null && !_isSpoolCrudLoading ? _updateSpool : null,
                  child: const Text('Update'),
                ),
                OutlinedButton(
                  onPressed: _authToken != null && !_isSpoolCrudLoading ? _deleteSpool : null,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Inventaire')),
                TextButton(
                  onPressed: _authToken != null && !_isInventoryLoading ? _loadInventory : null,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (_inventory.isEmpty)
              const Text('Aucune donnee inventaire.')
            else
              ..._inventory.take(20).map(
                    (e) => Text(
                      '#${e.id} ${e.brand} ${e.color} | ${e.material} | ${e.remainingWeight.toStringAsFixed(1)}g',
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Stats')),
                TextButton(
                  onPressed: _authToken != null && !_isStatsLoading ? _loadStats : null,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const Text('Par matiere'),
            ..._statsMaterials.map((e) => Text('${e['type_materials']}: ${e['poids_total']}')),
            const SizedBox(height: 8),
            const Text('Par projet'),
            ..._statsProjects.map((e) => Text('${e['project_name']}: ${e['total_consomme']}')),
            const SizedBox(height: 8),
            const Text('Par mois'),
            ..._statsMonthly.map((e) => Text('${e['mois']}: ${e['total_consomme']}')),
          ],
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
      id: _asInt(json['id_spools']),
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

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}

class ApiClient {
  final http.Client _client = http.Client();

  Uri _uri(String path) => Uri.parse('$_apiBaseUrl$path');

  Map<String, String> _headersWithToken(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<String> register({required String email, required String password}) {
    return _auth('/api/auth/register', email, password);
  }

  Future<String> login({required String email, required String password}) {
    return _auth('/api/auth/login', email, password);
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      _uri('/api/auth/logout'),
      headers: _headersWithToken(token),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<String> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/change-password'),
      headers: _headersWithToken(token),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['access_token'] as String;
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<String> _auth(String path, String email, String password) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['access_token'] as String;
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<List<Spool>> getInventory(String token) async {
    final response = await _client.get(
      _uri('/api/spools'),
      headers: _headersWithToken(token),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.map((e) => Spool.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<Spool> createSpool({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      _uri('/api/spools'),
      headers: _headersWithToken(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Spool.fromJson(decoded);
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<void> updateSpool({
    required String token,
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      _uri('/api/spools/$id'),
      headers: _headersWithToken(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> deleteSpool({required String token, required int id}) async {
    final response = await _client.delete(
      _uri('/api/spools/$id'),
      headers: _headersWithToken(token),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getStatsMaterials(String token) async {
    return _getStats('/api/stats/materials', token);
  }

  Future<List<Map<String, dynamic>>> getStatsProjects(String token) async {
    return _getStats('/api/stats/projects', token);
  }

  Future<List<Map<String, dynamic>>> getStatsMonthly(String token) async {
    return _getStats('/api/stats/monthly', token);
  }

  Future<List<Map<String, dynamic>>> _getStats(String path, String token) async {
    final response = await _client.get(
      _uri(path),
      headers: _headersWithToken(token),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.map((e) => (e as Map<String, dynamic>)).toList();
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<Spool> getSpoolByUid(String uid, String token) async {
    final response = await _client.get(
      _uri('/api/spools/nfc/$uid'),
      headers: _headersWithToken(token),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Spool.fromJson(decoded);
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<void> createUsage({
    required String token,
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
      headers: _headersWithToken(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
