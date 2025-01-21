#!/bin/bash

# Create folder and navigate into it
mkdir "Upwind Automated aws workshop" && cd "Upwind Automated aws workshop"

# Download the Terraform file
curl -O https://raw.githubusercontent.com/Zoan112/upwind-home-assignment-/main/main.tf

# Run Terraform init and apply
terraform init && terraform apply
