from datahub.ingestion.run.pipeline import Pipeline

training_pipeline = Pipeline.create(
    {
        "source": {
            "type": "postgres",
            "config": {
                "username": "gpadmin",
                "password": "${DATA_E2E_ML_TRAINING_PASSWORD}",
                "database": "dev",
                "host_port": "${DATA_E2E_ML_TRAINING_MASTER}:5432",
            },
        },
        "sink": {
            "type": "datahub-rest",
            "config": {"server": "http://datahub-gms-datahub.${DATA_E2E_BASE_URL}"},
        },
    }
)

training_pipeline.run()
training_pipeline.pretty_print_summary()

inference_pipeline = Pipeline.create(
    {
        "source": {
            "type": "postgres",
            "config": {
                "username": "pgadmin",
                "password": "${DATA_E2E_ML_INFERENCE_PASSWORD}",
                "database": "pginstance-inference",
                "host_port": "${DATA_E2E_ML_INFERENCE_HOST}:5432",
            },
        },
        "sink": {
            "type": "datahub-rest",
            "config": {"server": "http://datahub-gms-datahub.${DATA_E2E_BASE_URL}"},
        },
    }
)

inference_pipeline.run()
inference_pipeline.pretty_print_summary()

