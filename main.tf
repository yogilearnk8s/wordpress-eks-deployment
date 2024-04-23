provider "aws" {
  region     = "ap-south-1"
}

terraform {
  backend "s3" {
    bucket = "yogi-tf"
    key    = "terraform-backend/wordpress-eks-deployment.tf"
    region = "ap-south-1"
  }
}

locals {
  name   = "Sandbox-EKSCluster9"
  region = "ap-south-1"

 
  azs      = slice(data.aws_availability_zones.yogi-az.names, 0, 3)

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

data "aws_eks_cluster_auth" "default" {
  name = local.name
  #name = module.eks_cluster_creation.cluster_name
}


data "aws_vpc" "yogi-vpc"{

filter {
 name = "tag:Name"
 values = ["Yogi-VPC-DevOps"]
}
}

data "aws_availability_zones" "yogi-az" {
  state = "available"
}

resource "null_resource" "kubectl" {
    provisioner "local-exec" {
        command = "aws eks --region ap-south-1 update-kubeconfig --name ${local.name}"
    }
	
}


module "wordpress_db_deployment"{
  source = "./eks_wordpress_db_deployment"
  
}

module "wordpress_app_deployment"{
  source = "./eks_wordpress_app_deployment"
  depends_on = [module.wordpress_db_deployment]
}
