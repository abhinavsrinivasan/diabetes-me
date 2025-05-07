import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map recipe;

  RecipeDetailScreen({required this.recipe});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      backgroundColor: Color(0xFFFFF7F0),
      body: Column(
        children: [
          Stack(
            children: [
              ClipPath(
                clipper: BottomCurveClipper(),
                child: Image.network(
                  recipe['image'],
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() => isFavorite = !isFavorite);
                    Fluttertoast.showToast(
                      msg: isFavorite ? "Added to favorites!" : "Removed from favorites!",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                ),
              )
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe['title'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 18),
                      Icon(Icons.star, color: Colors.orange, size: 18),
                      Icon(Icons.star, color: Colors.orange, size: 18),
                      Icon(Icons.star_half, color: Colors.orange, size: 18),
                      Icon(Icons.star_border, color: Colors.orange, size: 18),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoBox("Calories", "${recipe['calories']} cal"),
                      _infoBox("Ingredients", "${(recipe['ingredients'] ?? []).length.toString().padLeft(2, '0')}"),
                      _infoBox("Total Time", recipe['time'] ?? "25 min"),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("About Recipe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  SizedBox(height: 10),
                  Text(
                    recipe['description'] ??
                        "A delicious diabetic-friendly recipe made with love and health in mind.",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  SizedBox(height: 20),
                  Text("Ingredients", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                  SizedBox(height: 10),
                  ...(recipe['ingredients'] ?? ["Sample Ingredient 1", "Sample Ingredient 2"]).map<Widget>((ing) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                            SizedBox(width: 8),
                            Expanded(child: Text(ing, style: TextStyle(fontSize: 14, color: Color(0xFF333333)))),
                          ],
                        ),
                      ))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333)))
      ],
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0.0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
