variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "fargate_profile_name" {
  description = "The name of the Fargate profile."
  type        = string
}

variable "pod_execution_role_arn" {
  description = "The ARN of the IAM role that provides permissions for pods running on Fargate."
  type        = string
}

variable "selector" {
  description = "A list of selectors to match pods for this Fargate profile."
  type = map(object({
    namespace = string
    labels    = optional(map(string))
  }))
}

variable "subnet_ids" {
  description = "A list of subnet IDs to associate with the Fargate profile."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to assign to the Fargate profile."
  type        = map(string)
  default     = {}
}
