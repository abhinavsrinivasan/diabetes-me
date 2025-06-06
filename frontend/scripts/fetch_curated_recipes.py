import requests
import time
import os
import json
from supabase import create_client, Client

# Load environment variables
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
API_KEY = os.getenv('SPOONACULAR_API_KEY')

if not SUPABASE_URL or not SUPABASE_KEY or not API_KEY:
    raise EnvironmentError("Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or SPOONACULAR_API_KEY environment variable.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

MAX_CARBS = 40
MAX_SUGAR = 15
RECIPE_LIMIT = 100

CUISINE_COUNTS = {
    "American": 15,
    "Italian": 15,
    "Mexican": 14,
    "Asian": 14,
    "Mediterranean": 14,
    "Indian": 14,
    "French": 14,
}

def safe_get_nutrient(nutrients, name):
    for n in nutrients:
        if n.get("name", "").lower() == name.lower():
            return n.get("amount")
    return None

def fetch_recipes(cuisine, count):
    all_results = []
    offset = 0

    while len(all_results) < count:
        params = {
            "apiKey": API_KEY,
            "cuisine": cuisine,
            "addRecipeNutrition": True,
            "number": min(50, count - len(all_results)),
            "offset": offset,
            "maxCarbs": MAX_CARBS,
            "maxSugar": MAX_SUGAR
        }

        response = requests.get("https://api.spoonacular.com/recipes/complexSearch", params=params)
        
        if response.status_code == 402 or response.status_code == 429:
            print("❌ Spoonacular API limit reached or too many requests. Try again later or upgrade your plan.")
            exit(1)
        
        data = response.json()
        results = data.get("results", [])

        for r in results:
            try:
                recipe_id = r.get("id")
                if not recipe_id:
                    raise ValueError("Missing recipe id")

                # Fetch full recipe info
                info_params = {"apiKey": API_KEY, "includeNutrition": True}
                info_resp = requests.get(
                    f"https://api.spoonacular.com/recipes/{recipe_id}/information",
                    params=info_params
                )
                if info_resp.status_code != 200:
                    print(f"❌ Info fetch failed for recipe {recipe_id}: {info_resp.status_code} {info_resp.text}")
                    continue
                info = info_resp.json()

                # Nutrition
                nutrients = []
                if "nutrition" in info and "nutrients" in info["nutrition"]:
                    nutrients = info["nutrition"]["nutrients"]
                carbs = safe_get_nutrient(nutrients, "Carbohydrates")
                sugar = safe_get_nutrient(nutrients, "Sugar")
                calories = safe_get_nutrient(nutrients, "Calories")
                if carbs is None or sugar is None or calories is None:
                    raise ValueError("Missing nutrition info")

                # Ingredients
                if "extendedIngredients" in info and isinstance(info["extendedIngredients"], list):
                    ingredients = [
                        i.get("nameClean") or i.get("name") or "" for i in info["extendedIngredients"]
                    ]
                else:
                    raise ValueError("Missing extendedIngredients")

                # Instructions
                instructions = []
                if (
                    "analyzedInstructions" in info and
                    isinstance(info["analyzedInstructions"], list) and
                    len(info["analyzedInstructions"]) > 0 and
                    "steps" in info["analyzedInstructions"][0]
                ):
                    instructions = [
                        step.get("step", "") for step in info["analyzedInstructions"][0]["steps"]
                    ]

                recipe = {
                    "title": info.get("title", ""),
                    "image": info.get("image", ""),
                    "carbs": int(float(carbs)),
                    "sugar": int(float(sugar)),
                    "calories": int(float(calories)),
                    "category": info.get("dishTypes", ["Other"])[0] if info.get("dishTypes") else "Other",
                    "cuisine": cuisine,
                    "ingredients": ingredients,
                    "instructions": instructions,
                    "approved": False,
                    "quality_score": 0
                }
                all_results.append(recipe)
                print(f"✅ {len(all_results)}/{count} {cuisine} recipes fetched...", end='\r')
                if len(all_results) >= count:
                    break
            except Exception as e:
                print(f"⚠️ Skipped one due to error: {e}")

            time.sleep(0.1)  # Reduce delay for faster fetching

        offset += 50
        # time.sleep(1)  # You can comment this out or reduce it

    return all_results

def upload_to_supabase(recipes):
    for recipe in recipes:
        try:
            supabase.table("curated_recipes").insert(recipe).execute()
        except Exception as e:
            print(f"⚠️ Failed to upload recipe '{recipe.get('title', 'Unknown')}': {e}")

def main():
    total_uploaded = 0
    for cuisine, count in CUISINE_COUNTS.items():
        print(f"🍽 Fetching {count} {cuisine} recipes...")
        recipes = fetch_recipes(cuisine, count)
        print(f"✅ {len(recipes)} recipes fetched for {cuisine}")
        upload_to_supabase(recipes)
        total_uploaded += len(recipes)
        print(f"⬆️ Uploaded {len(recipes)} to Supabase.")

    print(f"🎉 Done. {total_uploaded} total recipes uploaded.")

if __name__ == "__main__":
    main()
