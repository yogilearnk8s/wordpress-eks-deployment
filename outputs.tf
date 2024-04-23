//output "eks_nodegroup_role" {
//  description = "The ID of the VPC"
//  value       = module.eks_nodegroup_role
//}

output "eks_cluster_creation" {
  description = "Subnets created with CIDR blocks"
  value = module.eks_cluster_creation

}

//output "nodegroup_creation" {
//  description = "internet gateway arn"
//  value = module.nodegroup_creation
//}
