# in this code, we show how terraform know what api calls to do to create the infrastructure, and how it can manage the dependencies between resources.
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"  
}

resource "google_dns_record_set" "a" {
    name         = "example.com."
    type         = "A"
    ttl          = 300
    managed_zone    = "example-zone"
    rrdatas      = [aws_instance.example.public_ip]
  
}