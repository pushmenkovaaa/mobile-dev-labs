import 'dart:io';
import 'package:logging/logging.dart';

Logger initFileLogger(String name) {
  // Включаем иерархическое логирование
  hierarchicalLoggingEnabled = true;

  // Создаём логгер с именем
  final logger = Logger(name);
  final now = DateTime.now();

  // Получаем путь к проекту
  final scriptFile = File(Platform.script.toFilePath());
  final projectDir = scriptFile.parent.parent.path;

  // Создаём папку logs, если нет
  final dir = Directory('$projectDir/logs');
  if (!dir.existsSync()) dir.createSync();

  // Создаём файл лога с датой и именем
  final logFile = File(
    '${dir.path}/${now.year}_${now.month}_${now.day}_$name.txt',
  );

  // Уровень логирования: записывать всё
  logger.level = Level.ALL;

  // Слушаем записи и пишем в файл
  logger.onRecord.listen((record) {
    final msg =
        '[${record.time} - ${record.loggerName}] ${record.level.name}: ${record.message}';
    logFile.writeAsStringSync('$msg\n', mode: FileMode.append);
  });

  return logger;
}