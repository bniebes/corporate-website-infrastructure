variable "sub_regions" {
  type        = set(string)
  nullable    = false
  description = "Active sub regions"
}

variable "ecr_force_delete" {
  type        = bool
  default     = false
  description = "AWS ECR force delete"
}

variable "domain_name" {
  type        = string
  description = "Root domain name"
}

variable "initial_deployment" {
  type        = bool
  default     = false
  description = "Initial deployment of ressources"
}

variable "image_name" {
  type    = string
  default = "corporate-website"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "port" {
  type    = number
  default = 30123
}
variable "instance_cpu" {
  type        = string
  default     = "1 vCPU"
  description = "App Runner Instance CPU"
}

variable "instance_memory" {
  type        = string
  default     = "0.5 GB"
  description = "App Runner Instance Memory"
}

variable "auto_scaling_max_concurrency" {
  type        = number
  default     = 100
  description = "App Runner Auto Scaling Max Concurrency. (Number of Concurrent requests)"
}

variable "auto_scaling_max_size" {
  type        = number
  default     = 10
  description = "App Runner Auto Scaling Max Size"
}

variable "auto_scaling_min_size" {
  type        = number
  default     = 1
  description = "App Runner Auto Scaling Min Size"
}

