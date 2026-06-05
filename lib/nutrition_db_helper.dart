import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class FoodNutritionResult {
  final String foodName;
  final double grams;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final bool isEstimate;
  final double confidence; // 1.0 = exact match, 0.8 = partial, 0.5 = fallback

  FoodNutritionResult({
    required this.foodName,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    this.isEstimate = false,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toMap() => {
        'name': foodName,
        'grams': grams,
        'cal': calories,
        'pro': protein,
        'carb': carbs,
        'fat': fats,
        'fib': fiber,
        'isEstimate': isEstimate,
        'confidence': confidence,
      };
}

class NutritionDB {
  static Database? _db;

  static Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = p.join(await getDatabasesPath(), 'nutrition.db');
    final exists = await databaseExists(dbPath);
    if (!exists) {
      try {
        final data = await rootBundle.load('assets/nutrition.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await Directory(p.dirname(dbPath)).create(recursive: true);
        await File(dbPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        // Safe to ignore, fallback to programmatic creation
      }
    }
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS foods (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            name_lower TEXT NOT NULL,
            calories INTEGER NOT NULL,
            protein REAL NOT NULL,
            carbs REAL NOT NULL,
            fats REAL NOT NULL,
            fiber REAL NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_name_lower ON foods(name_lower)');
      },
    );
    return _db!;
  }

  static Future<void> initialize() async {
    final db = await _getDb();
    final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM foods'));
    if (c == null || c == 0) {
      await _seedDatabase(db);
    }
  }

  static Future<FoodNutritionResult?> lookup(String foodName, double grams) async {
    final db = await _getDb();
    final q = foodName.toLowerCase().trim();

    // 1. Try exact match
    var rows = await db.query('foods', where: 'name_lower = ?', whereArgs: [q], limit: 1);
    if (rows.isNotEmpty) {
      final r = rows.first;
      final scale = grams / 100.0;
      return FoodNutritionResult(
        foodName: r['name'] as String,
        grams: grams,
        calories: ((r['calories'] as int) * scale).round(),
        protein: double.parse(((r['protein'] as num) * scale).toStringAsFixed(1)),
        carbs: double.parse(((r['carbs'] as num) * scale).toStringAsFixed(1)),
        fats: double.parse(((r['fats'] as num) * scale).toStringAsFixed(1)),
        fiber: double.parse(((r['fiber'] as num) * scale).toStringAsFixed(1)),
        confidence: 1.0,
        isEstimate: false,
      );
    }

    // 2. Try partial match with LIKE
    rows = await db.query('foods', where: 'name_lower LIKE ?', whereArgs: ['%$q%'], limit: 5);
    if (rows.isNotEmpty) {
      final list = List<Map<String, dynamic>>.from(rows);
      list.sort((a, b) => (a['name_lower'] as String).length.compareTo((b['name_lower'] as String).length));
      final r = list.first;
      final scale = grams / 100.0;
      return FoodNutritionResult(
        foodName: r['name'] as String,
        grams: grams,
        calories: ((r['calories'] as int) * scale).round(),
        protein: double.parse(((r['protein'] as num) * scale).toStringAsFixed(1)),
        carbs: double.parse(((r['carbs'] as num) * scale).toStringAsFixed(1)),
        fats: double.parse(((r['fats'] as num) * scale).toStringAsFixed(1)),
        fiber: double.parse(((r['fiber'] as num) * scale).toStringAsFixed(1)),
        confidence: 0.8,
        isEstimate: false,
      );
    }

    // 3. Try word-by-word search
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isNotEmpty) {
      final Map<Map<String, dynamic>, int> matchCounts = {};
      final List<Map<String, dynamic>> allMatches = [];
      for (final w in words) {
        final matches = await db.query('foods', where: 'name_lower LIKE ?', whereArgs: ['%$w%'], limit: 10);
        for (final m in matches) {
          final existing = allMatches.firstWhere((element) => element['id'] == m['id'], orElse: () => const {});
          if (existing.isEmpty) {
            allMatches.add(m);
            matchCounts[m] = 1;
          } else {
            matchCounts[existing] = (matchCounts[existing] ?? 0) + 1;
          }
        }
      }
      if (allMatches.isNotEmpty) {
        allMatches.sort((a, b) {
          final countA = matchCounts[a] ?? 0;
          final countB = matchCounts[b] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          return (a['name_lower'] as String).length.compareTo((b['name_lower'] as String).length);
        });
        final r = allMatches.first;
        final scale = grams / 100.0;
        return FoodNutritionResult(
          foodName: r['name'] as String,
          grams: grams,
          calories: ((r['calories'] as int) * scale).round(),
          protein: double.parse(((r['protein'] as num) * scale).toStringAsFixed(1)),
          carbs: double.parse(((r['carbs'] as num) * scale).toStringAsFixed(1)),
          fats: double.parse(((r['fats'] as num) * scale).toStringAsFixed(1)),
          fiber: double.parse(((r['fiber'] as num) * scale).toStringAsFixed(1)),
          confidence: 0.8,
          isEstimate: false,
        );
      }
    }

    return null;
  }

  static FoodNutritionResult getFallbackEstimate(String foodName, double grams) {
    final n = foodName.toLowerCase();
    int cal = 150;
    double pro = 5, carb = 20, fat = 5, fib = 2;

    if (n.contains('rice') || n.contains('biryani')) {
      cal = 130; pro = 3; carb = 28; fat = 1; fib = 0.5;
    } else if (n.contains('chicken') || n.contains('murgh')) {
      cal = 180; pro = 25; carb = 2; fat = 8; fib = 0;
    } else if (n.contains('dal') || n.contains('lentil')) {
      cal = 120; pro = 8; carb = 20; fat = 1; fib = 5;
    } else if (n.contains('roti') || n.contains('chapati') || n.contains('naan')) {
      cal = 300; pro = 9; carb = 55; fat = 5; fib = 3;
    } else if (n.contains('paneer') || n.contains('cheese')) {
      cal = 265; pro = 18; carb = 3; fat = 20; fib = 0;
    } else if (n.contains('egg')) {
      cal = 155; pro = 13; carb = 1; fat = 11; fib = 0;
    } else if (n.contains('fish') || n.contains('prawn') || n.contains('shrimp')) {
      cal = 120; pro = 20; carb = 0; fat = 4; fib = 0;
    } else if (n.contains('fruit') || n.contains('mango') || n.contains('banana') || n.contains('apple')) {
      cal = 60; pro = 1; carb = 15; fat = 0.3; fib = 2;
    } else if (n.contains('salad') || n.contains('vegetable')) {
      cal = 40; pro = 2; carb = 8; fat = 1; fib = 3;
    } else if (n.contains('bread') || n.contains('toast')) {
      cal = 265; pro = 9; carb = 49; fat = 3; fib = 3;
    } else if (n.contains('milk') || n.contains('lassi')) {
      cal = 60; pro = 3; carb = 5; fat = 3; fib = 0;
    } else if (n.contains('sweet') || n.contains('dessert') || n.contains('halwa') || n.contains('cake')) {
      cal = 350; pro = 4; carb = 55; fat = 13; fib = 1;
    } else if (n.contains('curry') || n.contains('masala') || n.contains('sabzi')) {
      cal = 130; pro = 8; carb = 10; fat = 7; fib = 2;
    }

    final s = grams / 100.0;
    return FoodNutritionResult(
      foodName: foodName,
      grams: grams,
      calories: (cal * s).round(),
      protein: double.parse((pro * s).toStringAsFixed(1)),
      carbs: double.parse((carb * s).toStringAsFixed(1)),
      fats: double.parse((fat * s).toStringAsFixed(1)),
      fiber: double.parse((fib * s).toStringAsFixed(1)),
      isEstimate: true,
      confidence: 0.5,
    );
  }

  static Future<List<String>> searchSuggestions(String query, {int limit = 5}) async {
    final db = await _getDb();
    final rows = await db.query(
      'foods',
      columns: ['name'],
      where: 'name_lower LIKE ?',
      whereArgs: ['%${query.toLowerCase().trim()}%'],
      limit: limit,
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<void> _seedDatabase(Database db) async {
    const List<String> foods = [
      // Indian Staples & Grains
      'white rice cooked|130|2.7|28.2|0.3|0.4',
      'brown rice cooked|111|2.6|23.0|0.9|1.8',
      'basmati rice cooked|121|3.5|25.2|0.4|0.4',
      'red rice cooked|111|2.7|23.5|0.9|2.0',
      'parboiled rice cooked|130|2.7|28.2|0.3|0.4',
      'rice flakes poha|180|3.0|36.0|3.0|1.0',
      'puffed rice murmura|402|6.3|87.0|0.5|1.0',
      'wheat flour atta|341|13.0|70.0|1.7|11.2',
      'maida refined flour|348|9.0|73.0|1.0|2.0',
      'semolina sooji|360|11.0|73.0|1.0|3.9',
      'corn flour|361|6.9|79.0|0.5|2.4',
      'ragi finger millet|336|7.0|72.0|1.5|3.6',
      'jowar sorghum|329|10.4|67.0|1.7|6.3',
      'bajra pearl millet|361|11.0|67.0|5.0|1.2',
      'oats|389|17.0|66.0|7.0|10.6',
      'quinoa cooked|120|4.4|21.0|1.9|2.8',
      'barley cooked|123|2.3|28.0|0.4|6.0',
      'corn maize cooked|86|3.3|19.0|1.4|2.7',
      'popcorn plain|375|11.0|74.0|4.5|14.5',

      // Indian Breads
      'roti wheat chapati|297|9.0|60.0|3.0|3.5',
      'paratha plain|326|7.0|48.0|12.0|2.0',
      'paratha stuffed aloo|218|4.5|32.0|8.0|2.2',
      'naan|310|9.0|51.0|7.0|2.0',
      'puri|340|7.0|44.0|16.0|2.0',
      'bhatura|330|8.0|47.0|13.0|2.0',
      'idli|58|2.0|11.0|0.5|0.5',
      'dosa plain|168|4.0|30.0|3.7|1.5',
      'dosa masala|150|3.5|27.0|3.5|1.8',
      'uttapam|140|4.5|22.0|4.0|1.5',
      'appam|160|3.5|32.0|2.0|1.0',
      'vada medu|260|8.0|22.0|14.0|2.5',
      'dhokla|160|5.0|25.0|5.0|1.5',
      'thepla|280|8.0|40.0|10.0|4.0',
      'missi roti|280|11.0|45.0|6.0|5.0',

      // Indian Dal & Legumes cooked
      'dal toor arhar cooked|116|7.0|20.0|0.5|4.0',
      'dal moong cooked|105|7.0|19.0|0.4|7.6',
      'dal masoor red lentil cooked|116|9.0|20.0|0.4|7.9',
      'dal chana bengal gram cooked|164|8.9|27.0|2.6|7.6',
      'dal urad black gram cooked|105|7.0|18.0|0.4|3.3',
      'rajma kidney beans cooked|127|8.7|22.8|0.5|6.4',
      'chole chickpeas cooked|164|8.9|27.0|2.6|7.6',
      'moong sprouts raw|30|3.0|4.0|0.2|1.8',
      'black eyed peas cooked|116|7.8|21.0|0.5|6.6',
      'moth beans cooked|114|8.0|20.0|0.5|5.5',
      'soybean cooked|173|17.0|10.0|9.0|6.0',
      'lobia cowpeas cooked|116|7.7|21.0|0.5|6.5',
      'dal fry|130|7.0|18.0|4.0|4.0',
      'dal makhani|150|8.5|18.0|5.5|5.0',
      'sambhar|55|3.0|8.0|1.5|2.5',

      // Indian Curries & Dishes
      'chicken curry|150|14.0|5.0|9.0|0.5',
      'chicken tikka masala|180|18.0|6.0|10.0|1.0',
      'butter chicken|200|16.0|7.0|13.0|0.8',
      'chicken biryani|200|10.0|25.0|7.0|1.0',
      'mutton curry|190|18.0|4.0|12.0|0.5',
      'mutton biryani|220|12.0|25.0|9.0|1.0',
      'fish curry|140|15.0|5.0|7.0|0.5',
      'prawn masala|150|16.0|5.0|8.0|0.5',
      'paneer butter masala|210|9.0|8.0|16.0|1.0',
      'palak paneer|180|9.0|7.0|13.0|2.5',
      'shahi paneer|240|10.0|9.0|19.0|0.8',
      'paneer tikka|230|14.0|6.0|16.0|1.0',
      'aloo gobi|95|3.0|14.0|3.5|3.0',
      'aloo matar|110|3.5|17.0|3.5|3.0',
      'baingan bharta|80|2.5|9.0|4.0|3.5',
      'bhindi masala|70|2.0|8.0|3.5|3.5',
      'mixed veg curry|85|2.5|11.0|3.5|3.0',
      'egg curry|150|10.0|4.0|11.0|0.5',
      'egg bhurji|190|12.0|3.0|14.0|0.5',
      'keema matar|220|18.0|7.0|14.0|2.0',
      'matar paneer|165|8.0|12.0|10.0|3.5',
      'korma chicken|220|15.0|8.0|15.0|0.8',
      'vindaloo|180|16.0|5.0|11.0|0.8',
      'kadhai chicken|170|16.0|6.0|10.0|1.0',
      'rajma chawal|145|7.0|24.0|2.5|5.0',
      'chole bhature|310|9.0|40.0|13.0|5.0',

      // Indian Snacks & Street Food
      'samosa|308|6.0|32.0|17.0|2.5',
      'kachori|380|7.0|42.0|20.0|3.0',
      'pakora vegetable|280|7.0|28.0|16.0|2.5',
      'pakora onion|260|6.0|30.0|13.0|2.0',
      'vada pav|280|7.0|42.0|10.0|2.5',
      'pav bhaji|180|5.0|27.0|6.0|3.0',
      'bhel puri|180|4.0|35.0|4.5|2.5',
      'pani puri golgappa|210|5.0|38.0|5.0|2.5',
      'sev puri|240|5.0|38.0|8.0|2.5',
      'dahi puri|220|7.0|36.0|6.0|2.0',
      'aloo tikki|250|4.5|36.0|10.0|3.0',
      'ragda patties|220|7.0|32.0|7.0|4.0',
      'upma|110|3.0|19.0|3.0|1.5',
      'pongal|130|3.5|22.0|4.0|1.0',
      'khichdi|130|5.0|23.0|2.5|2.5',
      'poha|180|3.0|36.0|3.0|1.0',
      'halwa sooji|320|4.0|52.0|11.0|1.0',
      'jalebi|360|2.0|65.0|10.0|0.5',
      'gulab jamun|385|5.0|65.0|13.0|0.5',
      'rasgulla|186|3.5|42.0|0.2|0.2',
      'kheer|150|4.0|25.0|4.5|0.2',
      'payasam|160|4.5|28.0|4.5|0.5',
      'ladoo besan|450|8.0|58.0|20.0|2.5',
      'barfi milk|380|8.0|58.0|14.0|0.5',
      'peda|390|6.5|65.0|12.0|0.3',
      'halwa gajar|200|3.0|32.0|7.0|2.5',
      'kulfi|200|5.5|27.0|9.0|0.2',
      'chai tea with milk sugar|45|1.5|7.0|1.5|0.0',
      'lassi sweet|100|3.5|15.0|3.0|0.0',
      'chaas buttermilk|30|1.5|3.0|0.5|0.0',

      // Vegetables
      'potato|77|2.0|17.0|0.1|2.2',
      'potato boiled|87|1.9|20.0|0.1|1.8',
      'sweet potato boiled|86|1.6|20.0|0.1|3.0',
      'onion|40|1.1|9.3|0.1|1.7',
      'tomato|18|0.9|3.9|0.2|1.2',
      'carrot|41|0.9|9.6|0.2|2.8',
      'spinach palak|23|2.9|3.6|0.4|2.2',
      'methi fenugreek leaves|49|4.4|6.0|0.9|2.7',
      'broccoli|34|2.8|7.0|0.4|2.6',
      'cauliflower gobi|25|1.9|5.0|0.3|2.0',
      'cabbage|25|1.3|5.8|0.1|2.5',
      'capsicum green|20|0.9|4.6|0.2|1.7',
      'capsicum red|31|1.0|6.0|0.3|2.1',
      'eggplant baingan|25|1.0|5.9|0.2|3.0',
      'pumpkin|26|1.0|6.5|0.1|0.5',
      'bottle gourd lauki|14|0.6|3.4|0.0|0.5',
      'bitter gourd karela|17|1.0|3.7|0.2|2.8',
      'ridge gourd turai|17|0.9|3.5|0.1|0.5',
      'lady finger bhindi|33|1.9|7.5|0.2|3.2',
      'peas green|81|5.4|14.5|0.4|5.7',
      'corn cob|86|3.3|19.0|1.4|2.7',
      'mushroom|22|3.1|3.3|0.3|1.0',
      'beetroot|43|1.6|9.6|0.2|2.8',
      'radish mooli|16|0.7|3.4|0.1|1.6',
      'cucumber|15|0.7|3.6|0.1|0.5',
      'zucchini|17|1.2|3.1|0.3|1.0',
      'brinjal|25|1.0|5.9|0.2|3.0',
      'drumstick sahjan|37|2.1|8.5|0.2|3.2',
      'raw banana|109|1.4|25.0|0.3|2.6',
      'jackfruit raw|95|1.7|23.0|0.6|1.5',
      'lotus stem kamal kakdi|74|2.7|17.0|0.1|4.9',
      'taro arbi cooked|112|1.5|26.0|0.2|4.3',
      'yam suran cooked|118|1.5|27.0|0.2|4.1',

      // Fruits
      'banana|89|1.1|23.0|0.3|2.6',
      'apple|52|0.3|14.0|0.2|2.4',
      'mango|60|0.8|15.0|0.4|1.6',
      'orange|47|0.9|12.0|0.1|2.4',
      'watermelon|30|0.6|7.6|0.2|0.4',
      'grapes|69|0.7|18.0|0.2|0.9',
      'pineapple|50|0.5|13.0|0.1|1.4',
      'papaya|43|0.5|11.0|0.3|1.7',
      'guava amrood|68|2.6|14.0|1.0|5.4',
      'pomegranate|83|1.7|19.0|1.2|4.0',
      'lychee|66|0.8|17.0|0.4|1.3',
      'chikoo sapota|83|0.4|20.0|1.1|5.3',
      'strawberry|32|0.7|7.7|0.3|2.0',
      'kiwi|61|1.1|15.0|0.5|3.0',
      'pear|57|0.4|15.0|0.1|3.1',
      'peach|39|0.9|10.0|0.3|1.5',
      'plum|46|0.7|11.0|0.3|1.4',
      'cherry|50|1.0|12.0|0.3|1.6',
      'coconut fresh|354|3.3|15.0|33.0|9.0',
      'avocado|160|2.0|9.0|15.0|6.7',
      'dates fresh|282|2.5|75.0|0.4|8.0',
      'fig anjeer|74|0.8|19.0|0.3|2.9',
      'jackfruit ripe|95|1.7|23.0|0.6|1.5',
      'custard apple sitaphal|101|1.7|25.0|0.6|2.4',
      'amla gooseberry|44|0.9|10.0|0.6|3.4',
      'jamun|60|0.7|14.0|0.2|0.9',

      // Meat Poultry Seafood cooked
      'chicken breast grilled|165|31.0|0.0|3.6|0.0',
      'chicken thigh cooked|209|26.0|0.0|11.0|0.0',
      'chicken leg cooked|184|24.0|0.0|9.6|0.0',
      'chicken wings cooked|290|27.0|0.0|19.0|0.0',
      'chicken liver cooked|167|25.0|0.9|6.5|0.0',
      'mutton cooked|258|26.0|0.0|17.0|0.0',
      'lamb cooked|258|26.0|0.0|17.0|0.0',
      'beef cooked|250|26.0|0.0|15.0|0.0',
      'pork cooked|242|27.0|0.0|14.0|0.0',
      'bacon cooked|541|37.0|1.4|42.0|0.0',
      'sausage pork|296|12.0|2.4|27.0|0.0',
      'salami|336|18.0|2.0|29.0|0.0',
      'turkey breast cooked|135|30.0|0.0|1.0|0.0',
      'duck cooked|337|19.0|0.0|28.0|0.0',
      'egg whole boiled|155|13.0|1.1|11.0|0.0',
      'egg white boiled|52|11.0|0.7|0.2|0.0',
      'egg yolk|322|16.0|3.6|27.0|0.0',
      'egg scrambled|148|10.0|1.6|11.0|0.0',
      'salmon grilled|208|20.0|0.0|13.0|0.0',
      'tuna canned|116|26.0|0.0|1.0|0.0',
      'sardine canned|208|25.0|0.0|11.0|0.0',
      'mackerel bangda cooked|205|19.0|0.0|14.0|0.0',
      'rohu fish cooked|147|20.0|0.0|7.0|0.0',
      'catla fish cooked|113|19.0|0.0|4.0|0.0',
      'pomfret cooked|140|20.0|0.0|7.0|0.0',
      'prawn shrimp cooked|99|24.0|0.2|0.3|0.0',
      'crab cooked|97|19.0|0.0|2.0|0.0',
      'lobster cooked|98|21.0|1.3|0.6|0.0',
      'squid cooked|92|16.0|3.1|1.4|0.0',

      // Dairy
      'milk full fat|61|3.2|4.8|3.3|0.0',
      'milk toned|46|3.3|4.7|1.5|0.0',
      'milk skimmed|34|3.4|5.0|0.1|0.0',
      'curd yogurt full fat|61|3.5|4.7|3.3|0.0',
      'curd low fat|50|5.7|3.8|0.4|0.0',
      'greek yogurt|100|9.0|3.6|5.0|0.0',
      'paneer full fat|265|18.0|3.0|20.0|0.0',
      'paneer low fat|180|22.0|3.5|9.0|0.0',
      'cheese cheddar|402|25.0|1.3|33.0|0.0',
      'cheese mozzarella|280|28.0|2.2|17.0|0.0',
      'cheese processed|316|16.0|5.7|26.0|0.0',
      'cream|340|2.1|2.7|35.0|0.0',
      'butter|717|0.9|0.1|81.0|0.0',
      'ghee|900|0.0|0.0|100.0|0.0',
      'condensed milk|321|7.9|55.0|8.5|0.0',
      'khoa mawa|421|18.0|35.0|26.0|0.0',
      'ice cream vanilla|207|3.5|24.0|11.0|0.5',
      'ice cream chocolate|216|3.8|28.0|11.0|0.5',
      'whey protein powder|352|80.0|10.0|3.0|0.0',
      'casein protein powder|360|78.0|8.0|4.0|0.0',

      // Nuts Seeds Oils
      'almonds|579|21.0|22.0|50.0|12.5',
      'walnuts|654|15.0|14.0|65.0|6.7',
      'cashews|553|18.0|30.0|44.0|3.3',
      'peanuts|567|26.0|16.0|49.0|8.5',
      'peanut butter|588|25.0|20.0|50.0|6.0',
      'pistachios|562|20.0|28.0|45.0|10.6',
      'brazil nuts|656|14.0|12.0|66.0|7.5',
      'macadamia nuts|718|8.0|14.0|76.0|8.6',
      'pine nuts|673|14.0|13.0|68.0|3.7',
      'flaxseeds|534|18.0|29.0|42.0|27.3',
      'chia seeds|486|17.0|42.0|31.0|34.4',
      'sunflower seeds|584|21.0|20.0|51.0|8.6',
      'pumpkin seeds|559|30.0|11.0|49.0|6.0',
      'sesame seeds til|573|18.0|23.0|50.0|11.8',
      'hemp seeds|553|32.0|8.7|49.0|4.0',
      'olive oil|884|0.0|0.0|100.0|0.0',
      'coconut oil|862|0.0|0.0|100.0|0.0',
      'sunflower oil|884|0.0|0.0|100.0|0.0',
      'mustard oil|884|0.0|0.0|100.0|0.0',
      'groundnut oil|884|0.0|0.0|100.0|0.0',

      // International Foods & Fast Food
      'pizza margherita|266|11.0|33.0|10.0|2.3',
      'pizza pepperoni|290|13.0|32.0|13.0|2.0',
      'burger beef|295|17.0|24.0|14.0|1.2',
      'burger chicken|280|15.0|30.0|10.0|1.5',
      'burger veg|240|8.0|33.0|9.0|2.5',
      'hot dog|290|11.0|22.0|18.0|0.8',
      'french fries|312|3.4|41.0|15.0|3.8',
      'fried chicken kfc style|320|22.0|16.0|19.0|0.8',
      'sandwich chicken|220|18.0|22.0|7.0|2.0',
      'sandwich veg|210|7.0|30.0|7.0|2.5',
      'wrap chicken|250|17.0|28.0|8.0|2.0',
      'pasta cooked|158|5.8|31.0|0.9|1.8',
      'pasta with sauce|180|7.0|28.0|5.0|2.5',
      'spaghetti bolognese|180|9.0|22.0|6.0|2.0',
      'mac and cheese|170|7.0|20.0|7.0|1.0',
      'noodles cooked|138|4.5|25.0|2.7|1.5',
      'fried rice egg|180|5.0|28.0|6.0|1.0',
      'hakka noodles|185|5.5|30.0|5.5|1.5',
      'manchurian veg|150|4.0|20.0|6.0|2.0',
      'spring roll|220|5.5|28.0|10.0|2.0',
      'dim sum|180|8.0|22.0|6.0|1.5',
      'sushi rice|150|5.0|28.0|2.0|0.5',
      'tacos|210|9.0|22.0|10.0|3.0',
      'nachos|480|8.0|60.0|24.0|4.0',
      'shawarma chicken|280|18.0|25.0|11.0|2.0',
      'falafel|333|13.0|32.0|18.0|10.0',
      'hummus|166|8.0|14.0|10.0|6.0',
      'doner kebab|200|15.0|18.0|8.0|1.5',
      'soup vegetable|45|2.0|8.0|1.0|1.5',
      'soup chicken|50|4.0|4.0|1.5|0.5',
      'soup tomato|40|1.5|8.0|0.5|1.0',

      // Breakfast Foods
      'bread white|265|9.0|49.0|3.2|2.7',
      'bread brown whole wheat|247|9.0|47.0|3.0|4.0',
      'bread multigrain|265|10.0|47.0|4.0|5.0',
      'cornflakes|357|7.0|84.0|0.4|1.2',
      'muesli|367|10.0|66.0|8.0|7.5',
      'granola|471|10.0|64.0|20.0|5.0',
      'oatmeal porridge|71|2.5|12.0|1.5|1.7',
      'pancake|227|6.0|28.0|10.0|1.5',
      'waffle|291|8.0|37.0|13.0|1.5',
      'french toast|230|7.0|27.0|11.0|1.5',
      'doughnut|452|5.0|51.0|25.0|1.5',
      'croissant|406|9.0|46.0|21.0|2.0',
      'muffin blueberry|377|5.5|55.0|15.0|2.0',
      'toast butter|280|7.0|37.0|13.0|2.0',
      'peanut butter toast|340|13.0|35.0|18.0|3.5',
      'avocado toast|175|5.0|18.0|9.5|4.5',
      'smoothie banana|95|1.5|22.0|0.5|1.5',
      'smoothie berry|80|1.5|18.0|0.5|2.0',
      'protein shake|120|24.0|5.0|1.5|1.0',

      // Beverages
      'orange juice|45|0.7|10.0|0.2|0.2',
      'apple juice|46|0.1|11.0|0.1|0.2',
      'mango juice|60|0.4|15.0|0.1|0.3',
      'coconut water|19|0.7|3.7|0.2|1.1',
      'whole milk|61|3.2|4.8|3.3|0.0',
      'coffee black|2|0.3|0.0|0.0|0.0',
      'coffee with milk|30|1.5|3.5|1.0|0.0',
      'coffee latte|60|3.5|6.0|2.5|0.0',
      'cappuccino|60|3.5|6.0|2.5|0.0',
      'green tea|2|0.5|0.0|0.0|0.0',
      'black tea|2|0.0|0.5|0.0|0.0',
      'chai masala tea|50|2.0|7.5|1.5|0.0',
      'coca cola|41|0.0|10.6|0.0|0.0',
      'pepsi|40|0.0|10.6|0.0|0.0',
      'sprite|40|0.0|10.6|0.0|0.0',
      'energy drink redbull|45|0.3|11.0|0.0|0.0',
      'beer|43|0.5|3.6|0.0|0.0',
      'wine red|85|0.1|2.6|0.0|0.0',
      'wine white|82|0.1|2.6|0.0|0.0',
      'alcohol whiskey|250|0.0|0.0|0.0|0.0',
      'protein shake chocolate|130|24.0|8.0|2.5|1.0',
      'buttermilk chaas|30|1.5|3.0|0.5|0.0',
      'rose milk|95|2.5|17.0|2.0|0.0',

      // Sweets Snacks Processed
      'chocolate dark 70|546|5.0|60.0|31.0|7.0',
      'chocolate milk|535|7.6|59.0|30.0|3.4',
      'chocolate bar kit kat|518|7.5|62.0|26.0|1.5',
      'biscuit marie|401|7.0|70.0|10.0|2.0',
      'biscuit oreo|471|5.0|65.0|21.0|2.5',
      'biscuit cream|490|6.5|62.0|25.0|2.0',
      'cake chocolate|352|5.0|50.0|15.0|1.5',
      'cake vanilla|347|5.0|52.0|14.0|1.0',
      'brownie|429|5.0|63.0|18.0|2.5',
      'cookie chocolate chip|502|6.0|63.0|25.0|3.0',
      'chips lays|536|7.0|53.0|35.0|4.8',
      'chips doritos|490|7.0|56.0|26.0|4.0',
      'popcorn buttered|450|6.0|53.0|24.0|10.0',
      'pringles|536|6.0|56.0|34.0|4.0',
      'maggi noodles cooked|165|5.0|24.0|6.0|1.0',
      'instant noodles cooked|138|3.5|22.0|4.5|1.0',
      'bread pakora|240|6.0|30.0|11.0|2.0',
      'chakli|470|8.0|58.0|23.0|4.0',
      'namkeen mixture|490|10.0|55.0|26.0|5.0',
      'peanut chikki|490|14.0|55.0|24.0|4.0',
      'til chikki|510|12.0|55.0|28.0|6.0',
      'murukku|510|8.0|60.0|26.0|4.0',
      'mathri|480|8.0|58.0|24.0|3.0',
      'khakhra|390|11.0|64.0|10.0|6.0',
      'sev|547|18.0|49.0|32.0|5.0',

      // Health & Fitness Foods
      'whey protein shake made|120|24.0|5.0|1.5|0.0',
      'mass gainer shake made|400|30.0|60.0|5.0|2.0',
      'protein bar|350|20.0|40.0|12.0|5.0',
      'granola bar|393|7.0|64.0|13.0|4.0',
      'energy bar|380|10.0|60.0|12.0|3.0',
      'oat bar|380|9.0|58.0|14.0|5.0',
      'peanut butter|588|25.0|20.0|50.0|6.0',
      'almond butter|614|21.0|19.0|56.0|12.0',
      'greek yogurt plain|100|9.0|3.6|5.0|0.0',
      'cottage cheese paneer low fat|80|12.0|3.0|2.0|0.0',
      'rice cakes|392|8.0|80.0|3.0|3.0',
      'quinoa|120|4.4|21.0|1.9|2.8',
      'edamame boiled|121|11.0|8.9|5.2|5.2',
      'tofu firm|76|8.0|1.9|4.8|0.3',
      'tempeh|193|19.0|9.4|11.0|0.0',
      'lentil pasta cooked|130|9.0|20.0|1.0|4.5',
      'chickpea pasta cooked|180|11.0|28.0|3.5|8.0',

      // Sauces Condiments
      'tomato ketchup|97|0.9|24.0|0.1|0.5',
      'mayonnaise|680|1.0|0.6|75.0|0.0',
      'mustard|60|3.7|5.8|3.3|3.2',
      'soy sauce|53|8.1|4.9|0.1|0.8',
      'hot sauce|11|0.5|1.5|0.6|1.5',
      'chutney mint|50|2.0|8.0|1.0|2.0',
      'chutney tamarind imli|230|1.0|60.0|0.3|3.5',
      'pickle achar|110|1.0|10.0|7.0|3.0',
      'salad dressing caesar|350|2.0|4.0|36.0|0.0',
      'salad dressing olive oil|360|0.0|1.0|40.0|0.0',
      'vinegar|18|0.0|0.6|0.0|0.0',
      'sugar|387|0.0|100.0|0.0|0.0',
      'jaggery gud|383|0.4|98.0|0.1|0.0',
      'honey|304|0.3|82.0|0.0|0.2',
      'jam|250|0.5|65.0|0.1|1.0',
    ];

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in foods) {
        final parts = entry.split('|');
        if (parts.length != 6) continue;
        batch.insert('foods', {
          'name': parts[0],
          'name_lower': parts[0].toLowerCase(),
          'calories': int.parse(parts[1]),
          'protein': double.parse(parts[2]),
          'carbs': double.parse(parts[3]),
          'fats': double.parse(parts[4]),
          'fiber': double.parse(parts[5]),
        });
      }
      await batch.commit(noResult: true);
    });
  }
}