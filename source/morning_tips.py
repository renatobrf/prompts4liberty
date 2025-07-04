# give me morning tips from python code
import requests
import json
from datetime import datetime

def get_morning_tips():
    response = requests.get("https://api.example.com/morning-tips")
    data = json.loads(response.text)
    return data["tips"]
# Assisted by watsonx Code Assistant 

# get_morning_tips()

# create a new md file to describe the code
def create_md_file():
    content = """# Morning Tips Code    
This Python script fetches morning tips from an external API and prints them.

## Code Explanation
- The script imports the `requests` and `json` libraries to handle HTTP requests and JSON data.
- The `get_morning_tips` function sends a GET request to the specified API endpoint.
- It parses the JSON response to extract the tips.      
- Finally, it returns the tips for further use.

## Usage
- Run the script to fetch and print the morning tips.

## Dependencies 
- `requests`: For making HTTP requests.
- `json`: For parsing JSON data.

## Executions
"""
    
    with open("morning_tips.md", "w") as file:
        file.write(content)

def increase_md_file():
    # open the existing file and append content
    with open("morning_tips.md", "r") as file:
        content = file.read()   
    
    now = datetime.now()
    formatted = now.strftime("%Y-%m-%d %H-%M-%S")    
    content += '- '+ formatted + '\n'

    with open("morning_tips.md", "w") as file:
        file.write(content)

#create_md_file()
increase_md_file()
