--liquibase formatted sql
--changeset gpadmin:XYZCHANGESETID
CREATE OR REPLACE FUNCTION "XYZDBSCHEMA".run_training_task (mlflow_stage text,
                                        git_repo text,
                                        entry_point text,
                                        experiment_name text,
                                        environment_name text,
                                        mlflow_host text,
                                        mlflow_s3_uri text,
                                        app_location text)
RETURNS TEXT
AS $$
    # container: plc_python3_shared
    import os
    import sys
    import subprocess
    import logging
    logging.getLogger().addHandler(logging.StreamHandler())
    logging.getLogger().addHandler(logging.FileHandler(f"{app_location}/debug.log"))
    import importlib
    import pkgutil
    try:
        os.environ['MLFLOW_TRACKING_URI']=mlflow_host
        os.environ['MLFLOW_S3_ENDPOINT_URL']=mlflow_s3_uri
        os.environ['git_repo']=git_repo
        os.environ['mlflow_entry']=entry_point
        os.environ['mlflow_stage']=mlflow_stage
        os.environ['environment_name']=environment_name
        os.environ['experiment_name']=experiment_name
        os.environ['shared_app_path']=app_location
        os.environ['PYTHONPATH']=f'{app_location}/_vendor:{app_location}:{os.getenv("PYTHONPATH")}:{os.getenv("PATH")}'
--        sys.path.append(f'{app_location}/_vendor')
--        sys.path.append(f'{app_location}')
--        if sys.modules.get('base_app.base_app_main'):
--            del sys.modules['base_app.base_app_main']
--        if sys.modules.get('base_app'):
--            del sys.modules['base_app']

--        from base_app import base_app_main

        result = subprocess.run([sys.executable, f"{app_location}/base_app/main.py"], capture_output=True, text=True, env=os.environ.copy())
        plpy.info("stdout: ", result.stdout)
        plpy.info("stderr: ", result.stderr)

        return subprocess.check_output('ls -ltr /', shell=True).decode(sys.stdout.encoding).strip()
    except subprocess.CalledProcessError as e:
        plpy.error(e.output)
$$
LANGUAGE 'plpython3u';

