variable "ssh_ip_address" {
  type = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.ssh_ip_address))
    error_message = "The value of ssh_ip_address must be a valid IP address"
  }
}
