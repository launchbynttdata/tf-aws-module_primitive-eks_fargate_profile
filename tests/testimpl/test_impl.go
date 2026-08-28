package testimpl

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/eks"
	ekstypes "github.com/aws/aws-sdk-go-v2/service/eks/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	testTypes "github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestComposableComplete(t *testing.T, ctx testTypes.TestContext) {
	eksClient := GetAWSEKSClient(t)
	terraformOptions := ctx.TerratestTerraformOptions()

	clusterName := terraform.OutputContext(t, context.Background(), terraformOptions, "cluster_name")
	profileName := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_name")
	profileArn := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_arn")
	profileID := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_id")
	profileTags := terraform.OutputMapContext(t, context.Background(), terraformOptions, "fargate_profile_tags_all")

	require.NotEmpty(t, clusterName, "Terraform output cluster_name should not be empty")
	require.NotEmpty(t, profileName, "Terraform output fargate_profile_name should not be empty")
	require.NotEmpty(t, profileArn, "Terraform output fargate_profile_arn should not be empty")
	require.NotEmpty(t, profileID, "Terraform output fargate_profile_id should not be empty")

	describeOutput := describeFargateProfile(t, eksClient, clusterName, profileName)
	require.NotNil(t, describeOutput, "DescribeFargateProfile response should not be nil")
	require.NotNil(t, describeOutput.FargateProfile, "Fargate profile details should be present in DescribeFargateProfile response")

	fargateProfile := describeOutput.FargateProfile

	t.Run("TestFargateProfileAttributes", func(t *testing.T) {
		assert.Equal(t, clusterName, aws.ToString(fargateProfile.ClusterName), "Cluster name should match Terraform output")
		assert.Equal(t, profileName, aws.ToString(fargateProfile.FargateProfileName), "Fargate profile name should match Terraform output")
		assert.Equal(t, profileArn, aws.ToString(fargateProfile.FargateProfileArn), "Fargate profile ARN should match Terraform output")
		assert.Equal(t, buildFargateProfileID(clusterName, profileName), profileID, "Fargate profile ID should follow clusterName:profileName format")
		assert.Equal(t, ekstypes.FargateProfileStatusActive, fargateProfile.Status, "Fargate profile should be Active")
		assert.NotEmpty(t, aws.ToString(fargateProfile.PodExecutionRoleArn), "Fargate profile should include a pod execution role ARN")
		assert.NotEmpty(t, fargateProfile.Subnets, "Fargate profile should be associated with at least one subnet")
		assert.NotEmpty(t, fargateProfile.Selectors, "Fargate profile should have at least one selector defined")
	})

	t.Run("TestFargateProfileTags", func(t *testing.T) {
		require.NotEmpty(t, profileTags, "Terraform output fargate_profile_tags_all should not be empty")
		assert.Equal(t, profileTags, fargateProfile.Tags, "Fargate profile tags should match tags applied via Terraform")
	})
}

// TestComposableCompleteReadonly performs read-only verification of the EKS Fargate profile.
// It verifies Terraform outputs and AWS API state without any write operations.
func TestComposableCompleteReadonly(t *testing.T, ctx testTypes.TestContext) {
	eksClient := GetAWSEKSClient(t)
	terraformOptions := ctx.TerratestTerraformOptions()

	clusterName := terraform.OutputContext(t, context.Background(), terraformOptions, "cluster_name")
	profileName := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_name")
	profileArn := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_arn")
	profileID := terraform.OutputContext(t, context.Background(), terraformOptions, "fargate_profile_id")
	profileTags := terraform.OutputMapContext(t, context.Background(), terraformOptions, "fargate_profile_tags_all")

	require.NotEmpty(t, clusterName, "Terraform output cluster_name should not be empty")
	require.NotEmpty(t, profileName, "Terraform output fargate_profile_name should not be empty")
	require.NotEmpty(t, profileArn, "Terraform output fargate_profile_arn should not be empty")
	require.NotEmpty(t, profileID, "Terraform output fargate_profile_id should not be empty")

	describeOutput := describeFargateProfile(t, eksClient, clusterName, profileName)
	require.NotNil(t, describeOutput, "DescribeFargateProfile response should not be nil")
	require.NotNil(t, describeOutput.FargateProfile, "Fargate profile details should be present in DescribeFargateProfile response")

	fargateProfile := describeOutput.FargateProfile

	t.Run("TestFargateProfileAttributesReadonly", func(t *testing.T) {
		assert.Equal(t, clusterName, aws.ToString(fargateProfile.ClusterName), "Cluster name should match Terraform output")
		assert.Equal(t, profileName, aws.ToString(fargateProfile.FargateProfileName), "Fargate profile name should match Terraform output")
		assert.Equal(t, profileArn, aws.ToString(fargateProfile.FargateProfileArn), "Fargate profile ARN should match Terraform output")
		assert.Equal(t, buildFargateProfileID(clusterName, profileName), profileID, "Fargate profile ID should follow clusterName:profileName format")
		assert.Equal(t, ekstypes.FargateProfileStatusActive, fargateProfile.Status, "Fargate profile should be Active")
		assert.NotEmpty(t, aws.ToString(fargateProfile.PodExecutionRoleArn), "Fargate profile should include a pod execution role ARN")
		assert.NotEmpty(t, fargateProfile.Subnets, "Fargate profile should be associated with at least one subnet")
		assert.NotEmpty(t, fargateProfile.Selectors, "Fargate profile should have at least one selector defined")
	})

	t.Run("TestFargateProfileTagsReadonly", func(t *testing.T) {
		require.NotEmpty(t, profileTags, "Terraform output fargate_profile_tags_all should not be empty")
		assert.Equal(t, profileTags, fargateProfile.Tags, "Fargate profile tags should match tags applied via Terraform")
	})
}

func describeFargateProfile(t *testing.T, eksClient *eks.Client, clusterName, profileName string) *eks.DescribeFargateProfileOutput {
	output, err := eksClient.DescribeFargateProfile(context.TODO(), &eks.DescribeFargateProfileInput{
		ClusterName:        aws.String(clusterName),
		FargateProfileName: aws.String(profileName),
	})
	require.NoError(t, err, "failed to describe Fargate profile from AWS")
	return output
}

func buildFargateProfileID(clusterName, profileName string) string {
	return clusterName + ":" + profileName
}

func GetAWSEKSClient(t *testing.T) *eks.Client {
	return eks.NewFromConfig(GetAWSConfig(t))
}

func GetAWSConfig(t *testing.T) (cfg aws.Config) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoErrorf(t, err, "unable to load SDK config, %v", err)
	return cfg
}
