import 'package:isar_inspector/isar_inspector.dart';

void main(List<String> arguments) async {
  IsarInspector inspector = IsarInspector();
  await inspector.run(default_port: 9194);
}
