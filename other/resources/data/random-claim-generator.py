import json
from faker import Faker
import random
from random import randint
import requests
from datetime import datetime
import os
fake = Faker('en_US')
import sys

def put_content(content,root_url):
    x = requests.put(f'{root_url}/{content["id"]}', data = json.dumps(content, indent=2), headers = {"Content-Type": "application/json"})
    print(x.text)

# Usage
if len(sys.argv) == 1:
    print(f'USAGE: {os.path.basename(sys.argv[0])} ((number of records OR -1 for unlimited records)) ((POST url)) ((cityname (optional)))')
    quit()

# Generate a list of 20 cities
cities = ['New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio','San Diego','Dallas','San Jose','Austin',
            'Jacksonville', 'Fort Worth', 'Columbus', 'Indianapolis', 'Charlotte', 'San Francisco', 'Seattle', 'Denver', 'Washington']

# Generate random data
for i in range(sys.maxsize if int(sys.argv[1])==-1 else sys.argv[1]):
    city = sys.argv[3] if len(sys.argv)>3 else cities[random.randint(0,19)]
    my_dict = { 'id': f'{city}{i}', 
    '@type': 'org.apache.geode.web.rest.domain.Claim',
    'name': fake.name(), 
    'dob': fake.date_of_birth().strftime("%m-%d-%Y") , 
    'address': fake.address(), 
    'phone': fake.phone_number(), 
    'claimdate': datetime.now().strftime("%m-%d-%Y %H:%M:%S"),
    'city': city,
    'amount': random.randint(200,1000)}

    print(json.dumps(my_dict, indent=2))
    put_content(my_dict, sys.argv[2])
