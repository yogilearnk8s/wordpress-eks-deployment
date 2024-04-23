provider "aws" {
  region     = "ap-south-1"
}

data "terraform_remote_state" "eks-cluster-info" {
  backend = "s3"
  config = {
    bucket               = "yogi-tf"
    #workspace_key_prefix = "terraform-backend/eks-wordpress-cluster.tf"
    key                  = "terraform-backend/eks-wordpress-cluster.tf"
    region               = "ap-south-1"
  }
}

data "aws_eks_cluster_auth" "default" {
  name = local.name
  #name = module.eks_cluster_creation.cluster_name
}

data "aws_eks_cluster" "eks-cluster" {
  name = local.name
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

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks-cluster-info.outputs.eks_cluster_creation.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks-cluster-info.outputs.eks_cluster_creation.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.default.token
}

terraform {
  backend "s3" {
    bucket = "yogi-tf"
    key    = "terraform-backend/wordpress-eks-deployment.tf"
    region = "ap-south-1"
  }
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
