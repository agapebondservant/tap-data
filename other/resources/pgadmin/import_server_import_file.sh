chmod 700 /var/lib/pgadmin/storage/test_test.com
python -c "import sys; from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Server Group Training ' + sys.argv[1],
            'Port': {0},
            'Username': '{1}',
            'Host': '{2}',
            'SSLMode': 'require',
            'PassFile': '/pgpasstrain',
            'MaintenanceDB': '{3}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" > /tmp/servers.json; \

python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" > /var/lib/pgadmin/storage/test_test.com/pgpasstrain; \
chmod 600 /var/lib/pgadmin/storage/test_test.com/pgpasstrain; \
/venv/bin/python3 setup.py --load-servers /tmp/servers.json --replace --user test@test.com; \


python -c "import sys; from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('postgres', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Server Group Inference ' + sys.argv[1],
            'Port': {0},
            'Username': '{1}',
            'Host': '{2}',
            'SSLMode': 'require',
            'PassFile': '/pgpassinference',
            'MaintenanceDB': '{3}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" > /tmp/servers2.json; \

python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('postgres', 'vmware') or []), {}); \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" > /var/lib/pgadmin/storage/test_test.com/pgpassinference; \
chmod 600 /var/lib/pgadmin/storage/test_test.com/pgpassinference; \
/venv/bin/python3 setup.py --load-servers /tmp/servers2.json --replace --user test@test.com;