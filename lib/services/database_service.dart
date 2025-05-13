import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'fourrages.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
  CREATE TABLE essais (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL,
    nb_parcelles INTEGER NOT NULL,
    nb_lignes INTEGER NOT NULL,
    surface_parcelle REAL,
    date_semis TEXT
  );
''');
        await db.execute('''
          CREATE TABLE notations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL
          );
        ''');

        await db.execute('''
  CREATE TABLE notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    essai_id INTEGER,
    notation_id INTEGER,
    parcelle_index INTEGER,
    note REAL,
    FOREIGN KEY (essai_id) REFERENCES essais(id),
    FOREIGN KEY (notation_id) REFERENCES notations(id),
    UNIQUE (essai_id, notation_id, parcelle_index) ON CONFLICT REPLACE
  );
''');

      },
    );
  }

  Future<int> insertEssai(String nom, int nbParcelles, int nbLignes, double surface, String dateSemis) async {
    final dbClient = await db;
    return await dbClient.insert('essais', {
      'nom': nom,
      'nb_parcelles': nbParcelles,
      'nb_lignes': nbLignes,
      'surface_parcelle': surface,
      'date_semis': dateSemis,
    });
  }

  Future<List<Map<String, dynamic>>> getEssais() async {
    final dbClient = await db;
    return await dbClient.query('essais',
        orderBy: 'nom COLLATE NOCASE ASC',);
  }

  Future<int> insertNotationType(String nom) async {
    final dbClient = await db;
    return await dbClient.insert('notations', {
      'nom': nom,
    });
  }

  Future<List<Map<String, dynamic>>> getNotationTypes() async {
    final dbClient = await db;
    return await dbClient.query('notations');
  }

  Future<void> insertNote(int essaiId, int notationId, int parcelleIndex, double note) async {
    final dbClient = await db;
    await dbClient.insert(
      'notes',
      {
        'essai_id': essaiId,
        'notation_id': notationId,
        'parcelle_index': parcelleIndex,
        'note': note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<void> deleteNote(int essaiId, int notationId, int parcelleIndex) async {
    final dbClient = await db;
    await dbClient.delete(
      'notes',
      where: 'essai_id = ? AND notation_id = ? AND parcelle_index = ?',
      whereArgs: [essaiId, notationId, parcelleIndex],
    );
  }


  Future<List<Map<String, dynamic>>> getNotes(int essaiId, int notationId) async {
    final dbClient = await db;
    return await dbClient.query(
      'notes',
      where: 'essai_id = ? AND notation_id = ?',
      whereArgs: [essaiId, notationId],
    );
  }

  Future<void> deleteEssai(int id) async {
    final dbClient = await db;
    await dbClient.delete('notes', where: 'essai_id = ?', whereArgs: [id]);
    await dbClient.delete('essais', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNotationType(int id) async {
    final dbClient = await db;
    await dbClient.delete('notes', where: 'notation_id = ?', whereArgs: [id]);
    await dbClient.delete('notations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateEssai(int id, String nom, int nbParcelles, int nbLignes, double surface, String dateSemis) async {
    final dbClient = await db;
    await dbClient.update('essais', {
      'nom': nom,
      'nb_parcelles': nbParcelles,
      'nb_lignes': nbLignes,
      'surface_parcelle': surface,
      'date_semis': dateSemis,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateNotationType(int id, String nom) async {
    final dbClient = await db;
    await dbClient.update('notations', {
      'nom': nom,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearNotesOfEssai(int essaiId) async {
    final dbClient = await db;
    await dbClient.delete('notes', where: 'essai_id = ?', whereArgs: [essaiId]);
  }

  Future<void> clearNotesOfEssaiForType(int essaiId, int notationId) async {
    final dbClient = await db;
    await dbClient.update(
      'notes',
      {'note': null},
      where: 'essai_id = ? AND notation_id = ?',
      whereArgs: [essaiId, notationId],
    );
  }

  Future<bool> essaiADesNotations(int essaiId) async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as total FROM notes WHERE essai_id = ? AND note IS NOT NULL',
      [essaiId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  Future<void> exportNotesOfEssai(int essaiId, String essaiNom, String typeNotation) async {
    final dbClient = await db;
    final essais = await getEssais();
    final essai = essais.firstWhere((e) => e['id'] == essaiId, orElse: () => {});
    final dateSemis = essai['date_semis'] ?? '';
    final surface = essai['surface_parcelle']?.toString() ?? '';
    final nbParcelles = essai['nb_parcelles'] as int? ?? 0;

    final dir = Directory('/storage/emulated/0/FourragesNotations/export');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    Future<void> exportType(String nomType, int notationId) async {
      final notes = await dbClient.query(
        'notes',
        where: 'essai_id = ? AND notation_id = ?',
        whereArgs: [essaiId, notationId],
      );

      final Map<int, dynamic> notesMap = {
        for (var note in notes)
          if (note['parcelle_index'] != null)
            note['parcelle_index'] as int: note['note']
      };

      final filename = '$essaiNom.$nomType.$dateStr.csv';
      final file = File('${dir.path}/$filename');
      final sink = file.openWrite();
      sink.writeln("$dateSemis,$surface");
      sink.writeln("parcelle,note");

      for (int i = 0; i < nbParcelles; i++) {
        final parcelle = "${essaiNom}_${i + 10}";
        final note = notesMap[i];
        sink.writeln("$parcelle,${note ?? '-'}");
      }

      await sink.close();
    }

    if (typeNotation == '__TOUS__') {
      final types = await getNotationTypes();

      for (final type in types) {
        final notationId = type['id'];
        final nomType = type['nom'];

        final countResult = await dbClient.rawQuery(
          'SELECT COUNT(*) as total FROM notes WHERE essai_id = ? AND notation_id = ? AND note IS NOT NULL',
          [essaiId, notationId],
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;

        if (count > 0) {
          await exportType(nomType, notationId);
        }
      }
    }else {
      final type = await dbClient.query(
        'notations',
        where: 'nom = ?',
        whereArgs: [typeNotation],
      );

      if (type.isEmpty) return;

      final notationId = type.first['id'] as int;
      await exportType(typeNotation, notationId);
    }
  }



  Future<List<FileSystemEntity>> listExportedCsvFiles() async {
    final dir = Directory('/storage/emulated/0/FourragesNotations/export');
    if (!await dir.exists()) return [];
    return dir.listSync().where((f) => f.path.endsWith('.csv')).toList();
  }

  Future<void> deleteExportedCsvFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
  Future<void> deleteAllExportedCsvFiles() async {
    final dir = Directory('/storage/emulated/0/FourragesNotations/export');
    if (await dir.exists()) {
      final files = dir.listSync().where((f) => f.path.endsWith('.csv'));
      for (final file in files) {
        await File(file.path).delete();
      }
    }
  }
  Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'fourrages.db');
  }
}
