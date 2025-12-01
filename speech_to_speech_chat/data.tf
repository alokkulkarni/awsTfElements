data "terraform_remote_state" "live_chat" {
  backend = "s3"
  config = {
    bucket = "live-chat-content-moderation-tf-state-bucket"
    key    = "terraform.tfstate"
    region = "eu-west-2"
  }
}
