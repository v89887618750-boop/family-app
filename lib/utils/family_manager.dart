import 'package:shared_preferences/shared_preferences.dart';

class FamilyManager {
  static const String _keyFamilyId = 'current_family_id';

  // Получить ID текущей семьи (если нет, создать дефолтную)
  static Future<String> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyFamilyId);
    
    if (id == null) {
      // Если семья не создана, создаем случайный ID
      id = 'FAMILY-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      await prefs.setString(_keyFamilyId, id);
    }
    return id;
  }

  // Сменить семью (при вводе кода)
  static Future<void> setFamilyId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFamilyId, id);
  }
}
