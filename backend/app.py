from flask import Flask, jsonify, request
from flask_cors import CORS
import datetime

app = Flask(__name__)
CORS(app)  # Allow frontend access

# === Sample in-memory data (replace with real DB later) ===
users = {
    1: {
        "name": "Abhinav",
        "bio": "Living healthy with data!",
        "profile_picture": "https://via.placeholder.com/150",
        "goals": {
            "carbs": 200,
            "sugar": 50,
            "exercise": 30
        },
        "progress": {
            "carbs": 0,
            "sugar": 0,
            "exercise": 0
        },
        "lastUpdated": datetime.date.today().isoformat()
    }
}

recipes = [
    {
        "id": 1,
        "title": "Zucchini Noodles with Pesto",
        "image": "https://picsum.photos/seed/zucchini/300",
        "carbs": 20,
        "sugar": 5,
        "calories": 180,
        "category": "Lunch"
    },
    {
        "id": 2,
        "title": "Grilled Chicken Salad",
        "image": "https://picsum.photos/seed/salad/300",
        "carbs": 10,
        "sugar": 2,
        "calories": 220,
        "category": "Dinner"
    },
    {
        "id": 3,
        "title": "Berry Yogurt Parfait",
        "image": "https://picsum.photos/seed/parfait/300",
        "carbs": 15,
        "sugar": 8,
        "calories": 150,
        "category": "Breakfast"
    },
    {
        "id": 4,
        "title": "Roasted Chickpea Snack",
        "image": "https://picsum.photos/seed/chickpea/300",
        "carbs": 12,
        "sugar": 1,
        "calories": 130,
        "category": "Snacks"
    },
    {
        "id": 5,
        "title": "Greek Yogurt with Nuts",
        "image": "https://picsum.photos/seed/yogurt/300",
        "carbs": 10,
        "sugar": 4,
        "calories": 160,
        "category": "Dessert"
    }
]

# --- Helpers ---
def reset_if_needed(user):
    today = datetime.date.today().isoformat()
    if user.get("lastUpdated") != today:
        user["progress"] = {"carbs": 0, "sugar": 0, "exercise": 0}
        user["lastUpdated"] = today

# --- Routes ---
@app.route("/recipes", methods=["GET"])
def get_recipes():
    return jsonify(recipes)

@app.route("/profile/<int:user_id>", methods=["GET"])
def get_profile(user_id):
    user = users.get(user_id)
    if user:
        reset_if_needed(user)
        return jsonify(user)
    return jsonify({"error": "User not found"}), 404

@app.route("/goals/<int:user_id>", methods=["POST"])
def update_goals(user_id):
    data = request.json
    if user_id in users:
        users[user_id]["goals"] = data
        return jsonify({"message": "Goals updated"})
    return jsonify({"error": "User not found"}), 404

@app.route("/progress/<int:user_id>", methods=["POST"])
def log_progress(user_id):
    data = request.json
    if user_id in users:
        reset_if_needed(users[user_id])
        users[user_id]["progress"]["carbs"] += data.get("carbs", 0)
        users[user_id]["progress"]["sugar"] += data.get("sugar", 0)
        users[user_id]["progress"]["exercise"] += data.get("exercise", 0)
        return jsonify({"message": "Progress updated"})
    return jsonify({"error": "User not found"}), 404

@app.route("/progress/reset/<int:user_id>", methods=["POST"])
def reset_progress(user_id):
    if user_id in users:
        users[user_id]["progress"] = {"carbs": 0, "sugar": 0, "exercise": 0}
        users[user_id]["lastUpdated"] = datetime.date.today().isoformat()
        return jsonify({"message": "Progress reset"})
    return jsonify({"error": "User not found"}), 404

if __name__ == '__main__':
    app.run(debug=True)
