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
import 'services/auth_service.dart';
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic> profile = {};
  List<Recipe> favoriteRecipes = [];
  TextEditingController bioController = TextEditingController();
  TextEditingController carbsController = TextEditingController();
  TextEditingController sugarController = TextEditingController();
  TextEditingController exerciseController = TextEditingController();
  TextEditingController carbsInput = TextEditingController();
  TextEditingController sugarInput = TextEditingController();
  TextEditingController exerciseInput = TextEditingController();

  String? imageUrl;
  String? userEmail;
  Uint8List? pickedImageBytes;
  bool isEditingBio = false;
  bool showGoals = false;

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late TabController _tabController;

  final baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

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
    _tabController = TabController(length: 2, vsync: this);
    fetchProfile();
    loadSavedImage();
    loadFavoriteRecipes();
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
    double displayPercent = percent.clamp(0.0, 1.0); // For progress bar
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
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "$progress / $goal $unit",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
          // Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                              ],
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
                ],
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