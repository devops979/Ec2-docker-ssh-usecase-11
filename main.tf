provider "aws" {
  region = var.region
}


module "network" {
  source             = "./modules/network"
  vpc_cidr           = var.cidr_block
  vpc_name           = "demo-webapp-vpc"
  environment        = var.environment
  public_cidr_block  = var.public_subnet_cidrs
  private_cidr_block = var.private_subnet_cidrs
  azs                = var.availability_zones
  owner              = "demo-webapp-alb"
}

module "nat" {
  source           = "./modules/nat"
  public_subnet_id = module.network.public_subnets_id[0]
  private_rt_ids   = module.network.private_route_table_ids
  vpc_name         = module.network.vpc_name
}



module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.network.vpc_id
  tags   = var.tags
}

module "openproject" {
  source             = "./modules/ec2"
  key_name           = var.key_name
  ami_name           = var.ami_id
  sg_id              = module.security_groups.web_sg_id
  vpc_name           = module.network.vpc_name
  public_subnets     = module.network.public_subnets_id[0]
  instance_type      = var.instance_type
  project_name       = "demo-instance-openproject"

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt-get install -y docker.io
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo docker run -d -p 80:80 -e OPENPROJECT_SECRET_KEY_BASE=secret -e OPENPROJECT_HTTPS=false openproject/openproject:15.4.1
                EOF
}



module "alb" {
  source                = "./modules/alb"
  name                  = "web-lb"
  security_group_id     = module.security_groups.web_sg_id
  subnet_ids            = module.network.public_subnets_id
  target_group_name     = "web-target-group"
  target_group_port     = 80
  target_group_protocol = "HTTP"
  vpc_id                = module.network.vpc_id
  health_check_path     = "/"
  health_check_protocol = "HTTP"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 2
  listener_port         = 80
  listener_protocol     = "HTTP"
  target_ids            = module.openproject.instance_id
  tags                  = var.tags
}
