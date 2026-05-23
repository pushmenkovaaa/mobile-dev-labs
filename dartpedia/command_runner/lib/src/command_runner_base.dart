import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'arguments.dart';
import 'exceptions.dart';

class CommandRunner {
  CommandRunner({this.onOutput, this.onError});

  final Map<String, Command> _commands = <String, Command>{};

  UnmodifiableSetView<Command> get commands =>
      UnmodifiableSetView<Command>(<Command>{..._commands.values});

  /// If not null, this method is used to handle output.
  /// Useful if you want to execute code before the output is printed
  /// to the console, or if you want to do something other than print.
  /// If null, the output will be printed to the console.
  FutureOr<void> Function(String)? onOutput;

  /// If not null, this method is used to handle errors.
  /// If null, exceptions will be rethrown.
  FutureOr<void> Function(Object)? onError;

  Future<void> run(List<String> input) async {
    try {
      final ArgResults results = parse(input);
      if (results.command != null) {
        Object? output = await results.command!.run(results);
        if (onOutput != null) {
          await onOutput!(output.toString());
        } else {
          print(output.toString());
        }
      }
    } on Exception catch (exception) {
      if (onError != null) {
        onError!(exception);
      } else {
        rethrow;
      }
    }
  }

  void addCommand(Command command) {
    _commands[command.name] = command;
    command.runner = this;
  }

  ArgResults parse(List<String> input) {
    ArgResults results = ArgResults();
    if (input.isEmpty) return results;

    // Проверка: первая команда должна быть известна
    if (_commands.containsKey(input.first)) {
      results.command = _commands[input.first];
      input = input.sublist(1);
    } else {
      throw ArgumentException(
        'The first word of input must be a command.',
        null,
        input.first,
      );
    }

    // Проверка: нельзя указать две команды подряд
    if (results.command != null &&
        input.isNotEmpty &&
        _commands.containsKey(input.first)) {
      throw ArgumentException(
        'Input can only contain one command. Got ${input.first} and ${results.command!.name}',
        null,
        input.first,
      );
    }

    // Обработка опций и флагов
    Map<Option, Object?> inputOptions = {};
    int i = 0;
    while (i < input.length) {
      if (input[i].startsWith('-')) {
        var base = _removeDash(input[i]);
        
        // Проверка: опция должна быть известна
        var option = results.command!.options.firstWhere(
          (option) => option.name == base || option.abbr == base,
          orElse: () {
            throw ArgumentException(
              'Unknown option ${input[i]}',
              results.command!.name,
              input[i],
            );
          },
        );

        if (option.type == OptionType.flag) {
          inputOptions[option] = true;
          i++;
          continue;
        }

        if (option.type == OptionType.option) {
          // Проверка: у опции должно быть значение
          if (i + 1 >= input.length) {
            throw ArgumentException(
              'Option ${option.name} requires an argument',
              results.command!.name,
              option.name,
            );
          }
          // Проверка: значение не должно начинаться с "-"
          if (input[i + 1].startsWith('-')) {
            throw ArgumentException(
              'Option ${option.name} requires an argument, but got another option ${input[i + 1]}',
              results.command!.name,
              option.name,
            );
          }
          var arg = input[i + 1];
          inputOptions[option] = arg;
          i++;
        }
      } else {
        // Проверка: только один позиционный аргумент
        if (results.commandArg != null && results.commandArg!.isNotEmpty) {
          throw ArgumentException(
            'Commands can only have up to one argument.',
            results.command!.name,
            input[i],
          );
        }
        results.commandArg = input[i];
      }
      i++;
    }
    results.options = inputOptions;

    return results;
  }

  /// Helper method to remove leading dashes from option names.
  /// --foo → foo, -f → f
  String _removeDash(String input) {
    if (input.startsWith('--')) {
      return input.substring(2);
    }
    if (input.startsWith('-')) {
      return input.substring(1);
    }
    return input;
  }

  /// Returns usage string for the executable.
  String get usage {
    final exeFile = Platform.script.path.split('/').last;
    return 'Usage: dart bin/$exeFile <command> [commandArg?] [...options?]';
  }
}