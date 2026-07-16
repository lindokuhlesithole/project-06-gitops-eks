output "api_url" {
  value = "${aws_api_gateway_deployment.portal.invoke_url}/api"
}
