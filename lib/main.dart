import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/gestion_page.dart';
import 'services/database_service.dart';
import 'package:vibration/vibration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await askPermissions();
  await ensureAppFoldersExist();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FourragesApp());
}

Future<void> askPermissions() async {
  var status = await Permission.manageExternalStorage.status;

  if (!status.isGranted) {
    status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
    }
  }
}

Future<void> ensureAppFoldersExist() async {
  try {
    final basePath = '/storage/emulated/0/FourragesNotations/export';
    final folders = ['export'];

    for (final folder in folders) {
      final dir = Directory('$basePath/$folder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      } else {
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('>> ERREUR création dossiers : $e');
    }
  }
}

class FourragesApp extends StatelessWidget {
  const FourragesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notation Fourrages',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const EssaiSelectionPage(),
    );
  }
}

class EssaiSelectionPage extends StatefulWidget {
  const EssaiSelectionPage({super.key});

  @override
  State<EssaiSelectionPage> createState() => _EssaiSelectionPageState();
}

class _EssaiSelectionPageState extends State<EssaiSelectionPage> {
  final db = DatabaseService();
  List<Map<String, dynamic>> essais = [];
  List<Map<String, dynamic>> notations = [];
  int? selectedEssaiId;
  int? selectedNotationId;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    loadData();
  }

  Future<void> loadData() async {
    await Permission.storage.request();
    essais = await db.getEssais();
    notations = await db.getNotationTypes();

    if (essais.isEmpty) {
      await db.insertEssai("EssaiTest", 12, 3, 15.5, "05/05/2025");
    }

    if (notations.isEmpty) {
      await db.insertNotationType("NotationTest");
    }
    essais = await db.getEssais();
    notations = await db.getNotationTypes();
    setState(() {});
  }


  void goToNotation() {
    if (selectedEssaiId != null && selectedNotationId != null) {
      final selectedEssai = essais.firstWhere((e) => e['id'] == selectedEssaiId);
      final selectedNotation = notations.firstWhere((e) => e['id'] == selectedNotationId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotationPage(
            essai: selectedEssai,
            notation: selectedNotation,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (essais.isEmpty && notations.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (essais.isEmpty || notations.isEmpty) {
      return Scaffold(
        body: Center(child: Text("Aucune donnée trouvée.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Sélection de l'essai")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<int>(
              isExpanded: true,
              hint: const Text("Choisir un essai"),
              value: selectedEssaiId,
              items: essais
                  .map((e) => DropdownMenuItem<int>(
                value: e['id'],
                child: Text(e['nom']),
              ))
                  .toList(),
              onChanged: (val) => setState(() => selectedEssaiId = val),
            ),
            const SizedBox(height: 20),
            DropdownButton<int>(
              isExpanded: true,
              hint: const Text("Type de notation"),
              value: selectedNotationId,
              items: notations
                  .map((e) => DropdownMenuItem<int>(
                value: e['id'],
                child: Text(e['nom']),
              ))
                  .toList(),
              onChanged: (val) => setState(() => selectedNotationId = val),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: goToNotation,
              child: const Text("Commencer la notation"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GestionPage()),
                ).then((_) => loadData());
              },
              child: const Text("Gestion des données"),
            ),
          ],
        ),
      ),
    );
  }
}

class NotationPage extends StatefulWidget {
  final Map<String, dynamic> essai;
  final Map<String, dynamic> notation;

  const NotationPage({super.key, required this.essai, required this.notation});

  @override
  State<NotationPage> createState() => _NotationPageState();
}

class _NotationPageState extends State<NotationPage> {
  final db = DatabaseService();
  final Map<int, double> notes = {};
  final Map<int, GlobalKey> parcelleKeys = {}; // 👈 Clés pour le scroll auto

  int get nbParcelles => widget.essai['nb_parcelles'];
  int get nbLignes => widget.essai['nb_lignes'];
  int get nbColonnes => (nbParcelles / nbLignes).ceil();

  List<int> parcours = [];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    parcours = _generateSerpentinParcours();
    currentIndex = parcours.first;
    loadNotes();
  }

  Future<void> loadNotes() async {
    final rawNotes = await db.getNotes(widget.essai['id'], widget.notation['id']);
    for (final row in rawNotes) {
      notes[row['parcelle_index']] = row['note'];
    }
    setState(() {});
  }

  int getParcelleId(int col, int row) {
    bool isColImpair = col % 2 == 1;
    return isColImpair
        ? 10 + (col * nbLignes) + (nbLignes - 1 - row)
        : 10 + (col * nbLignes) + row;
  }

  List<int> _generateSerpentinParcours() {
    List<int> ordre = [];
    for (int row = 0; row < nbLignes; row++) {
      List<int> ligne = [];
      for (int col = 0; col < nbColonnes; col++) {
        int index = col * nbLignes + row;
        if (index < nbParcelles) ligne.add(index);
      }
      if (row % 2 == 1) {
        ligne = ligne.reversed.toList();
      }
      ordre.addAll(ligne);
    }
    return ordre;
  }

  void enterNote(double value) async {
    setState(() => notes[currentIndex] = value);
    await db.insertNote(widget.essai['id'], widget.notation['id'], currentIndex, value);
    avancer();
  }

  void avancer() {
    final idx = parcours.indexOf(currentIndex);
    if (idx != -1 && idx + 1 < parcours.length) {
      final nextIndex = parcours[idx + 1];
      setState(() => currentIndex = nextIndex);

      // 🔁 Scroll automatique
      Future.delayed(const Duration(milliseconds: 50), () {
        final key = parcelleKeys[nextIndex];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.essai['nom']} - ${widget.notation['nom']}")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(nbColonnes, (col) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(nbLignes, (row) {
                              final index = col * nbLignes + row;
                              if (index >= nbParcelles) return const SizedBox.shrink();

                              final isNoted = notes.containsKey(index);
                              final parcelleName = "${widget.essai['nom']}_${getParcelleId(col, row)}";
                              final key = parcelleKeys[index] ?? GlobalKey();
                              parcelleKeys[index] = key;

                              return GestureDetector(
                                onTap: () {
                                  setState(() => currentIndex = index);
                                  Future.delayed(const Duration(milliseconds: 50), () {
                                    final context = key.currentContext;
                                    if (context != null) {
                                      Scrollable.ensureVisible(
                                        context,
                                        duration: const Duration(milliseconds: 300),
                                        alignment: 0.5,
                                      );
                                    }
                                  });
                                },
                                child: Container(
                                  key: key,
                                  margin: const EdgeInsets.all(8),
                                  width: 120,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: index == currentIndex
                                        ? Colors.blue
                                        : isNoted
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    parcelleName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11, // 🧾 Taille réduite
                                    ),
                                  ),
                                ),
                              );
                            }).reversed.toList(),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  "Noter : ${widget.essai['nom']}_${getParcelleId(currentIndex ~/ nbLignes, currentIndex % nbLignes)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // 🔒 Hauteur fixe pour le pavé numérique
              SizedBox(
                height: 330,
                child: NumericPad(
                  key: ValueKey(currentIndex),
                  initialValue: notes[currentIndex],
                  onValueEntered: enterNote,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NumericPad extends StatefulWidget {
  final Function(double) onValueEntered;
  final double? initialValue;

  const NumericPad({super.key, required this.onValueEntered, this.initialValue});

  @override
  State<NumericPad> createState() => _NumericPadState();
}

class _NumericPadState extends State<NumericPad> {
  late String input;

  @override
  void initState() {
    super.initState();
    input = widget.initialValue != null
        ? (widget.initialValue! % 1 == 0
        ? widget.initialValue!.toInt().toString()
        : widget.initialValue!.toString())
        : "";
  }

  Future<void> vibrate({required int duration}) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: duration);
    }
  }

  void addDigit(String digit) {
    vibrate(duration: 20); // vibration légère
    setState(() => input += digit);
  }

  void clearInput() async {
    vibrate(duration: 50); // vibration moyenne
    setState(() => input = "");
    await DatabaseService().deleteNote(
      (context.findAncestorStateOfType<_NotationPageState>()!).widget.essai['id'],
      (context.findAncestorStateOfType<_NotationPageState>()!).widget.notation['id'],
      (context.findAncestorStateOfType<_NotationPageState>()!).currentIndex,
    );
    setState(() {
      (context.findAncestorStateOfType<_NotationPageState>()!).notes.remove(
        (context.findAncestorStateOfType<_NotationPageState>()!).currentIndex,
      );
    });
  }

  void validate() {
    vibrate(duration: 100); // vibration forte
    final value = double.tryParse(input);
    if (value != null) {
      widget.onValueEntered(value);
      setState(() => input = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              input,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(
          height: 260,
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            padding: const EdgeInsets.all(8),
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              ...List.generate(9, (i) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => addDigit("${i + 1}"),
                child: Text("${i + 1}", style: const TextStyle(fontSize: 16)),
              )),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: clearInput,
                child: const Icon(Icons.backspace, size: 18),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => addDigit("0"),
                child: const Text("0", style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: validate,
                child: const Icon(Icons.check, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}