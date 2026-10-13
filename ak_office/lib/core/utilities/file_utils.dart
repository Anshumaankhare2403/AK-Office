import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class FileUtils {
  static Future<Directory> getAppBaseDirectory() async {
    Directory base;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final appDir = Directory(p.join(base.path, AppConstants.rootFolderName));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  static Future<Directory> getDocumentsDirectory() async {
    final base = await getAppBaseDirectory();
    final docsDir = Directory(p.join(base.path, AppConstants.documentsFolder));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir;
  }

  static Future<Directory> getRevisionsDirectory() async {
    final base = await getAppBaseDirectory();
    final revDir = Directory(p.join(base.path, AppConstants.revisionsFolder));
    if (!await revDir.exists()) {
      await revDir.create(recursive: true);
    }
    return revDir;
  }

  static Future<Directory> getDraftsDirectory() async {
    final base = await getAppBaseDirectory();
    final draftsDir = Directory(p.join(base.path, AppConstants.draftsFolder));
    if (!await draftsDir.exists()) {
      await draftsDir.create(recursive: true);
    }
    return draftsDir;
  }

  static Future<Directory> getModelsDirectory() async {
    final base = await getAppBaseDirectory();
    final modelsDir = Directory(p.join(base.path, AppConstants.modelsFolder));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Writes content to a file atomically by saving to a temp file first, then renaming.
  static Future<File> writeAtomically(String targetFilePath, String content) async {
    final targetFile = File(targetFilePath);
    final parentDir = targetFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final tempFilePath = '$targetFilePath.tmp_${DateTime.now().millisecondsSinceEpoch}';
    final tempFile = File(tempFilePath);
    await tempFile.writeAsString(content, flush: true);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    return await tempFile.rename(targetFilePath);
  }

  /// Sanitizes string for safe filesystem usage
  static String sanitizeFileName(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    var clean = name.replaceAll(invalidChars, '_').trim();
    if (clean.isEmpty) {
      clean = 'Untitled Document';
    }
    return clean;
  }

  /// Formats byte size into human readable string (KB, MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
