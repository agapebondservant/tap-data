--liquibase formatted sql
--changeset pgadmin:XYZCHANGESETID
CREATE EXTENSION IF NOT EXISTS plpython3u;
CREATE OR REPLACE FUNCTION XYZDBSCHEMA.run_inference_task (img bytea,
    model_name text,
    model_stage text,
    app_location text,
    mlflow_tracking_uri text,
    git_repo text,
    git_branch text)
RETURNS TEXT
AS $$
    # container: plc_python3_shared
    import os, sys, subprocess, logging, pickle
    try:
        os.environ['MLFLOW_TRACKING_URI'] = mlflow_tracking_uri

        dir = f"{os.path.expanduser('~')}/{app_location}"
        logging.getLogger().addHandler(logging.StreamHandler())
        logging.getLogger().addHandler(logging.FileHandler(f"{dir}/debug.log"))
        if not os.path.exists(dir):
        	os.system(f'git clone -v --branch={git_branch} "{git_repo}" --single-branch {dir}')
        sys.path.append(f'{dir}') if dir not in sys.path else True
        sys.modules.pop('app.analytics.cifar_cnn') if sys.modules.get('app.analytics.cifar_cnn') else True
        sys.modules.pop('app.analytics.config') if sys.modules.get('app.analytics.config') else True

        from app.analytics import cifar_cnn, config
        return cifar_cnn.predict(pickle.loads(img), model_name, model_stage)
    except subprocess.CalledProcessError as e:
        plpy.error(e.output)
$$
LANGUAGE 'plpython3u';