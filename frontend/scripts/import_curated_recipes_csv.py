import csv
import ast
import os
from supabase import create_client, Client

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def parse_list_field(field):
    try:
        # Try to parse as Python list first
        if field.startswith("["):
            return ast.literal_eval(field)
        # Otherwise, split on newlines (not commas)
        return [x.strip() for x in field.splitlines() if x.strip()]
    except Exception:
        return [field]

def import_csv_to_supabase(csv_path):
    # Delete all existing rows first
    print("⚠️ Deleting all existing rows from curated_recipes...")
    supabase.table("curated_recipes").delete().neq("id", 0).execute()
    print("✅ All rows deleted.")

    with open(csv_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            try:
                recipe = {
                    "title": row["title"],
                    "image": row["image"],
                    "carbs": int(float(row["carbs"])),
                    "sugar": int(float(row["sugar"])),
                    "calories": int(float(row["calories"])),
                    "category": row["category"],
                    "cuisine": row["cuisine"],
                    "ingredients": parse_list_field(row["ingredients"]),
                    "instructions": parse_list_field(row["instructions"]),
                    "approved": row.get("approved", "false").lower() in ("true", "1", "t"),
                    "quality_score": int(row.get("quality_score", 0)),
                }
                supabase.table("curated_recipes").insert(recipe).execute()
                print(f"✅ Uploaded: {recipe['title']}")
            except Exception as e:
                print(f"⚠️ Failed to upload '{row.get('title', 'Unknown')}': {e}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python import_curated_recipes_csv.py /Users/abhinavsrinivasan/Downloads/curated_recipes_cleaned_final.csv")
    else:
        import_csv_to_supabase(sys.argv[1])