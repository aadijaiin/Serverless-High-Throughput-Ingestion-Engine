output "instance_ids" {
  description = "IDs of the load generator EC2 instances"
  value       = aws_instance.load_nodes[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of the load generator EC2 instances"
  value       = aws_instance.load_nodes[*].private_ip
}

output "security_group_id" {
  description = "ID of the load generator security group"
  value       = aws_security_group.load_gen.id
}

output "instance_count" {
  description = "Number of active load generator nodes"
  value       = length(aws_instance.load_nodes)
}
