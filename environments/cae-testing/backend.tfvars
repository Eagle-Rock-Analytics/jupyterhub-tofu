# Terraform Backend Configuration - CAE Testing Environment
# Will be created automatically by: make init ENVIRONMENT=cae-testing
# Account: 390197508439

bucket         = "tofu-state-jupyterhub-cae-testing-usw2-e7f2a9d8-390197508439"
key            = "terraform.tfstate"
region         = "us-west-2"
encrypt        = true
dynamodb_table = "tofu-state-lock-cae-testing-usw2"
