mkdir -p /var/lib/pgadmin/storage/test_test.com
chmod 700 /var/lib/pgadmin/storage/test_test.com
python -c "import os; from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Server Group Training {0}',
            'Port': {1},
            'Username': '{2}',
            'Host': '{3}',
            'SSLMode': 'require',
            'PassFile': '/pgpasstrain',
            'MaintenanceDB': '{4}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(os.getenv('SRV_GRP_SUFFIX'), bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" > /tmp/servers.json; \

python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" > /var/lib/pgadmin/storage/test_test.com/pgpasstrain; \
chmod 600 /var/lib/pgadmin/storage/test_test.com/pgpasstrain; \
/venv/bin/python3 setup.py --load-servers /tmp/servers.json --replace --user test@test.com; \


python -c "import os; from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('postgres', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Server Group Inference {0}',
            'Port': {1},
            'Username': '{2}',
            'Host': '{3}',
            'SSLMode': 'require',
            'PassFile': '/pgpassinference',
            'MaintenanceDB': '{4}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(os.getenv('SRV_GRP_SUFFIX'), bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" > /tmp/servers2.json; \

python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('postgres', 'vmware') or []), {}); \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" > /var/lib/pgadmin/storage/test_test.com/pgpassinference; \
chmod 600 /var/lib/pgadmin/storage/test_test.com/pgpassinference; \
/venv/bin/python3 setup.py --load-servers /tmp/servers2.json --replace --user test@test.com;