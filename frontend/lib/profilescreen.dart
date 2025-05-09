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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> profile = {};
  TextEditingController bioController = TextEditingController();
  TextEditingController carbsController = TextEditingController();
  TextEditingController sugarController = TextEditingController();
  TextEditingController exerciseController = TextEditingController();
  TextEditingController carbsInput = TextEditingController();
  TextEditingController sugarInput = TextEditingController();
  TextEditingController exerciseInput = TextEditingController();

  String? imageUrl;
  Uint8List? pickedImageBytes;
  bool isEditingBio = false;
  bool showGoals = false;

  final baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    fetchProfile();
    loadSavedImage();
  }

  Future<void> loadSavedImage() async {
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('profile_image_path');
      if (savedPath != null && File(savedPath).existsSync()) {
        setState(() => imageUrl = savedPath);
      }
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          pickedImageBytes = bytes;
          imageUrl = pickedFile.path;
        });
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(pickedFile.path);
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', savedImage.path);
        setState(() => imageUrl = savedImage.path);
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goals updated")));
      fetchProfile();
    }
  }

  Future<void> resetProgress() async {
    final token = await AuthService().getToken();
    final res = await http.post(Uri.parse('$baseUrl/progress/reset'), headers: {"Authorization": "Bearer $token"});
    if (res.statusCode == 200) {
      fetchProfile();
    }
  }

  Future<void> updateManual(String type, String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    final token = await AuthService().getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/progress'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: json.encode({type: parsed}),
    );
    if (res.statusCode == 200) {
      fetchProfile();
    }
  }

  Widget buildProgressCard(String label, int progress, int goal, Color color, TextEditingController input, String type) {
  double percent = (goal > 0) ? (progress / goal).clamp(0.0, 1.0) : 0.0;
  String unit = type == 'exercise' ? 'min' : 'g';
  return Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
  height: 60,
  width: 60,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Transform.scale(
        scale: 1.5,
        child: CircularProgressIndicator(
          value: percent,
          strokeWidth: 5,
          backgroundColor: Colors.grey.shade300,
          color: color,
        ),
      ),
      Text(
        "${(percent * 100).toInt()}%",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  ),
),

        const SizedBox(height: 6),
        Text("$progress $unit", style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 36, // Smaller input field
          child: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: unit,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: () => updateManual(type, input.text),
            child: const Text("Add"),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              textStyle: const TextStyle(fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          )
        ],
      ),
      body: profile.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: imageUrl != null
    ? (kIsWeb
        ? (pickedImageBytes != null
            ? MemoryImage(pickedImageBytes!) as ImageProvider<Object>
            : null)
        : FileImage(File(imageUrl!)) as ImageProvider<Object>)
    : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Tap to change photo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Bio with edit button
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
  height: 40, // or 36 for smaller height
  child: TextField(
    controller: bioController,
    readOnly: !isEditingBio,
    style: const TextStyle(fontSize: 14), // optional: smaller font
    decoration: InputDecoration(
      hintText: 'Bio',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(isEditingBio ? Icons.check : Icons.edit, color: Colors.deepPurple),
                        onPressed: () {
                          setState(() {
                            if (isEditingBio) {
                              // Save logic here if needed
                            }
                            isEditingBio = !isEditingBio;
                          });
                        },
                      )
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Daily Goals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: resetProgress, icon: const Icon(Icons.refresh, color: Colors.orange))
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      buildProgressCard("Carbs", profile['progress']['carbs'], profile['goals']['carbs'], Colors.orange, carbsInput, 'carbs'),
                      const SizedBox(width: 8),
                      buildProgressCard("Sugar", profile['progress']['sugar'], profile['goals']['sugar'], Colors.purple, sugarInput, 'sugar'),
                      const SizedBox(width: 8),
                      buildProgressCard("Exercise", profile['progress']['exercise'], profile['goals']['exercise'], Colors.green, exerciseInput, 'exercise'),
                    ],
                  ),

                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text("Update Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    initiallyExpanded: false,
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                        controller: carbsController,
                        decoration: const InputDecoration(labelText: 'Daily Carb Goal', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: sugarController,
                        decoration: const InputDecoration(labelText: 'Daily Sugar Goal', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: exerciseController,
                        decoration: const InputDecoration(labelText: 'Daily Exercise Goal (mins)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saveGoals,
                        child: const Text("Save Goals"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
    );
  }
}
