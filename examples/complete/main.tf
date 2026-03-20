############################
# Simple EKS Cluster Example
# Balanced configuration for integration testing
############################

module "resource_names" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 2.0"

  for_each = var.resource_names_map

  logical_product_family  = var.logical_product_family
  logical_product_service = var.logical_product_service
  region                  = var.region
  class_env               = var.class_env
  cloud_resource_type     = each.value.name
  instance_env            = var.instance_env
  maximum_length          = each.value.max_length
  instance_resource       = var.instance_resource
}

# Use Launch primitive module for IAM role
module "eks_service_role" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version = "~> 0.1"

  name               = module.resource_names["iam_role"].minimal_random_suffix_without_any_separators
  assume_role_policy = var.assume_role_policy
  tags               = var.tags
}

# Use Launch primitive module for policy attachments
module "eks_cluster_policy" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws"
  version = "~> 0.1"

  role_name  = module.eks_service_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

module "eks_vpc_resource_controller_policy" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws"
  version = "~> 0.1"

  role_name  = module.eks_service_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

module "eks_fargate_pod_execution_role" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version = "~> 0.1"

  name               = module.resource_names["fargaterole"].minimal
  assume_role_policy = var.fargate_pod_execution_assume_role_policy
  tags               = var.tags
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Use Launch primitive module for VPC
module "vpc" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/vpc/aws"
  version = "~> 1.0"

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = module.resource_names["vpc"].minimal_random_suffix_without_any_separators
  })
}

# Use Launch primitive modules for subnets
module "subnet_1" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/subnet/aws"
  version = "~> 1.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = var.subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = module.resource_names["subnet"].minimal_random_suffix_without_any_separators
  })
}

module "subnet_2" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/subnet/aws"
  version = "~> 1.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = var.subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = module.resource_names["subnet"].minimal_random_suffix_without_any_separators
  })
}

# Configure default security group to deny all traffic
resource "aws_default_security_group" "default" {
  vpc_id = module.vpc.vpc_id

  tags = merge(var.tags, {
    Name = "${module.resource_names["vpc"].standard}-default-sg"
  })
}

# Use the primitive EKS cluster module
module "eks_cluster" {
  # checkov:skip=CKV_TF_1: trusted module source
  source  = "terraform.registry.launch.nttdata.com/module_primitive/eks_cluster/aws"
  version = "~> 0.1"

  name               = module.resource_names["eks"].minimal_random_suffix_without_any_separators
  role_arn           = module.eks_service_role.role_arn
  kubernetes_version = var.kubernetes_version

  enabled_cluster_log_types = ["api", "audit"]

  vpc_config = {
    subnet_ids              = [module.subnet_1.subnet_id, module.subnet_2.subnet_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = var.tags

  depends_on = [
    module.eks_cluster_policy,
    module.eks_vpc_resource_controller_policy
  ]
}

module "fargate_profile" {
  source                 = "../../"
  cluster_name           = module.resource_names["eks"].minimal_random_suffix_without_any_separators
  fargate_profile_name   = module.resource_names["fargateprofile"].minimal_random_suffix_without_any_separators
  pod_execution_role_arn = module.eks_fargate_pod_execution_role.role_arn
  subnet_ids = [
    module.subnet_1.subnet_id,
    module.subnet_2.subnet_id
  ]
  selector   = var.selector
  tags       = local.tags
  depends_on = [module.eks_cluster]
}
