# import_recipes.py
import requests
import time
from application import app, db, Recipe

# Your Spoonacular API key
API_KEY = "dd6b4d10cbf0480c8c0e6fc7f5e9a317"

def get_diabetic_recipes(limit=50):
    """Get diabetes-friendly recipes from Spoonacular"""
    url = "https://api.spoonacular.com/recipes/complexSearch"
    params = {
        "diet": "diabetic",
        "maxCarbs": 35,           # Max 35g carbs per serving
        "maxSugar": 15,           # Max 15g sugar per serving  
        "addRecipeInformation": True,
        "addRecipeNutrition": True,
        "number": limit,
        "apiKey": API_KEY
    }
    
    print(f"🔍 Searching for {limit} diabetic-friendly recipes...")
    response = requests.get(url, params=params)
    
    if response.status_code != 200:
        print(f"❌ Error: {response.status_code}")
        print(response.text)
        return []
    
    data = response.json()
    print(f"✅ Found {len(data['results'])} recipes")
    return data['results']

def extract_nutrition(nutrition_data):
    """Extract key nutrition values from Spoonacular data"""
    nutrients = nutrition_data.get('nutrients', [])
    
    # Find specific nutrients
    carbs = 0
    sugar = 0
    calories = 0
    
    for nutrient in nutrients:
        name = nutrient.get('name', '').lower()
        amount = nutrient.get('amount', 0)
        
        if 'carbohydrate' in name:
            carbs = int(amount)
        elif 'sugar' in name:
            sugar = int(amount)
        elif name == 'calories':
            calories = int(amount)
    
    return carbs, sugar, calories

def estimate_glycemic_index(carbs, sugar, ingredients):
    """Simple GI estimation based on ingredients and carb/sugar ratio"""
    ingredient_text = ' '.join(ingredients).lower()
    
    # High GI indicators
    if any(word in ingredient_text for word in ['white rice', 'white bread', 'potato', 'corn syrup']):
        return 70
    
    # Low GI indicators  
    if any(word in ingredient_text for word in ['quinoa', 'oats', 'beans', 'lentils', 'nuts']):
        return 35
    
    # Sugar-based estimation
    if carbs > 0:
        sugar_ratio = sugar / carbs
        if sugar_ratio > 0.7:
            return 65  # High GI
        elif sugar_ratio > 0.3:
            return 50  # Medium GI
        else:
            return 40  # Low GI
    
    return 45  # Default medium-low

def import_recipes_to_database(recipes_data):
    """Import recipes into your database"""
    imported_count = 0
    
    with app.app_context():
        for recipe_data in recipes_data:
            try:
                # Extract basic info
                title = recipe_data.get('title', 'Unknown Recipe')
                image_url = recipe_data.get('image', '')
                
                # Extract nutrition
                nutrition = recipe_data.get('nutrition', {})
                carbs, sugar, calories = extract_nutrition(nutrition)
                
                # Extract ingredients and instructions
                ingredients = []
                if 'extendedIngredients' in recipe_data:
                    ingredients = [ing.get('original', '') for ing in recipe_data['extendedIngredients']]
                
                instructions = []
                if 'analyzedInstructions' in recipe_data and recipe_data['analyzedInstructions']:
                    steps = recipe_data['analyzedInstructions'][0].get('steps', [])
                    instructions = [step.get('step', '') for step in steps]
                
                # Determine category and cuisine
                dish_types = recipe_data.get('dishTypes', [])
                category = 'Main Course'
                if dish_types:
                    if 'breakfast' in dish_types[0].lower():
                        category = 'Breakfast'
                    elif 'lunch' in dish_types[0].lower():
                        category = 'Lunch'
                    elif 'dinner' in dish_types[0].lower():
                        category = 'Dinner'
                    elif 'dessert' in dish_types[0].lower():
                        category = 'Dessert'
                    elif 'snack' in dish_types[0].lower():
                        category = 'Snacks'
                
                cuisines = recipe_data.get('cuisines', ['American'])
                cuisine = cuisines[0] if cuisines else 'American'
                
                # Estimate glycemic index
                gi = estimate_glycemic_index(carbs, sugar, ingredients)
                
                # Check if recipe already exists
                existing = Recipe.query.filter_by(title=title).first()
                if existing:
                    print(f"⚠️  Skipping duplicate: {title}")
                    continue
                
                # Create new recipe
                recipe = Recipe(
                    title=title,
                    image_url=image_url,
                    carbs=carbs,
                    sugar=sugar,
                    calories=calories,
                    category=category,
                    cuisine=cuisine,
                    glycemic_index=gi,
                    ingredients=ingredients,
                    instructions=instructions
                )
                
                db.session.add(recipe)
                imported_count += 1
                print(f"✅ Added: {title} (Carbs: {carbs}g, Sugar: {sugar}g, GI: {gi})")
                
                # Small delay to be nice to the API
                time.sleep(0.1)
                
            except Exception as e:
                print(f"❌ Error importing recipe: {e}")
                continue
        
        # Commit all changes
        db.session.commit()
        print(f"\n🎉 Successfully imported {imported_count} recipes!")

def main():
    print("🍽️  Diabetes&Me Recipe Importer")
    print("=" * 40)
    
    # Get recipes from Spoonacular
    recipes = get_diabetic_recipes(limit=50)  # Free tier allows this
    
    if not recipes:
        print("❌ No recipes found. Check your API key.")
        return
    
    # Import to database
    import_recipes_to_database(recipes)
    
    print("\n✅ Import complete! Your app now has diabetes-friendly recipes.")

if __name__ == "__main__":
    main()