from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity
)
import datetime

app = Flask(__name__)
CORS(app)

# === Security Config ===
app.config['JWT_SECRET_KEY'] = 'super-secret-key'  # Use environment variable in production
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(days=1)

bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# === In-memory data (replace with real DB in production) ===
users = {}  # key: email, value: {password_hash, profile}

recipes = [
    {
        "id": 1,
        "title": "Zucchini Noodles with Pesto",
        "image": "https://picsum.photos/seed/zucchini/300",
        "carbs": 20,
        "sugar": 5,
        "calories": 180,
        "category": "Lunch",
        "glycemic_index": 35,
        "ingredients": ["Zucchini", "Pesto", "Olive oil", "Parmesan"],
        "instructions": [
            "Spiralize the zucchini.",
            "Heat in a pan with olive oil.",
            "Add pesto and mix well.",
            "Serve with grated parmesan."
        ]
    },
    {
        "id": 2,
        "title": "Grilled Chicken Salad",
        "image": "https://picsum.photos/seed/salad/300",
        "carbs": 10,
        "sugar": 2,
        "calories": 220,
        "category": "Dinner",
        "glycemic_index": 45,
        "ingredients": ["Chicken breast", "Lettuce", "Tomatoes", "Cucumber", "Balsamic dressing"],
        "instructions": [
            "Grill the chicken until fully cooked.",
            "Chop the lettuce, tomatoes, and cucumber.",
            "Slice the chicken and add to the salad.",
            "Drizzle with balsamic dressing before serving."
        ]
    },
    {
        "id": 3,
        "title": "Berry Yogurt Parfait",
        "image": "https://picsum.photos/seed/parfait/300",
        "carbs": 15,
        "sugar": 8,
        "calories": 150,
        "category": "Breakfast",
        "glycemic_index": 40,
        "ingredients": ["Greek yogurt", "Strawberries", "Blueberries", "Chia seeds", "Honey"],
        "instructions": [
            "Layer Greek yogurt in a glass.",
            "Add a mix of strawberries and blueberries.",
            "Sprinkle chia seeds on top.",
            "Drizzle with honey and serve chilled."
        ]
    },
    {
        "id": 4,
        "title": "Roasted Chickpea Snack",
        "image": "https://picsum.photos/seed/chickpea/300",
        "carbs": 12,
        "sugar": 1,
        "calories": 130,
        "category": "Snacks",
        "glycemic_index": 28,
        "ingredients": ["Canned chickpeas", "Olive oil", "Paprika", "Garlic powder", "Salt"],
        "instructions": [
            "Drain and rinse chickpeas.",
            "Toss with olive oil and seasonings.",
            "Spread on a baking tray.",
            "Roast at 400°F for 25 minutes until crispy."
        ]
    },
    {
        "id": 5,
        "title": "Greek Yogurt with Nuts",
        "image": "https://picsum.photos/seed/yogurt/300",
        "carbs": 10,
        "sugar": 4,
        "calories": 160,
        "category": "Dessert",
        "glycemic_index": 36,
        "ingredients": ["Greek yogurt", "Almonds", "Walnuts", "Honey"],
        "instructions": [
            "Scoop Greek yogurt into a bowl.",
            "Top with chopped almonds and walnuts.",
            "Drizzle lightly with honey.",
            "Serve immediately."
        ]
    }
]

# === Helpers ===
def reset_if_needed(user_profile):
    today = datetime.date.today().isoformat()
    if user_profile.get("lastUpdated") != today:
        user_profile["progress"] = {"carbs": 0, "sugar": 0, "exercise": 0}
        user_profile["lastUpdated"] = today

# === Auth Endpoints ===
@app.route("/signup", methods=["POST"])
def signup():
    data = request.get_json()
    email = data["email"]
    password = data["password"]

    if email in users:
        return jsonify({"msg": "User already exists"}), 400

    hashed_pw = bcrypt.generate_password_hash(password).decode('utf-8')

    users[email] = {
        "password": hashed_pw,
        "profile": {
            "name": "New User",
            "bio": "",
            "profile_picture": "",
            "goals": {"carbs": 200, "sugar": 50, "exercise": 30},
            "progress": {"carbs": 0, "sugar": 0, "exercise": 0},
            "lastUpdated": datetime.date.today().isoformat()
        }
    }

    return jsonify({"msg": "User registered successfully"}), 200

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    email = data["email"]
    password = data["password"]

    user = users.get(email)
    if not user or not bcrypt.check_password_hash(user["password"], password):
        return jsonify({"msg": "Invalid credentials"}), 401

    access_token = create_access_token(identity=email)
    return jsonify(access_token=access_token), 200

# === Recipe Endpoint ===
@app.route("/recipes", methods=["GET"])
def get_recipes():
    return jsonify(recipes)

# === Profile & Goal Management ===
@app.route("/profile", methods=["GET"])
@jwt_required()
def get_profile():
    email = get_jwt_identity()
    user = users.get(email)
    if user:
        reset_if_needed(user["profile"])
        return jsonify(user["profile"])
    return jsonify({"error": "User not found"}), 404

@app.route("/goals", methods=["POST"])
@jwt_required()
def update_goals():
    email = get_jwt_identity()
    data = request.get_json()
    user = users.get(email)
    if user:
        user["profile"]["goals"] = data
        return jsonify({"message": "Goals updated"})
    return jsonify({"error": "User not found"}), 404

@app.route("/progress", methods=["POST"])
@jwt_required()
def log_progress():
    email = get_jwt_identity()
    data = request.get_json()
    user = users.get(email)
    if user:
        reset_if_needed(user["profile"])
        user["profile"]["progress"]["carbs"] += data.get("carbs", 0)
        user["profile"]["progress"]["sugar"] += data.get("sugar", 0)
        user["profile"]["progress"]["exercise"] += data.get("exercise", 0)
        return jsonify({"message": "Progress updated"})
    return jsonify({"error": "User not found"}), 404

@app.route("/progress/reset", methods=["POST"])
@jwt_required()
def reset_progress():
    email = get_jwt_identity()
    user = users.get(email)
    if user:
        user["profile"]["progress"] = {"carbs": 0, "sugar": 0, "exercise": 0}
        user["profile"]["lastUpdated"] = datetime.date.today().isoformat()
        return jsonify({"message": "Progress reset"})
    return jsonify({"error": "User not found"}), 404

# === Run Server ===
if __name__ == "__main__":
    app.run(debug=True)
