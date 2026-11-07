resource "kind_cluster" "default" {
  name           = "terraform-learn"
  wait_for_ready = true
}