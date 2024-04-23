variable "public-subnet-cidr" {
 description = "Update the CIDR block ranges for public subnets"
 default = ["10.0.4.0/24","10.0.5.0/24","10.0.6.0/24"]
 type = list
}

variable "public-subnet-cidr1" {
 description = "Update the CIDR block ranges for private subnets"
 default = ["10.0.8.0/24","10.0.9.0/24","10.0.10.0/24"]
 type = list
}

variable "eks-cluster-name" {
 description = "EKS Cluster Name"
 default = "sandbox-eks-cluster1"
}

