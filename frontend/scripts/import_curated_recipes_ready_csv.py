import csv
import ast
import os
from supabase import create_client, Client

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def parse_brace_list(field):
    # Converts {a,b,c} or {'a','b'} to ['a','b','c']
    if field.startswith("{") and field.endswith("}"):
        items = field[1:-1].split(",")
        return [i.strip(" '\"") for i in items]
    return [field]

def import_csv_to_supabase(csv_path):
    # Delete all rows
    print("⚠️ Deleting all existing rows from curated_recipes...")
    supabase.table("curated_recipes").delete().neq("id", 0).execute()
    print("✅ All rows deleted.")

    # Reset the sequence (run this SQL in Supabase SQL editor for full reset)
    # Or use the API if you have access to run raw SQL

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
                    "ingredients": parse_brace_list(row["ingredients"]),
                    "instructions": parse_brace_list(row["instructions"]),
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
        print("Usage: python import_curated_recipes_ready_csv.py /Users/abhinavsrinivasan/Downloads/curated_recipes_ready_for_supabase.csv")
    else:
        import_csv_to_supabase(sys.argv[1])