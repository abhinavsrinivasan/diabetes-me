import boto3

session = boto3.Session(profile_name='default', region_name='us-east-1')
dynamodb = session.resource('dynamodb')
table = dynamodb.Table('diabetes_recipes')

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

for recipe in recipes:
    recipe['id'] = str(recipe['id'])  # Convert id to string for DynamoDB
    print(dynamodb.meta.client.list_tables())
    table.put_item(Item=recipe)

print("✅ All recipes inserted successfully.")
