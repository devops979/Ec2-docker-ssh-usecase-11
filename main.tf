provider "aws" {
  region = var.region
}


module "network" {
  source             = "./modules/network"
  vpc_cidr           = var.cidr_block
  vpc_name           = var.vpc_name
  environment        = var.environment
  public_cidr_block  = var.public_subnet_cidrs
  private_cidr_block = var.private_subnet_cidrs
  azs                = var.availability_zones
  owner              = var.owner
}


module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.network.vpc_id
  tags   = var.tags
}

module "Ec2" {
  source             = "./modules/ec2"
  key_name           = var.key_name
  ami_name           = var.ami_id
  sg_id              = module.security_groups.web_sg_id
  vpc_name           = module.network.vpc_name
  public_subnets     = module.network.public_subnets_id
  instance_type      = var.instance_type
  project_name       = "demo-instance"

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt-get install -y nginx docker.io
                sudo systemctl start docker
                sudo systemctl enable docker                
                EOF
}
