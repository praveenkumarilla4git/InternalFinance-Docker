variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  description = "Name of your existing EC2 Key Pair (without .pem)"
  default     = "batch3"  # <--- REPLACE THIS
}

variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true  # This hides it from logs
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}