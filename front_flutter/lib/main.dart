import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
  final TextEditingController _manualUidController = TextEditingController();
  final TextEditingController _spoolIdController = TextEditingController();
  final TextEditingController _spoolNfcController = TextEditingController();
  final TextEditingController _spoolBrandController = TextEditingController();
  final TextEditingController _spoolMaterialController = TextEditingController();
  final TextEditingController _spoolColorController = TextEditingController();
  final TextEditingController _spoolInitialController = TextEditingController(text: '1000');
  final TextEditingController _spoolEmptyController = TextEditingController(text: '200');
  final TextEditingController _spoolDiameterController = TextEditingController(text: '1.75');
  final TextEditingController _spoolTempImpController = TextEditingController(text: '200');
  final TextEditingController _spoolTempBedController = TextEditingController(text: '50');
  final TextEditingController _spoolDebitController = TextEditingController(text: '100');
  final TextEditingController _spoolPressureAdvanceController = TextEditingController(text: '0');
  final TextEditingController _spoolVitVolMaxController = TextEditingController(text: '15');
  final TextEditingController _spoolVitImpController = TextEditingController(text: '60');

  bool _nfcAvailable = false;
  bool _isAuthLoading = false;
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isInventoryLoading = false;
  bool _isSpoolCrudLoading = false;
  bool _isStatsLoading = false;
  int _selectedIndex = 0;
  String _status = 'Verification NFC...';
  String? _authToken;
  String? _lastUid;
  Spool? _spool;
  List<Spool> _inventory = const [];
  List<Map<String, dynamic>> _inventoryAggregated = const [];
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
    _manualUidController.dispose();
    _spoolIdController.dispose();
    _spoolNfcController.dispose();
    _spoolBrandController.dispose();
    _spoolMaterialController.dispose();
    _spoolColorController.dispose();
    _spoolInitialController.dispose();
    _spoolEmptyController.dispose();
    _spoolDiameterController.dispose();
    _spoolTempImpController.dispose();
    _spoolTempBedController.dispose();
    _spoolDebitController.dispose();
    _spoolPressureAdvanceController.dispose();
    _spoolVitVolMaxController.dispose();
    _spoolVitImpController.dispose();
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
          } on ApiHttpException catch (e) {
            if (!mounted) {
              return;
            }
            if (e.statusCode == 404) {
              setState(() {
                _lastUid = uid;
                _spool = null;
                _status = 'Tag lu, bobine introuvable.';
                _error = null;
                _isScanning = false;
              });
              await NfcManager.instance.stopSession(errorMessageIos: 'Bobine introuvable');
              await _promptCreateSpoolForUnknownTag(uid);
              return;
            }
            setState(() {
              _lastUid = uid;
              _spool = null;
              _status = 'Echec lecture bobine.';
              _error = e.toString();
              _isScanning = false;
            });
            await NfcManager.instance.stopSession(errorMessageIos: 'Erreur API');
          } catch (e) {
            if (!mounted) {
              return;
            }
            setState(() {
              _lastUid = uid;
              _spool = null;
              _status = 'Echec lecture bobine.';
              _error = e.toString();
              _isScanning = false;
            });
            await NfcManager.instance.stopSession(errorMessageIos: 'Erreur API');
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
      final aggregated = await _apiClient.getAggregatedInventory(_authToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _inventory = data;
        _inventoryAggregated = aggregated;
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
    final diameter = double.tryParse(_spoolDiameterController.text.trim());
    final tempImp = double.tryParse(_spoolTempImpController.text.trim());
    final tempBed = double.tryParse(_spoolTempBedController.text.trim());
    final debit = double.tryParse(_spoolDebitController.text.trim());
    final pressureAdvance = double.tryParse(_spoolPressureAdvanceController.text.trim());
    final vitVolMax = double.tryParse(_spoolVitVolMaxController.text.trim());
    final vitImp = double.tryParse(_spoolVitImpController.text.trim());
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
          'diametre': diameter ?? 1.75,
          'temperature_imp': tempImp ?? 200,
          'temperature_table': tempBed ?? 50,
          'debit': debit ?? 100,
          'pressure_advance': pressureAdvance ?? 0,
          'vit_volum_max': vitVolMax ?? 15,
          'vit_imp': vitImp ?? 60,
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

    final initialWeight = double.tryParse(_spoolInitialController.text.trim());
    final emptyWeight = double.tryParse(_spoolEmptyController.text.trim());
    final diameter = double.tryParse(_spoolDiameterController.text.trim());
    final tempImp = double.tryParse(_spoolTempImpController.text.trim());
    final tempBed = double.tryParse(_spoolTempBedController.text.trim());
    final debit = double.tryParse(_spoolDebitController.text.trim());
    final pressureAdvance = double.tryParse(_spoolPressureAdvanceController.text.trim());
    final vitVolMax = double.tryParse(_spoolVitVolMaxController.text.trim());
    final vitImp = double.tryParse(_spoolVitImpController.text.trim());

    try {
      await _apiClient.updateSpool(
        token: _authToken!,
        id: id,
        payload: {
          if (_spoolNfcController.text.trim().isNotEmpty) 'nfc_id': _spoolNfcController.text.trim(),
          if (_spoolBrandController.text.trim().isNotEmpty) 'brand_name': _spoolBrandController.text.trim(),
          if (_spoolMaterialController.text.trim().isNotEmpty) 'material_name': _spoolMaterialController.text.trim(),
          if (_spoolColorController.text.trim().isNotEmpty) 'color_name': _spoolColorController.text.trim(),
          if (_spoolInitialController.text.trim().isNotEmpty && initialWeight != null) 'initial_weight': initialWeight,
          if (_spoolEmptyController.text.trim().isNotEmpty && emptyWeight != null) 'empty_spool_weight': emptyWeight,
          if (_spoolDiameterController.text.trim().isNotEmpty && diameter != null) 'diametre': diameter,
          if (_spoolTempImpController.text.trim().isNotEmpty && tempImp != null) 'temperature_imp': tempImp,
          if (_spoolTempBedController.text.trim().isNotEmpty && tempBed != null) 'temperature_table': tempBed,
          if (_spoolDebitController.text.trim().isNotEmpty && debit != null) 'debit': debit,
          if (_spoolPressureAdvanceController.text.trim().isNotEmpty && pressureAdvance != null)
            'pressure_advance': pressureAdvance,
          if (_spoolVitVolMaxController.text.trim().isNotEmpty && vitVolMax != null) 'vit_volum_max': vitVolMax,
          if (_spoolVitImpController.text.trim().isNotEmpty && vitImp != null) 'vit_imp': vitImp,
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
    final titles = [
      'Kaki3D - Scan NFC',
      'Kaki3D - Inventaire',
      'Kaki3D - Ajout Bobine',
      'Kaki3D - Modifier Bobine',
      'Kaki3D - Stats',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
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
            if (_authToken == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Connecte-toi pour acceder aux ecrans inventaire/ajout/modif/stats.'),
                ),
              )
            else
              _buildActiveScreen(context),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nfc),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventaire',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Ajout',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            label: 'Modif',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  Future<void> _searchUidManually() async {
    if (_authToken == null) {
      return;
    }
    final uid = _manualUidController.text.trim().toUpperCase();
    if (uid.isEmpty) {
      setState(() {
        _error = 'Saisis un UID NFC valide.';
      });
      return;
    }

    setState(() {
      _error = null;
      _status = 'Recherche bobine pour UID $uid...';
    });

    try {
      final spool = await _apiClient.getSpoolByUid(uid, _authToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastUid = uid;
        _spool = spool;
        _status = 'Bobine trouvee via UID manuel.';
        _weightController.text = '10';
      });
    } on ApiHttpException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.statusCode == 404) {
        setState(() {
          _lastUid = uid;
          _spool = null;
          _status = 'UID inconnu.';
          _error = null;
        });
        await _promptCreateSpoolForUnknownTag(uid);
        return;
      }
      setState(() {
        _error = 'Erreur recherche UID: $e';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur recherche UID: $e';
      });
    }
  }

  Widget _buildActiveScreen(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildScanAndUsageCard(context);
      case 1:
        return _buildInventoryCard();
      case 2:
        return _buildSpoolCreateCard();
      case 3:
        return _buildSpoolEditCard();
      case 4:
        return _buildStatsCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _cloneSpoolFromInventory(Spool spool) async {
    if (_authToken == null || _isSpoolCrudLoading) {
      return;
    }

    final nfcCtrl = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Dupliquer bobine #${spool.id}'),
          content: TextField(
            controller: nfcCtrl,
            decoration: const InputDecoration(
              labelText: 'NFC ID (optionnel)',
              hintText: 'Laisser vide pour associer plus tard',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Dupliquer'),
            ),
          ],
        );
      },
    );

    if (!mounted || create != true) {
      nfcCtrl.dispose();
      return;
    }

    setState(() {
      _isSpoolCrudLoading = true;
      _error = null;
    });

    try {
      final nfcId = nfcCtrl.text.trim();
      final cloned = await _apiClient.cloneSpool(
        token: _authToken!,
        id: spool.id,
        nfcId: nfcId.isEmpty ? null : nfcId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Bobine dupliquee (id ${cloned.id}).';
      });
      await _loadInventory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Erreur duplication bobine: $e';
      });
    } finally {
      nfcCtrl.dispose();
      if (mounted) {
        setState(() {
          _isSpoolCrudLoading = false;
        });
      }
    }
  }

  void _prefillSpoolFields(Spool spool, {required bool includeId}) {
    if (includeId) {
      _spoolIdController.text = spool.id.toString();
    }
    _spoolNfcController.text = spool.nfcId;
    _spoolBrandController.text = spool.brand;
    _spoolMaterialController.text = spool.material;
    _spoolColorController.text = spool.color;
    _spoolInitialController.text = spool.initialWeight.toStringAsFixed(2);
    _spoolEmptyController.text = spool.emptySpoolWeight.toStringAsFixed(2);
    _spoolDiameterController.text = spool.diameter.toStringAsFixed(2);
    _spoolTempImpController.text = spool.temperatureImp.toStringAsFixed(2);
    _spoolTempBedController.text = spool.temperatureTable.toStringAsFixed(2);
    _spoolDebitController.text = spool.debit.toStringAsFixed(2);
    _spoolPressureAdvanceController.text = spool.pressureAdvance.toStringAsFixed(3);
    _spoolVitVolMaxController.text = spool.vitVolumMax.toStringAsFixed(2);
    _spoolVitImpController.text = spool.vitImp.toStringAsFixed(2);
  }

  void _openSpoolInEdit(Spool spool) {
    setState(() {
      _prefillSpoolFields(spool, includeId: true);
      _selectedIndex = 3;
      _status = 'Bobine #${spool.id} chargee dans l\'ecran Modif.';
      _error = null;
    });
  }

  void _openSpoolForConsumption(Spool spool) {
    setState(() {
      _spool = spool;
      _lastUid = spool.nfcId.isNotEmpty ? spool.nfcId : null;
      _selectedIndex = 0;
      _status = 'Bobine #${spool.id} chargee pour consommation.';
      _error = null;
    });
  }

  Future<void> _promptCreateSpoolForUnknownTag(String uid) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tag inconnu'),
          content: Text('Le tag $uid est inconnu. Creer une nouvelle bobine ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Creer'),
            ),
          ],
        );
      },
    );

    if (!mounted || create != true) {
      return;
    }

    setState(() {
      _spoolNfcController.text = uid;
      _selectedIndex = 2;
      _status = 'Tag inconnu: complete le formulaire pour creer la bobine.';
      _error = null;
    });
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

  Widget _buildScanAndUsageCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _nfcAvailable && !_isScanning && _authToken != null ? _startScan : null,
              child: const Text('Scanner une bobine'),
            ),
            const SizedBox(height: 8),
            if (!_nfcAvailable)
              const Text('NFC indisponible: utilise la saisie UID manuelle ci-dessous.'),
            const SizedBox(height: 8),
            TextField(
              controller: _manualUidController,
              decoration: const InputDecoration(
                labelText: 'UID manuel',
                hintText: 'Ex: 04:AB:12:CD:EF:00:01',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _authToken != null ? _searchUidManually : null,
              child: const Text('Rechercher par UID'),
            ),
            const SizedBox(height: 12),
            if (_spool != null)
              _buildSpoolCard(context)
            else
              const Text('Aucune bobine lue. Lance un scan NFC.'),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoolCreateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajout de bobine'),
            const SizedBox(height: 8),
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
            const Text('Parametres techniques'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolDiameterController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Diametre (mm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolVitImpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Vit. impression'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolTempImpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Temp. buse'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolTempBedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Temp. plateau'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolDebitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Debit (%)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolPressureAdvanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Pressure advance'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _spoolVitVolMaxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Vit. volumetrique max'),
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
                  onPressed: _isSpoolCrudLoading ? null : _clearSpoolFields,
                  child: const Text('Vider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoolEditCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Modifier / supprimer bobine'),
            const SizedBox(height: 8),
            TextField(
              controller: _spoolIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID spool (obligatoire)'),
            ),
            TextField(
              controller: _spoolNfcController,
              decoration: const InputDecoration(labelText: 'NFC ID (optionnel)'),
            ),
            TextField(
              controller: _spoolBrandController,
              decoration: const InputDecoration(labelText: 'Marque (optionnel)'),
            ),
            TextField(
              controller: _spoolMaterialController,
              decoration: const InputDecoration(labelText: 'Matiere (optionnel)'),
            ),
            TextField(
              controller: _spoolColorController,
              decoration: const InputDecoration(labelText: 'Couleur (optionnel)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolInitialController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Poids initial (opt.)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolEmptyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Poids bobine vide (opt.)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Parametres techniques (optionnels)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolDiameterController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Diametre (opt.)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolVitImpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Vit. impression (opt.)'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolTempImpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Temp. buse (opt.)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolTempBedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Temp. plateau (opt.)'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spoolDebitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Debit (opt.)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _spoolPressureAdvanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Pressure advance (opt.)'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _spoolVitVolMaxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Vit. volum max (opt.)'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _authToken != null && !_isSpoolCrudLoading ? _updateSpool : null,
                  child: const Text('Update'),
                ),
                OutlinedButton(
                  onPressed: _authToken != null && !_isSpoolCrudLoading ? _deleteSpool : null,
                  child: const Text('Delete'),
                ),
                OutlinedButton(
                  onPressed: _isSpoolCrudLoading ? null : _clearSpoolFields,
                  child: const Text('Vider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearSpoolFields() {
    _spoolIdController.clear();
    _spoolNfcController.clear();
    _spoolBrandController.clear();
    _spoolMaterialController.clear();
    _spoolColorController.clear();
    _spoolInitialController.text = '1000';
    _spoolEmptyController.text = '200';
    _spoolDiameterController.text = '1.75';
    _spoolTempImpController.text = '200';
    _spoolTempBedController.text = '50';
    _spoolDebitController.text = '100';
    _spoolPressureAdvanceController.text = '0';
    _spoolVitVolMaxController.text = '15';
    _spoolVitImpController.text = '60';
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
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('#${e.id} ${e.brand} ${e.color}'),
                      subtitle: Text('${e.material} | ${e.remainingWeight.toStringAsFixed(1)}g'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'clone') {
                            _cloneSpoolFromInventory(e);
                            return;
                          }
                          if (value == 'edit') {
                            _openSpoolInEdit(e);
                            return;
                          }
                          if (value == 'use') {
                            _openSpoolForConsumption(e);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'use', child: Text('Utiliser')),
                          PopupMenuItem(value: 'edit', child: Text('Modifier')),
                          PopupMenuItem(value: 'clone', child: Text('Dupliquer')),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            const Text('Stock agrege', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_inventoryAggregated.isEmpty)
              const Text('Aucune donnee agregee.')
            else
              ..._inventoryAggregated.map((row) {
                final totalInitial = Spool._asDouble(row['total_initial']);
                final totalRestant = Spool._asDouble(row['total_restant']);
                final ratio = totalInitial > 0
                    ? (totalRestant / totalInitial).clamp(0.0, 1.0).toDouble()
                    : 0.0;
                final brand = (row['nom_marques'] ?? '').toString();
                final material = (row['type_materials'] ?? '').toString();
                final color = (row['color_name'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$brand | $material | $color'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: ratio),
                      const SizedBox(height: 4),
                      Text('${totalRestant.toStringAsFixed(0)}g / ${totalInitial.toStringAsFixed(0)}g'),
                    ],
                  ),
                );
              }),
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
            const SizedBox(height: 8),
            const Text('Par matiere', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildBarChartFromRows(
              context: context,
              rows: _statsMaterials,
              labelKey: 'type_materials',
              valueKey: 'poids_total',
              emptyText: 'Aucune donnee matiere.',
            ),
            const SizedBox(height: 8),
            const Text('Par projet', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildBarChartFromRows(
              context: context,
              rows: _statsProjects,
              labelKey: 'project_name',
              valueKey: 'total_consomme',
              emptyText: 'Aucune donnee projet.',
            ),
            const SizedBox(height: 8),
            const Text('Par mois', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildBarChartFromRows(
              context: context,
              rows: _statsMonthly,
              labelKey: 'mois',
              valueKey: 'total_consomme',
              emptyText: 'Aucune donnee mensuelle.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartFromRows({
    required BuildContext context,
    required List<Map<String, dynamic>> rows,
    required String labelKey,
    required String valueKey,
    required String emptyText,
  }) {
    if (rows.isEmpty) {
      return Text(emptyText);
    }

    final labels = rows.map((e) => (e[labelKey] ?? '').toString()).toList();
    final values = rows.map((e) => Spool._asDouble(e[valueKey])).toList();
    final maxY = math.max(1.0, values.reduce(math.max) * 1.2);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: maxY / 4,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  final raw = labels[idx];
                  final short = raw.length > 10 ? '${raw.substring(0, 10)}...' : raw;
                  return SideTitleWidget(
                    meta: meta,
                    child: Transform.rotate(
                      angle: -0.6,
                      child: Text(short, style: const TextStyle(fontSize: 10)),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(values.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class Spool {
  const Spool({
    required this.id,
    required this.nfcId,
    required this.brand,
    required this.color,
    required this.material,
    required this.initialWeight,
    required this.emptySpoolWeight,
    required this.diameter,
    required this.temperatureImp,
    required this.temperatureTable,
    required this.debit,
    required this.pressureAdvance,
    required this.vitVolumMax,
    required this.vitImp,
    required this.remainingWeight,
  });

  final int id;
  final String nfcId;
  final String brand;
  final String color;
  final String material;
  final double initialWeight;
  final double emptySpoolWeight;
  final double diameter;
  final double temperatureImp;
  final double temperatureTable;
  final double debit;
  final double pressureAdvance;
  final double vitVolumMax;
  final double vitImp;
  final double remainingWeight;

  factory Spool.fromJson(Map<String, dynamic> json) {
    return Spool(
      id: _asInt(json['id_spools']),
      nfcId: (json['nfc_id'] ?? '') as String,
      brand: (json['nom_marques'] ?? '') as String,
      color: (json['color_name'] ?? '') as String,
      material: (json['type_materials'] ?? '') as String,
      initialWeight: _asDouble(json['initial_weight']),
      emptySpoolWeight: _asDouble(json['empty_spool_weight']),
      diameter: _asDouble(json['diametre']),
      temperatureImp: _asDouble(json['temperature_imp']),
      temperatureTable: _asDouble(json['temperature_table']),
      debit: _asDouble(json['debit']),
      pressureAdvance: _asDouble(json['pressure_advance']),
      vitVolumMax: _asDouble(json['vit_volum_max']),
      vitImp: _asDouble(json['vit_imp']),
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

    throw ApiHttpException(response.statusCode, response.body);
  }

  Future<List<Map<String, dynamic>>> getAggregatedInventory(String token) async {
    final response = await _client.get(
      _uri('/api/spools/aggregated'),
      headers: _headersWithToken(token),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.map((e) => (e as Map<String, dynamic>)).toList();
    }

    throw ApiHttpException(response.statusCode, response.body);
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

    throw ApiHttpException(response.statusCode, response.body);
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
      throw ApiHttpException(response.statusCode, response.body);
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

  Future<Spool> cloneSpool({
    required String token,
    required int id,
    String? nfcId,
  }) async {
    final payload = <String, dynamic>{};
    if (nfcId != null) {
      payload['nfc_id'] = nfcId;
    }

    final response = await _client.post(
      _uri('/api/spools/$id/clone'),
      headers: _headersWithToken(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Spool.fromJson(decoded);
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
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

    throw ApiHttpException(response.statusCode, response.body);
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

class ApiHttpException implements Exception {
  ApiHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HTTP $statusCode: $body';
}
