# Terraform Backend Configuration - CAE Development Environment
# Will be created automatically by: make init ENVIRONMENT=cae-dev
# Account: 390197508439

bucket         = "tofu-state-jupyterhub-cae-dev-usw2-390197508439"
key            = "terraform.tfstate"
region         = "us-west-2"
encrypt        = true
dynamodb_table = "tofu-state-lock-cae-dev-usw2"
