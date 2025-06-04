# test_spoonacular.py
import requests

# Replace with your actual API key
API_KEY = "dd6b4d10cbf0480c8c0e6fc7f5e9a317"

def test_api():
    url = "https://api.spoonacular.com/recipes/complexSearch"
    params = {
        "diet": "diabetic",
        "number": 3,  # Just get 3 recipes to test
        "apiKey": API_KEY
    }
    
    response = requests.get(url, params=params)
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ API works! Found {len(data['results'])} recipes")
        for recipe in data['results']:
            print(f"- {recipe['title']}")
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.text)

if __name__ == "__main__":
    test_api()