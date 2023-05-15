// ignore_for_file: public_member_api_docs, prefer_single_quotes, prefer_final_locals, omit_local_variable_types, non_constant_identifier_names, lines_longer_than_80_chars, directives_ordering

import 'dart:isolate';

import 'package:universal_io/io.dart';

import "package:path/path.dart" as path;

Future<Directory?> getPackageDirectory({
  String package_name = "package:glx/glx.dart",
}) async {
  Uri? res = await Isolate.resolvePackageUri(Uri.parse(package_name));
  if (res == null) {
    return null;
  }
  List<String> paths = [...res.pathSegments];
  for (var i = 0; i < package_name.split("/").length; i++) {
    paths.removeLast();
  }
  Directory directory = Directory(path.joinAll(paths));

  if (!directory.existsSync()) {
    directory = Directory(path.joinAll(["/", ...paths]));
  }
  return directory;
}
