import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Genera i recorda un identificador únic per a AQUEST dispositiu com a
/// jugador. Sobreviu a tancar l'app i a reiniciar el mòbil (es guarda amb
/// `shared_preferences`), però no sobreviu a reinstal·lar l'app ni, per
/// descomptat, a fer servir un altre mòbil.
///
/// És la peça clau de la reconnexió automàtica: si el `deviceId` coincideix
/// amb un jugador ja existent d'una sessió, el màster el reconeix sense fer
/// falta cap acció manual.
class DeviceIdentity {
  static const _prefsKey = 'navidad_jordi_device_id';
  static const _uuid = Uuid();

  static String? _cached;

  static Future<String> getOrCreate() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }
}
