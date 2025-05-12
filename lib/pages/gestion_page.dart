import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class GestionPage extends StatefulWidget {
  const GestionPage({super.key});

  @override
  State<GestionPage> createState() => _GestionPageState();
}

class _GestionPageState extends State<GestionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showEssaiForm({Map<String, dynamic>? essai}) {
    final nomCtrl = TextEditingController(text: essai?['nom'] ?? '');
    final nbParcCtrl = TextEditingController(text: essai?['nb_parcelles']?.toString() ?? '');
    final nbLignesCtrl = TextEditingController(text: essai?['nb_lignes']?.toString() ?? '');
    final surfaceCtrl = TextEditingController(text: essai?['surface_parcelle']?.toString() ?? '');
    final dateSemisCtrl = TextEditingController(text: essai?['date_semis'] ?? '');

    String? errorMessage;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(essai == null ? 'Nouvel essai' : 'Modifier essai'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(
                  controller: nbParcCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de parcelles'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: nbLignesCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de lignes'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: surfaceCtrl,
                  decoration: const InputDecoration(labelText: 'Surface des parcelles'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: dateSemisCtrl,
                  decoration: const InputDecoration(labelText: 'Date de semis (JJ/MM/AAAA)'),
                  keyboardType: TextInputType.datetime,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final nom = nomCtrl.text.trim();
                final nbText = nbParcCtrl.text.trim();
                final lignesText = nbLignesCtrl.text.trim();
                final surfaceText = surfaceCtrl.text.trim();
                final dateSemis = dateSemisCtrl.text.trim();

                if (nom.isEmpty || nbText.isEmpty || lignesText.isEmpty || surfaceText.isEmpty || dateSemis.isEmpty) {
                  setState(() {
                    errorMessage = 'Tous les champs sont obligatoires.';
                  });
                  return;
                }

                final nb = int.tryParse(nbText);
                final lignes = int.tryParse(lignesText);
                final surface = double.tryParse(surfaceText);

                if (nb == null || lignes == null || surface == null) {
                  setState(() {
                    errorMessage = 'Champs numériques invalides.';
                  });
                  return;
                }

                // Ici tu peux ajouter une vérification du format JJ/MM/AAAA si tu veux

                // Insertion ou mise à jour
                if (essai == null) {
                  await db.insertEssai(nom, nb, lignes, surface, dateSemis);
                } else {
                  await db.updateEssai(essai['id'], nom, nb, lignes, surface, dateSemis);
                }

                Navigator.pop(context);
                this.setState(() {}); // met à jour l'écran principal
              },
              child: const Text('Valider'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> exportDatabase() async {
    try {
      final dbPath = await db.getDatabasePath();

      // Dossier souhaité : /storage/emulated/0/FourragesNotations
      final dir = Directory('/storage/emulated/0/FourragesNotations');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final backupFile = File('${dir.path}/backup.db');
      await File(dbPath).copy(backupFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Base exportée : ${backupFile.path}")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur export : $e")),
        );
      }
    }
  }
  Future<void> importDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null) {
        final pickedFile = File(result.files.single.path!);
        final dbPath = await db.getDatabasePath();

        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirmation"),
            content: const Text("Importer ce fichier et écraser la base actuelle ?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Importer")),
            ],
          ),
        );

        if (confirm == true) {
          await pickedFile.copy(dbPath);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Base de données importée avec succès.")),
            );
            setState(() {}); // recharger l’interface
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur import : $e")),
        );
      }
    }
  }
  void _showNotationForm({Map<String, dynamic>? notation}) {
    final ctrl = TextEditingController(text: notation?['nom'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notation == null ? 'Nouvelle notation' : 'Modifier notation'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(
            onPressed: () async {
              final nom = ctrl.text.trim();
              if (notation == null) {
                await db.insertNotationType(nom);
              } else {
                await db.updateNotationType(notation['id'], nom);
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Valider'),
          )
        ],
      ),
    );
  }

  Widget _buildEssaiTab() {
    return FutureBuilder(
      future: db.getEssais(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final essais = snapshot.data as List<Map<String, dynamic>>;
        return ListView(
          children: [
            for (final essai in essais)
              ListTile(
                title: Text(essai['nom']),
                subtitle: Text("${essai['nb_parcelles']} parcelles - ${essai['nb_lignes']} lignes"),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEssaiForm(essai: essai);
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirmation'),
                          content: Text("Supprimer l'essai \"${essai['nom']}\" ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await db.deleteEssai(essai['id']);
                        setState(() {});
                      }
                    } else if (value == 'export') {
                      final allTypes = await db.getNotationTypes();
                      final filteredTypes = <Map<String, dynamic>>[];

                      for (final type in allTypes) {
                        final notes = await db.getNotes(essai['id'], type['id']);
                        if (notes.any((n) => n['note'] != null)) {
                          filteredTypes.add(type);
                        }
                      }

                      if (!context.mounted) return;

                      if (filteredTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Aucune notation enregistrée pour \"${essai['nom']}\".")),
                        );
                        return;
                      }

                      final selected = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Sélectionner un type de notation"),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  title: const Text("Tous les types"),
                                  leading: const Icon(Icons.select_all),
                                  onTap: () => Navigator.pop(context, '__TOUS__'),
                                ),
                                ...filteredTypes.map((n) {
                                  return ListTile(
                                    title: Text(n['nom']),
                                    onTap: () => Navigator.pop(context, n['nom']),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (selected != null) {
                        await db.exportNotesOfEssai(essai['id'], essai['nom'], selected);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(selected == '__TOUS__'
                                  ? "Export CSV de tous les types pour \"${essai['nom']}\" terminé."
                                  : "Export CSV de \"${essai['nom']}\" ($selected) terminé."),
                            ),
                          );
                        }
                      }
                    } else if (value == 'clear') {
                      final allTypes = await db.getNotationTypes();
                      final filteredTypes = <Map<String, dynamic>>[];

                      for (final type in allTypes) {
                        final notes = await db.getNotes(essai['id'], type['id']);
                        if (notes.any((n) => n['note'] != null)) {
                          filteredTypes.add(type);
                        }
                      }

                      if (!context.mounted) return;

                      if (filteredTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Aucune notation enregistrée pour \"${essai['nom']}\".")),
                        );
                        return;
                      }

                      final selected = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Réinitialiser les notations"),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  title: const Text("Tous les types"),
                                  leading: const Icon(Icons.delete_forever),
                                  onTap: () => Navigator.pop(context, '__TOUS__'),
                                ),
                                ...filteredTypes.map((n) {
                                  return ListTile(
                                    title: Text(n['nom']),
                                    onTap: () => Navigator.pop(context, n['id'].toString()),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (selected != null) {
                        String message;
                        if (selected == '__TOUS__') {
                          message = "Réinitialiser *toutes* les notations de \"${essai['nom']}\" ?";
                        } else {
                          final typeId = int.tryParse(selected);
                          final allTypes = await db.getNotationTypes();
                          final selectedType = allTypes.firstWhere((t) => t['id'] == typeId);
                          final typeNom = selectedType['nom'];
                          message = "Réinitialiser la notation \"$typeNom\" de \"${essai['nom']}\" ?";
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Confirmation"),
                            content: Text(message),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirmer")),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          if (selected == '__TOUS__') {
                            await db.clearNotesOfEssai(essai['id']);
                          } else {
                            final typeId = int.tryParse(selected);
                            if (typeId != null) {
                              await db.clearNotesOfEssaiForType(essai['id'], typeId);
                            }
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Notations de \"${essai['nom']}\" réinitialisées.")),
                            );
                          }
                        }
                      }
                    }

                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text("Modifier")),
                    const PopupMenuItem(value: 'delete', child: Text("Supprimer")),
                    const PopupMenuItem(value: 'export', child: Text("Exporter CSV")),
                    const PopupMenuItem(value: 'clear', child: Text("Réinitialiser notations")),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => _showEssaiForm(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un essai'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotationTab() {
    return FutureBuilder(
      future: db.getNotationTypes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final notations = snapshot.data as List<Map<String, dynamic>>;
        return ListView(
          children: [
            for (final n in notations)
              ListTile(
                title: Text(n['nom']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showNotationForm(notation: n)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirmation'),
                          content: Text("Supprimer la notation \"${n['nom']}\" ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await db.deleteNotationType(n['id']);
                        setState(() {});
                      }
                    }),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => _showNotationForm(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un type de notation'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des données"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Essais'),
            Tab(text: 'Notations'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEssaiTab(),
                _buildNotationTab(),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text("Exporter BDD"),
                onPressed: exportDatabase,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text("Importer BDD"),
                onPressed: importDatabase,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text("Voir les fichiers exportés"),
              onPressed: () async {
                final fichiers = await db.listExportedCsvFiles();
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Fichiers exportés"),
                    content: fichiers.isEmpty
                        ? const Text("Aucun fichier trouvé.")
                        : SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView(
                        children: fichiers.map((f) {
                          final name = f.path.split('/').last;
                          return ListTile(
                            title: Text(name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.blue),
                                  onPressed: () async {
                                    await Share.shareXFiles([XFile(f.path)], text: "Voici un fichier exporté depuis l'application.");
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Confirmation"),
                                        content: Text("Supprimer le fichier \"$name\" ?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer")),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await db.deleteExportedCsvFile(f.path);
                                      Navigator.pop(context);
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              final result = await OpenFilex.open(f.path);
                              if (result.type != ResultType.done && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur à l'ouverture : ${result.message}")),
                                );
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Confirmation"),
                              content: const Text("Supprimer tous les fichiers exportés ?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer tout")),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await db.deleteAllExportedCsvFiles();
                            Navigator.pop(context); // ferme le popup
                            setState(() {}); // recharge les fichiers
                          }
                        },
                        child: const Text("Tout supprimer"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Fermer"),
                      ),
                    ],

                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
