output "name" {
  description = "The name of the Fargate profile."
  value       = aws_eks_fargate_profile.fargate_profile.fargate_profile_name
}

output "arn" {
  description = "The ARN of the Fargate profile."
  value       = aws_eks_fargate_profile.fargate_profile.arn
}

output "id" {
  description = "The ID of the Fargate profile."
  value       = aws_eks_fargate_profile.fargate_profile.id
}

output "tags_all" {
  description = "A map of tags assigned to the Fargate profile, including those inherited from the provider default_tags configuration block."
  value       = aws_eks_fargate_profile.fargate_profile.tags_all
}
