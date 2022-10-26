import json
from faker import Faker
import random
from random import randint

fake = Faker('en_US')
import sys


def upload_content(content, i):
    f = open("{0}.json".format(str(i)), "w+")
    f.write(str(content))
    f.close()


for i in range(int(sys.argv[1]) or 1000):
    my_dict = {'id': i, 'name': fake.name(), 'dob': fake.date_of_birth().strftime("%m-%d-%Y"),
               'address': fake.address(), 'phone': fake.phone_number(), 'email': fake.email()}
    print(my_dict)
    upload_content(my_dict, i)
