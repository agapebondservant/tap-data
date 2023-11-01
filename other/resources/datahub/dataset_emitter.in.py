from datahub.ingestion.run.pipeline import Pipeline

"""cifar_dataset_pipeline = Pipeline.create(
    {
        "source": {
            "type": "file",
            "config": {
                "path": "${DATA_E2E_ML_TRAINING_DATASET_CIFAR}",
                "file_extension": "*"
            },
        },
        "sink": {
            "type": "datahub-rest",
            "config": {"server": "http://datahub-gms-datahub.${DATA_E2E_BASE_URL}"},
        },
    }
)"""

cifar_dataset_pipeline = Pipeline.create(
    {
        "source": {
            "type": "s3",
            "config": {
                "path_specs": [{"include": "${DATA_E2E_ML_TRAINING_DATASET_CIFAR_S3_BUCKET}"}],
                "aws_config": {
                    "aws_region": "us-east-2"
                },
                "platform": "s3"
            }
        },
        "sink": {
            "type": "datahub-rest",
            "config": {"server": "http://datahub-gms-datahub.${DATA_E2E_BASE_URL}"},
        },
    }
)

cifar_dataset_pipeline.run()
cifar_dataset_pipeline.pretty_print_summary()