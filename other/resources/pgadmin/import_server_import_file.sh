mkdir -m 700 -p /var/lib/pgadmin/storage/test@test.com
chown -R pgadmin:pgadmin /var/lib/pgadmin/storage/test@test.com
python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Training DB Group',
            'Port': {0},
            'Username': '{1}',
            'Host': '{2}',
            'SSLMode': 'require',
            'PassFile': '/pgpass',
            'MaintenanceDB': '{3}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" > /tmp/servers.json; \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" > /var/lib/pgadmin/storage/test@test.com/pgpass; \
python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('postgres', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Inference DB Group',
            'Port': {0},
            'Username': '{1}',
            'Host': '{2}',
            'SSLMode': 'require',
            'PassFile': '/pgpass',
            'MaintenanceDB': '{3}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)" >> /tmp/servers.json; \
obj=\"{0}:{1}:{2}:{3}\".format(bindings.get('host'),bindings.get('database'),bindings.get('username'),bindings.get('password')); \
print(obj)" >> /var/lib/pgadmin/storage/test@test.com/pgpass; \
chmod 600 /var/lib/pgadmin/storage/test@test.com/pgpass; \
/venv/bin/python3 setup.py --load-servers /tmp/servers.json --user test@test.com;