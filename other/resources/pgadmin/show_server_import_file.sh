set -x
python -c "from pyservicebinding import binding; bindings = next(iter(binding.ServiceBinding().bindings('greenplum', 'vmware') or []), {}); \
obj =\"\"\"{{
    'Servers': {{
        '1': {{
            'Name': 'test@test.com',
            'Group': 'Default 123 Group 1',
            'Port': {0},
            'Username': '{1}',
            'Host': '{2}',
            'SSLMode': 'require',
            'PassFile': '/pgpass',
            'MaintenanceDB': '{3}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)"