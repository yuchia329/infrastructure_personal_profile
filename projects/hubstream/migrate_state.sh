#!/bin/bash
# Move state files to HubStream project
mv ../../terraform.tfstate . 2>/dev/null || true
mv ../../terraform.tfstate.backup . 2>/dev/null || true
mv ../../.terraform . 2>/dev/null || true
mv ../../.terraform.lock.hcl . 2>/dev/null || true

echo "Migrating state to modular structure..."

# Run init to ensure correct providers
terraform init

# Array of all resources to migrate
RESOURCES=(
  "aws_vpc.main"
  "aws_subnet.public"
  "aws_internet_gateway.main"
  "aws_route_table.public"
  "aws_route_table_association.public"
  "aws_security_group.app"
  "aws_eip.app"
  "aws_eip_association.app"
  "cloudflare_record.app"
  "tls_private_key.hubstream_key"
  "aws_key_pair.hubstream"
  "local_sensitive_file.private_key"
  "aws_iam_role.ec2_ssm_role"
  "aws_iam_role_policy_attachment.ssm_core"
  "aws_iam_instance_profile.ec2_ssm_profile"
  "aws_iam_openid_connect_provider.github"
  "aws_iam_role.github_actions_role"
  "aws_iam_policy.github_ssm_policy"
  "aws_iam_role_policy_attachment.github_ssm_attach"
  "aws_instance.app"
)

# Move each resource into the core_cluster module
for res in "${RESOURCES[@]}"; do
  terraform state mv "$res" "module.core_cluster.$res" || true
done

echo ""
echo "State Migration Complete! Run 'terraform plan' to verify everything is in sync."
