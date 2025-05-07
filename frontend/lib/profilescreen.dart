import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
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

  final baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    fetchProfile();
    loadSavedImage();
  }

  Future<void> loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profile_image_path');
    if (savedPath != null && File(savedPath).existsSync()) {
      setState(() => imageUrl = savedPath);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        setState(() => imageUrl = pickedFile.path);
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
    final response = await http.get(Uri.parse('$baseUrl/profile/1'));
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
    final res = await http.post(
      Uri.parse('$baseUrl/goals/1'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "carbs": int.parse(carbsController.text),
        "sugar": int.parse(sugarController.text),
        "exercise": int.parse(exerciseController.text),
      }),
    );
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Goals updated")),
      );
      fetchProfile();
    }
  }

  Future<void> resetProgress() async {
    final res = await http.post(Uri.parse('$baseUrl/progress/reset/1'));
    if (res.statusCode == 200) {
      fetchProfile();
    }
  }

  Future<void> updateManual(String type, String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    final res = await http.post(
      Uri.parse('$baseUrl/progress/1'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({type: parsed}),
    );
    if (res.statusCode == 200) {
      fetchProfile();
    }
  }

  Widget buildProgressCard(String label, int progress, int goal, Color color, TextEditingController input, String type) {
    double percent = (goal > 0) ? (progress / goal).clamp(0.0, 1.0) : 0.0;
    String unit = type == 'exercise' ? 'min' : 'g';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade300,
                    color: color,
                  ),
                ),
                Text("${(percent * 100).toInt()}%"),
              ],
            ),
            SizedBox(height: 4),
            Text("$progress $unit", style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            TextField(
              controller: input,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: unit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            SizedBox(height: 6),
            ElevatedButton(
              onPressed: () => updateManual(type, input.text),
              child: Text("Add"),
              style: ElevatedButton.styleFrom(backgroundColor: color),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: profile.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: imageUrl != null
                          ? FileImage(File(imageUrl!))
                          : NetworkImage(profile['profile_picture']) as ImageProvider,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Tap to change photo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 16),
                  TextField(
                    controller: bioController,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Daily Goals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: resetProgress, icon: Icon(Icons.refresh, color: Colors.orange))
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: buildProgressCard("Carbs", profile['progress']['carbs'], profile['goals']['carbs'], Colors.orange, carbsInput, 'carbs')),
                      SizedBox(width: 8),
                      Expanded(child: buildProgressCard("Sugar", profile['progress']['sugar'], profile['goals']['sugar'], Colors.purple, sugarInput, 'sugar')),
                      SizedBox(width: 8),
                      Expanded(child: buildProgressCard("Exercise", profile['progress']['exercise'], profile['goals']['exercise'], Colors.green, exerciseInput, 'exercise')),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("Update Goals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  TextField(
                    controller: carbsController,
                    decoration: InputDecoration(labelText: 'Daily Carb Goal', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: sugarController,
                    decoration: InputDecoration(labelText: 'Daily Sugar Goal', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: exerciseController,
                    decoration: InputDecoration(labelText: 'Daily Exercise Goal (mins)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveGoals,
                    child: Text("Save Goals"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
