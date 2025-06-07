import 'services/ingredient_intelligence_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'services/auth_service.dart';
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';
import 'blood_sugar_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic> profile = {};
  List<Recipe> favoriteRecipes = [];
  List<BloodSugarEntry> bloodSugarEntries = [];
  TextEditingController bioController = TextEditingController();
  TextEditingController carbsController = TextEditingController();
  TextEditingController sugarController = TextEditingController();
  TextEditingController exerciseController = TextEditingController();
  TextEditingController carbsInput = TextEditingController();
  TextEditingController sugarInput = TextEditingController();
  TextEditingController exerciseInput = TextEditingController();
  TextEditingController bloodSugarController = TextEditingController();
  TextEditingController noteController = TextEditingController();

  String? imageUrl;
  String? userEmail;
  Uint8List? pickedImageBytes;
  bool isEditingBio = false;
  bool showGoals = false;
  String selectedContext = 'Fasting';
  DateTime selectedDateTime = DateTime.now();

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late TabController _tabController;

  final String baseUrl = kIsWeb 
    ? 'http://127.0.0.1:5001' 
    : Platform.isIOS
        ? 'http://192.168.1.248:5001'
        : 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _tabController = TabController(length: 3, vsync: this);
    fetchProfile();
    loadSavedImage();
    loadFavoriteRecipes();
    loadBloodSugarEntries();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await AuthService().getToken();
    if (token != null) {
      // Decode JWT to get email (simplified - in production use proper JWT library)
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        userEmail = payload['sub'] ?? payload['email'];
      }
    }
    
    if (userEmail != null) {
      final savedPath = prefs.getString('profile_image_$userEmail');
      if (savedPath != null) {
        if (kIsWeb) {
          setState(() => imageUrl = savedPath);
        } else if (File(savedPath).existsSync()) {
          setState(() => imageUrl = savedPath);
        }
      }
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        await prefs.setString('profile_image_$userEmail', base64Image);
        setState(() {
          pickedImageBytes = bytes;
          imageUrl = base64Image;
        });
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${userEmail}_profile_${path.basename(pickedFile.path)}';
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
        await prefs.setString('profile_image_$userEmail', savedImage.path);
        setState(() => imageUrl = savedImage.path);
      }
    }
  }

  Future<void> loadFavoriteRecipes() async {
    final favorites = await RecipeUtils.getFavoriteRecipes();
    setState(() {
      favoriteRecipes = favorites;
    });
  }

  Future<void> loadBloodSugarEntries() async {
    final prefs = await SharedPreferences.getInstance();
    if (userEmail == null) {
      final token = await AuthService().getToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
          userEmail = payload['sub'] ?? payload['email'];
        }
      }
    }
    
    if (userEmail != null) {
      final entriesJson = prefs.getString('blood_sugar_$userEmail');
      if (entriesJson != null) {
        final List<dynamic> entriesList = json.decode(entriesJson);
        setState(() {
          bloodSugarEntries = entriesList.map((item) => BloodSugarEntry.fromJson(item)).toList();
          bloodSugarEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
      }
    }
  }

  Future<void> saveBloodSugarEntry() async {
    _dismissKeyboard();
    
    final value = int.tryParse(bloodSugarController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid blood sugar value"),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final entry = BloodSugarEntry(
      id: const Uuid().v4(),
      value: value,
      timestamp: selectedDateTime,
      context: selectedContext,
      note: noteController.text.isNotEmpty ? noteController.text : null,
    );

    bloodSugarEntries.insert(0, entry);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'blood_sugar_$userEmail',
      json.encode(bloodSugarEntries.map((e) => e.toJson()).toList()),
    );

    bloodSugarController.clear();
    noteController.clear();
    selectedDateTime = DateTime.now();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Blood sugar reading saved: $value mg/dL"),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Map<String, List<BloodSugarEntry>> getGroupedEntries() {
    final grouped = <String, List<BloodSugarEntry>>{};
    for (var entry in bloodSugarEntries) {
      final dateKey = DateFormat('MMM d, yyyy').format(entry.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(entry);
    }
    return grouped;
  }

  Map<String, double> getAveragesByContext() {
    final contextGroups = <String, List<int>>{};
    for (var entry in bloodSugarEntries) {
      contextGroups.putIfAbsent(entry.context, () => []).add(entry.value);
    }
    
    final averages = <String, double>{};
    contextGroups.forEach((context, values) {
      if (values.isNotEmpty) {
        averages[context] = values.reduce((a, b) => a + b) / values.length;
      }
    });
    return averages;
  }

  int getHighReadingsCount() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return bloodSugarEntries
        .where((e) => e.timestamp.isAfter(weekAgo) && e.value > 180)
        .length;
  }

  int getLowReadingsCount() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return bloodSugarEntries
        .where((e) => e.timestamp.isAfter(weekAgo) && e.value < 70)
        .length;
  }

  Future<void> fetchProfile() async {
    final token = await AuthService().getToken();
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        profile = data;
        bioController.text = data['bio'] ?? '';
        carbsController.text = data['goals']['carbs'].toString();
        sugarController.text = data['goals']['sugar'].toString();
        exerciseController.text = data['goals']['exercise'].toString();
      });
      _animationController.forward();
    }
  }

  Future<void> saveGoals() async {
    _dismissKeyboard();
    
    final token = await AuthService().getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/goals'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: json.encode({
        "carbs": int.parse(carbsController.text),
        "sugar": int.parse(sugarController.text),
        "exercise": int.parse(exerciseController.text),
      }),
    );
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Goals updated successfully!"),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      fetchProfile();
    }
  }

  Future<void> resetProgress() async {
    final token = await AuthService().getToken();
    final res = await http.post(Uri.parse('$baseUrl/progress/reset'), headers: {"Authorization": "Bearer $token"});
    if (res.statusCode == 200) {
      fetchProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Progress reset successfully!"),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> updateManual(String type, String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed == 0) return;
    
    // Dismiss keyboard first
    _dismissKeyboard();
    
    final token = await AuthService().getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/progress'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: json.encode({type: parsed}),
    );
    if (res.statusCode == 200) {
      // Clear the input field
      if (type == 'carbs') carbsInput.clear();
      else if (type == 'sugar') sugarInput.clear();
      else if (type == 'exercise') exerciseInput.clear();
      
      fetchProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added $parsed ${type == 'exercise' ? 'minutes' : 'g'} to $type!"),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> saveBio() async {
    _dismissKeyboard();
    
    final token = await AuthService().getToken();
    final success = await AuthService().updateProfile({'bio': bioController.text});
    if (success) {
      setState(() => isEditingBio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Bio updated!"),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget buildProgressCard(String label, int progress, int goal, Color color, TextEditingController input, String type, IconData icon) {
    double percent = (goal > 0) ? (progress / goal) : 0.0;
    double displayPercent = percent.clamp(0.0, 1.0);
    String unit = type == 'exercise' ? 'min' : 'g';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    // Wrap the left-side Row in Expanded to prevent overflow
    Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded( // Also wrap the Column to ensure its content doesn't overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "$progress / $goal $unit",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),

    // Right-side percentage (not in Expanded to preserve its size)
    Text(
      "${(percent * 100).toInt()}%",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: percent > 1.0 ? Colors.red : color,
      ),
    ),
  ],
),

          const SizedBox(height: 16),
          // Progress Bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: displayPercent * _progressAnimation.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Input Row with keyboard fixes
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 16),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      updateManual(type, value);
                    } else {
                      _dismissKeyboard();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "Add $unit",
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: color, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => updateManual(type, input.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Add",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Goals Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Daily Goals",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: resetProgress,
                icon: const Icon(Icons.refresh_rounded),
                color: Colors.orange,
                tooltip: 'Reset Daily Progress',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Track your daily nutrition and exercise",
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Progress Cards
          buildProgressCard(
            "Carbs",
            profile['progress']?['carbs'] ?? 0,
            profile['goals']?['carbs'] ?? 200,
            Colors.orange,
            carbsInput,
            'carbs',
            Icons.rice_bowl,
          ),
          const SizedBox(height: 16),
          buildProgressCard(
            "Sugar",
            profile['progress']?['sugar'] ?? 0,
            profile['goals']?['sugar'] ?? 50,
            Colors.purple,
            sugarInput,
            'sugar',
            Icons.water_drop,
          ),
          const SizedBox(height: 16),
          buildProgressCard(
            "Exercise",
            profile['progress']?['exercise'] ?? 0,
            profile['goals']?['exercise'] ?? 30,
            Colors.green,
            exerciseInput,
            'exercise',
            Icons.directions_run,
          ),

          const SizedBox(height: 32),

          // Update Goals Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  "Update Goals",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  "Customize your daily targets",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildGoalInput(
                          controller: carbsController,
                          label: "Daily Carbs Goal (g)",
                          icon: Icons.rice_bowl,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        _buildGoalInput(
                          controller: sugarController,
                          label: "Daily Sugar Goal (g)",
                          icon: Icons.water_drop,
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 16),
                        _buildGoalInput(
                          controller: exerciseController,
                          label: "Daily Exercise Goal (min)",
                          icon: Icons.directions_run,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: saveGoals,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Save Goals",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    if (favoriteRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No favorite recipes yet",
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Add recipes to favorites from the home screen",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: favoriteRecipes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final recipe = favoriteRecipes[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          ).then((_) => loadFavoriteRecipes()),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        recipe.image,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                          onPressed: () async {
                            // Remove from favorites
                            await RecipeUtils.toggleFavorite(recipe);
                            await loadFavoriteRecipes();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.rice_bowl, size: 16, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text("${recipe.carbs}g", style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          Icon(Icons.water_drop, size: 16, color: Colors.purple[600]),
                          const SizedBox(width: 4),
                          Text("${recipe.sugar}g", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBloodSugarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Entry Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.red[600], size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      "Add Blood Sugar Reading",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Blood Sugar Input
                TextField(
                  controller: bloodSugarController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  onSubmitted: (_) => _dismissKeyboard(),
                  decoration: InputDecoration(
                    labelText: "Blood Sugar Value",
                    suffixText: "mg/dL",
                    prefixIcon: Icon(Icons.water_drop, color: Colors.red[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date & Time Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('MMM d, yyyy').format(selectedDateTime)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDateTime,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(DateFormat('h:mm a').format(selectedDateTime)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (time != null) {
                            setState(() {
                              selectedDateTime = DateTime(
                                selectedDateTime.year,
                                selectedDateTime.month,
                                selectedDateTime.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Context Tags
                const Text("Context", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Fasting', 'Before meal', 'After meal', 'Random'].map((context) {
                    final isSelected = selectedContext == context;
                    return ChoiceChip(
                      label: Text(context),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedContext = context);
                        }
                      },
                      selectedColor: Colors.red[400],
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Note Field
                TextField(
  controller: noteController,
  maxLines: 2,
  textInputAction: TextInputAction.done, // ADD THIS
  onSubmitted: (_) => _dismissKeyboard(), // ADD THIS
  decoration: InputDecoration(
    labelText: "Note (optional)",
    hintText: "e.g., Had oatmeal and berries",
    prefixIcon: const Icon(Icons.note_add),
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red[400]!, width: 2),
    ),
  ),
),
                const SizedBox(height: 20),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saveBloodSugarEntry,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Entry", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Statistics Summary
          if (bloodSugarEntries.isNotEmpty) ...[
            const Text(
              "Statistics",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "High Readings",
                    "${getHighReadingsCount()}",
                    "This week",
                    Colors.red,
                    Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Low Readings",
                    "${getLowReadingsCount()}",
                    "This week",
                    Colors.orange,
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Averages by Context
            ...getAveragesByContext().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            entry.key == 'Fasting' ? Icons.nights_stay :
                            entry.key == 'Before meal' ? Icons.restaurant :
                            entry.key == 'After meal' ? Icons.fastfood :
                            Icons.access_time,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Avg ${entry.key}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${entry.value.toStringAsFixed(0)} mg/dL",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getColorForValue(entry.value.toInt()),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 24),
            const Text(
              "Recent Readings",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Readings List
          if (bloodSugarEntries.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No blood sugar readings yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add your first reading above",
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            ...getGroupedEntries().entries.map((dayGroup) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      dayGroup.key,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  ...dayGroup.value.map((entry) => _buildReadingCard(entry)),
                ],
              );
            }).toList(),
          
          const SizedBox(height: 80),
          
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[800]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This app is for informational purposes only. Always consult your doctor for medical decisions.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(BloodSugarEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: entry.getColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: entry.getColor(),
                  ),
                ),
                Text(
                  "mg/dL",
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.getColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      entry.context == 'Fasting' ? Icons.nights_stay :
                      entry.context == 'Before meal' ? Icons.restaurant :
                      entry.context == 'After meal' ? Icons.fastfood :
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.context,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: entry.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.getStatus(),
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.getColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(entry.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(int value) {
    if (value < 70 || value > 180) {
      return Colors.red;
    } else if (value >= 140 && value <= 180) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: _dismissKeyboard, // Dismiss keyboard when tapping outside
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: profile.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 320,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.black87),
                        tooltip: 'Logout',
                        onPressed: () async {
                          await AuthService().logout();
                          if (!mounted) return;
                          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
  background: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.deepPurple.shade50,
          Colors.white,
        ],
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60), // Add padding for tab bar
        child: SingleChildScrollView( // ADD THIS to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // ADD THIS
            children: [
              const SizedBox(height: 20),
              // Profile Picture
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: imageUrl != null
                        ? (kIsWeb
                            ? (imageUrl!.startsWith('data:') || imageUrl!.length > 200
                                ? Image.memory(base64Decode(imageUrl!), fit: BoxFit.cover)
                                : const Icon(Icons.person, size: 50, color: Colors.white))
                            : Image.file(File(imageUrl!), fit: BoxFit.cover))
                        : const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Tap to change photo",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                profile['name'] ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Bio Section
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: isEditingBio
                          ? TextField(
                              controller: bioController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => saveBio(),
                              decoration: InputDecoration(
                                hintText: "Add a bio...",
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            )
                          : Text(
                              bioController.text.isNotEmpty ? bioController.text : "Add a bio...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: bioController.text.isNotEmpty ? Colors.black87 : Colors.grey[500],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isEditingBio ? Icons.check_circle : Icons.edit,
                        color: Colors.deepPurple,
                        size: 20,
                      ),
                      onPressed: () {
                        if (isEditingBio) {
                          saveBio();
                        } else {
                          setState(() => isEditingBio = true);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8), // Reduced from 12 to save space
            ],
          ),
        ),
      ),
    ),
  ),
),
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurple,
                      tabs: const [
                        Tab(text: "Daily Goals", icon: Icon(Icons.track_changes)),
                        Tab(text: "Favorites", icon: Icon(Icons.favorite)),
                        Tab(text: "Blood Sugar", icon: Icon(Icons.water_drop)),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildDailyGoalsTab(),
                  _buildFavoritesTab(),
                  _buildBloodSugarTab(),
                ],
              ),
            ),
    ),
  );
}

  Widget _buildGoalInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}

