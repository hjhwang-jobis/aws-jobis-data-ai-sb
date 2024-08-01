output "vpc_peering_id" {
  value = aws_vpc_peering_connection.data-ai-us-west-2-peer.id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
