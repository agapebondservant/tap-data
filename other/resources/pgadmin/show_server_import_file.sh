set -x
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
            'PassFile': '/pgpass',
            'MaintenanceDB': '{4}'
        }}}}}}\"\"\"; \
obj = obj.replace('\'', '\"'); \
obj = obj.format(os.getenv('SRV_GRP_SUFFIX'), bindings.get('port'), bindings.get('username'), bindings.get('host'), bindings.get('database'));\
print(obj)"