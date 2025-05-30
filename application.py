from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity
)
import datetime

app = Flask(__name__)
CORS(app, origins=["http://localhost:*", "http://127.0.0.1:*"], 
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     allow_headers=["Content-Type", "Authorization"])


# === Security Config ===
app.config['JWT_SECRET_KEY'] = 'super-secret-key  # Use environment variable in production
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(days=1)

bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# === In-memory data (replace with real DB in production) ===
users = {}  # key: email, value: {password_hash, profile}

recipes = [
    {
        "id": 1,
        "title": "Zucchini Noodles with Pesto",
        "image": "https://images.unsplash.com/photo-1609501676725-7186f017a4b7?w=400&h=400&fit=crop",
        "carbs": 20,
        "sugar": 5,
        "calories": 180,
        "category": "Lunch",
        "cuisine": "Italian",
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
        "image": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=400&fit=crop",
        "carbs": 10,
        "sugar": 2,
        "calories": 220,
        "category": "Dinner",
        "cuisine": "Mediterranean",
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
        "image": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop",
        "carbs": 15,
        "sugar": 8,
        "calories": 150,
        "category": "Breakfast",
        "cuisine": "American",
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
        "image": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop",
        "carbs": 12,
        "sugar": 1,
        "calories": 130,
        "category": "Snacks",
        "cuisine": "Mediterranean",
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
        "image": "https://images.unsplash.com/photo-1488900128323-21503983a07e?w=400&h=400&fit=crop",
        "carbs": 10,
        "sugar": 4,
        "calories": 160,
        "category": "Dessert",
        "cuisine": "Mediterranean",
        "glycemic_index": 36,
        "ingredients": ["Greek yogurt", "Almonds", "Walnuts", "Honey"],
        "instructions": [
            "Scoop Greek yogurt into a bowl.",
            "Top with chopped almonds and walnuts.",
            "Drizzle lightly with honey.",
            "Serve immediately."
        ]
    },
    {
        "id": 6,
        "title": "Cauliflower Rice Bowl",
        "image": "https://images.unsplash.com/photo-1534938665420-4193effeacc4?w=400&h=400&fit=crop",
        "carbs": 8,
        "sugar": 3,
        "calories": 140,
        "category": "Lunch",
        "cuisine": "Asian",
        "glycemic_index": 32,
        "ingredients": ["Cauliflower", "Bell peppers", "Onions", "Garlic", "Olive oil"],
        "instructions": [
            "Pulse cauliflower in food processor until rice-like.",
            "Sauté onions and garlic in olive oil.",
            "Add cauliflower rice and bell peppers.",
            "Cook for 5-7 minutes until tender."
        ]
    },
    {
        "id": 7,
        "title": "Avocado Toast",
        "image": "https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=400&h=400&fit=crop",
        "carbs": 25,
        "sugar": 2,
        "calories": 250,
        "category": "Breakfast",
        "cuisine": "American",
        "glycemic_index": 43,
        "ingredients": ["Whole grain bread", "Avocado", "Lime", "Salt", "Pepper"],
        "instructions": [
            "Toast the bread until golden.",
            "Mash avocado with lime juice.",
            "Spread on toast.",
            "Season with salt and pepper."
        ]
    },
    {
        "id": 8,
        "title": "Baked Salmon with Vegetables",
        "image": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400&h=400&fit=crop",
        "carbs": 12,
        "sugar": 6,
        "calories": 320,
        "category": "Dinner",
        "cuisine": "American",
        "glycemic_index": 38,
        "ingredients": ["Salmon fillet", "Broccoli", "Carrots", "Olive oil", "Lemon"],
        "instructions": [
            "Preheat oven to 400°F.",
            "Place salmon and vegetables on baking sheet.",
            "Drizzle with olive oil and lemon.",
            "Bake for 20-25 minutes."
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
    name = data.get("name", "New User")  # Get name from request

    if email in users:
        return jsonify({"msg": "User already exists"}), 400

    hashed_pw = bcrypt.generate_password_hash(password).decode('utf-8')

    users[email] = {
        "password": hashed_pw,
        "profile": {
            "name": name,
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

@app.route("/profile", methods=["PUT"])
@jwt_required()
def update_profile():
    email = get_jwt_identity()
    data = request.get_json()
    user = users.get(email)
    if user:
        # Update name if provided
        if "name" in data:
            user["profile"]["name"] = data["name"]
        # Update bio if provided
        if "bio" in data:
            user["profile"]["bio"] = data["bio"]
        return jsonify({"message": "Profile updated", "profile": user["profile"]})
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
    app.run(debug=True, host='0.0.0.0', port=5001)
