// ignore_for_file: unnecessary_brace_in_string_interps, public_member_api_docs, avoid_print, lines_longer_than_80_chars, inference_failure_on_instance_creation, non_constant_identifier_names, sort_constructors_first, unawaited_futures, prefer_single_quotes, prefer_final_locals, omit_local_variable_types, avoid_redundant_argument_values, strict_raw_type, unnecessary_raw_strings, require_trailing_commas, directives_ordering, avoid_final_parameters

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math';
// import 'dart:math';
import 'package:http/http.dart';
import 'package:isar/isar.dart';
import 'package:isar_inspector/packages/get_package.dart';
import 'package:isar_inspector/packages/shell.dart';
import 'package:universal_io/io.dart';
import "package:path/path.dart" as path_pckg;

extension DirectoryHelperIsarInspector on Directory {
  /// Recursively copies a directory + subdirectories into a target directory.
  /// Similar to Copy-Item in PowerShell.
  void isarInspectorCopyTo(
    final Directory destination, {
    final List<String> ignoreDirList = const [],
    final List<String> ignoreFileList = const [],
  }) {
    listSync().forEach((final entity) {
      if (entity is Directory) {
        if (ignoreDirList.contains(path_pckg.basename(entity.path))) {
          return;
        }
        final newDirectory = Directory(
          path_pckg.join(destination.absolute.path, path_pckg.basename(entity.path)),
        )..createSync();
        entity.absolute.isarInspectorCopyTo(newDirectory);
      } else if (entity is File) {
        if (ignoreFileList.contains(path_pckg.basename(entity.path))) {
          return;
        }
        entity.copySync(
          path_pckg.join(destination.path, path_pckg.basename(entity.path)),
        );
      }
    });
  }
}

class IsarInspector {
  bool is_init = false;
  Uri? serviceUri;
  Directory? directory_lib;

  IsarInspector() {
    Future(() async {
      await init();
    });
  }

  Future<void> init() async {
    final info = await Service.getInfo();
    serviceUri = info.serverUri;

    directory_lib = await getPackageDirectory(
      package_name: 'package:isar_inspector/isar_inspector.dart',
    );
    is_init = true;
  }

  bool get isRelease => const bool.fromEnvironment('dart.vm.product');
  bool get isProfile => const bool.fromEnvironment('dart.vm.profile');

  Future<bool> get isDebug async {
    if (is_init) {
      return (serviceUri != null);
    }
    while (true) {
      await Future.delayed(const Duration(milliseconds: 1));
      if (is_init) {
        return serviceUri is Uri;
      }
    }
  }

  Future<void> run({
    Directory? directoryLib,
    int default_port = 9955,
    String web_renderer = "html",
  }) async {
    if (!(await isDebug)) {
      return;
    }
    if (serviceUri == null) {
      return;
    }
    directoryLib ??= directory_lib;

    final port = serviceUri!.port;
    var path = serviceUri!.path;
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('=')) {
      path = path.substring(0, path.length - 1);
    }

    if (directoryLib != null) {
      Future(() async {
        int createRandomPort() {
          List<int> ports = List.generate(10, (index) => index).toList();
          List<int> port_results = List.generate(4, (index) => ports[Random().nextInt(ports.length)]);
          int port_result = int.parse(port_results.join(""));
          return port_result;
        }

        int random_port = default_port;

        Future<Process?> runProgram() async {
          Uri url_api = Uri.parse("http://localhost:${random_port}/manifest.json");

          while (true) {
            await Future.delayed(const Duration(milliseconds: 1));
            try {
              var res = await get(url_api);
              if (res.statusCode == 200) {
                try {
                  Map jsonData = json.decode(res.body) as Map;
                  if (jsonData["name"] is String && RegExp(r"isar", caseSensitive: false).hasMatch(jsonData["name"].toString()) && RegExp(r"inspector", caseSensitive: false).hasMatch(jsonData["name"].toString())) {
                    return null;
                  } else {
                    random_port = createRandomPort();
                  }
                } catch (e) {
                  random_port = createRandomPort();
                }
              } else {
                random_port = createRandomPort();
              }
            } catch (e) {
              // ClientException;
              if (e is ClientException) {
                // print("lp");
                break;
              } else {
                random_port = createRandomPort();
              }
            }
          }

          return shell(
            executable: "flutter",
            workingDirectory: directoryLib!.path,
            arguments: [
              "run",
              "--web-renderer",
              web_renderer,
              "--web-port",
              "${random_port}",
              "--release",
            ],
            runInShell: false,
            isFuture: true,
            onStdout: (data, executable, arguments, workingDirectory, environment, includeParentEnvironment, runInShell, mode) {
              String text = utf8.decode(data).trim();
              if (RegExp(r"to hot restart changes", caseSensitive: false).hasMatch(text) && RegExp(r'\"r\"', caseSensitive: false).hasMatch(text)) {
                // print("berhasil");
              }
            },
            onStderr: (data, executable, arguments, workingDirectory, environment, includeParentEnvironment, runInShell, mode) async {
              String text = utf8.decode(data).trim();
              if (RegExp(r"server", caseSensitive: false).hasMatch(text) && RegExp(r"socket", caseSensitive: false).hasMatch(text) && RegExp(r"Address already in use", caseSensitive: false).hasMatch(text)) {
                random_port = createRandomPort();
                await runProgram();
                // print("server already use");
              }

              if (RegExp(r"Cannot", caseSensitive: false).hasMatch(text) && RegExp(r"package", caseSensitive: false).hasMatch(text) && RegExp(r"cache", caseSensitive: false).hasMatch(text)) {
                // Cannot operate on packages inside the cache.
                //
                Directory directory_new = Directory(path_pckg.join(Directory.current.path, "dev", "isar_inspector"));
                if (!directory_new.existsSync()) {
                  await directory_new.create(recursive: true);
                }
                directory_lib!.isarInspectorCopyTo(directory_new, ignoreFileList: [
                  "build",
                  ".dart_tool",
                  ".git",
                ]);
                await run(
                  directoryLib: directory_new,
                  default_port: default_port,
                  web_renderer: web_renderer,
                );
              }
            },
            onComplete: (shell, executable, arguments, workingDirectory, environment, includeParentEnvironment, runInShell, mode) {
              shell.kill();
            },
          );
        }

        await runProgram();

        final url = ' https://inspect.isar.dev/${Isar.version}/#/$port$path ';
        final urlLocal = ' http://localhost:${random_port}/#/$port$path ';

        final urls = <String>[url, urlLocal];
        final lengthText = () {
          var length = 0;
          for (var i = 0; i < urls.length; i++) {
            final url = urls[i];
            if (url.length > length) {
              length = url.length;
            }
          }
          return length;
        }.call();
        String line(String text, String fill) {
          final fillCount = lengthText - text.length;
          final left = List.filled(fillCount ~/ 2, fill);
          final right = List.filled(fillCount - left.length, fill);
          return left.join() + text + right.join();
        }

        print('╔${line('', '═')}╗');
        print('║${line('ISAR CONNECT STARTED', ' ')}║');
        print('╟${line('', '─')}╢');
        print('║${line('Open the link to connect to the Isar', ' ')}║');
        print('║${line('Inspector while this build is running.', ' ')}║');
        print('╟${line('', '─')}╢');
        print('║${url}║');
        print('╟${line('', '─')}╢');
        print('║${urlLocal}║');
        print('╚${line('', '═')}╝');
      });
    }
  }
}
