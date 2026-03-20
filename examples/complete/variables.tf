############################
# Variables - Simple Example
############################

variable "resource_names_map" {
  description = "A map of key to resource_name that will be used by tf-launch-module_library-resource_name to generate resource names"
  type = map(object({
    name       = string
    max_length = optional(number, 60)
  }))

  default = {
    iam_role = {
      name       = "iam"
      max_length = 64
    }
    vpc = {
      name       = "vpc"
      max_length = 64
    }
    subnet = {
      name       = "snet"
      max_length = 80
    }
    eks = {
      name       = "eks"
      max_length = 100
    }
    fargateprofile = {
      name       = "fargateprofile"
      max_length = 100
    }
    fargaterole = {
      name       = "eksfargatero"
      max_length = 64
    }
  }
}

variable "instance_env" {
  description = "Number that represents the instance of the environment"
  type        = number
  default     = 0
}

variable "instance_resource" {
  description = "Number that represents the instance of the resource"
  type        = number
  default     = 0
}

variable "logical_product_family" {
  description = "Logical product family name"
  type        = string
  default     = "launch"
}

variable "logical_product_service" {
  description = "Logical product service name"
  type        = string
  default     = "eks"
}

variable "class_env" {
  description = "Environment class (e.g., dev, qa, prod)"
  type        = string
  default     = "sandbox"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "assume_role_policy" {
  description = "IAM assume role policy statements to include in the trust policy."
  type = list(object({
    sid     = optional(string)
    effect  = optional(string, "Allow")
    actions = list(string)

    # each statement may have multiple principal blocks
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))

    conditions = optional(list(object({
      test     = string       # e.g., "StringEquals"
      variable = string       # e.g., "aws:PrincipalTag/Team"
      values   = list(string) # e.g., ["DevOps"]
    })))
  }))
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_1_cidr" {
  description = "CIDR block for subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_2_cidr" {
  description = "CIDR block for subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "selector" {
  description = "A list of selectors to match pods for this Fargate profile."
  type = map(object({
    namespace = string
    labels    = optional(map(string))
  }))
  default = {}
}

variable "fargate_pod_execution_assume_role_policy" {
  description = "IAM assume role policy statements for the Fargate pod execution role."
  type = list(object({
    sid     = optional(string)
    effect  = optional(string, "Allow")
    actions = list(string)

    # each statement may have multiple principal blocks
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))

    conditions = optional(list(object({
      test     = string       # e.g., "StringEquals"
      variable = string       # e.g., "aws:PrincipalTag/Team"
      values   = list(string) # e.g., ["DevOps"]
    })))
  }))
  default = []
}
