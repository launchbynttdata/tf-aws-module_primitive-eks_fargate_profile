# tf-aws-module_primitive-eks_fargate_profile

Terraform primitive module for the [aws_eks_fargate_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) resource.

## Overview

This module wraps a single AWS EKS Fargate profile resource. Fargate profiles define which pods run on Fargate by specifying pod selectors (namespace and optional labels). Subnets must be tagged with `kubernetes.io/cluster/CLUSTER_NAME` for Fargate to use them.

## Features

- Single resource wrapper for `aws_eks_fargate_profile`
- Configurable selectors (namespace and labels)
- Tag support
- Full output passthrough for composition

## Usage

```hcl
module "fargate_profile" {
  source = "terraform.registry.launch.nttdata.com/module_primitive/eks_fargate_profile/aws"
  version = "~> 0.1"

  cluster_name           = var.cluster_name
  fargate_profile_name   = var.fargate_profile_name
  pod_execution_role_arn = var.pod_execution_role_arn
  subnet_ids             = var.subnet_ids
  selector               = var.selector
  tags                   = var.tags
}
```

## Requirements

- EKS cluster must exist
- Pod execution role must have `AmazonEKSFargatePodExecutionRolePolicy` attached
- Subnets must have the tag `kubernetes.io/cluster/<cluster_name>` (shared or owned)

## Related Modules

- [tf-aws-module_primitive-eks_cluster](https://github.com/launchbynttdata/tf-aws-module_primitive-eks_cluster)
- [tf-aws-module_primitive-iam_role](https://github.com/launchbynttdata/tf-aws-module_primitive-iam_role)

## Contributing

- Pass `make check` validation
- Follow naming conventions
- Include clear documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.100 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_fargate_profile.fargate_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the EKS cluster. | `string` | n/a | yes |
| <a name="input_fargate_profile_name"></a> [fargate\_profile\_name](#input\_fargate\_profile\_name) | The name of the Fargate profile. | `string` | n/a | yes |
| <a name="input_pod_execution_role_arn"></a> [pod\_execution\_role\_arn](#input\_pod\_execution\_role\_arn) | The ARN of the IAM role that provides permissions for pods running on Fargate. | `string` | n/a | yes |
| <a name="input_selector"></a> [selector](#input\_selector) | A list of selectors to match pods for this Fargate profile. | <pre>map(object({<br/>    namespace = string<br/>    labels    = optional(map(string))<br/>  }))</pre> | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to associate with the Fargate profile. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the Fargate profile. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | The name of the Fargate profile. |
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the Fargate profile. |
| <a name="output_id"></a> [id](#output\_id) | The ID of the Fargate profile. |
| <a name="output_tags_all"></a> [tags\_all](#output\_tags\_all) | A map of tags assigned to the Fargate profile, including those inherited from the provider default\_tags configuration block. |
<!-- END_TF_DOCS -->
