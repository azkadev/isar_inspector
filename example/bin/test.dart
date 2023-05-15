import 'package:galaxeus_lib/galaxeus_lib.dart';

main() async {
  try {
    var res = await get(Uri.parse("http://localhost:7793/manifest.json"));
    print(res.statusCode);
    print(res.body);
  } catch (e) {
    // ClientException;
    if (e is ClientException) {
      print("lp");
    }
    print(e.runtimeType);
  }
}
