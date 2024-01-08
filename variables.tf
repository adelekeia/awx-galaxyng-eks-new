variable "region" {
  type        = string
}

variable "cluster_name" {
  type        = string
  default     = "awx-cluster"
}

variable "default_tags" {
  description = "Default tags."
  type        = map(string)
}

variable "galaxy_ng_instance" {
  type        = string
  default     = "galaxy-ng"
}