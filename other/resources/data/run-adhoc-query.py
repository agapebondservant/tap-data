import sys
import requests

# Usage
if len(sys.argv) != 3:
    print(f'USAGE: {os.path.basename(sys.argv[0])} ((url)) ((query))')
    quit()

r = requests.get(f'{sys.argv[1]}/queries/adhoc', params = {"q": sys.argv[2]})

print(r.text)