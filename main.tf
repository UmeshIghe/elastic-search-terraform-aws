#basic setup
resource "aws_vpc" "elastic_vpc" {
  cidr_block = cidrsubnet("172.20.0.0/16", 0, 0)
  tags = {
    Name = "elastic_vpc"
  }
}
resource "aws_internet_gateway" "elastic_internet_gateway" {
  vpc_id = aws_vpc.elastic_vpc.id
  tags = {
    Name = "elastic_igw"
  }
}
resource "aws_route_table" "elastic_rt" {
  vpc_id = aws_vpc.elastic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.elastic_internet_gateway.id
  }
  tags = {
    Name = "elastic_rt"
  }
}
resource "aws_main_route_table_association" "elastic_rt_main" {
  vpc_id         = aws_vpc.elastic_vpc.id
  route_table_id = aws_route_table.elastic_rt.id
}
resource "aws_subnet" "elastic_subnet" {
  for_each          = { us-east-1a = cidrsubnet("172.20.0.0/16", 8, 10), us-east-1b = cidrsubnet("172.20.0.0/16", 8, 20), us-east-1c = cidrsubnet("172.20.0.0/16", 8, 30) }
  vpc_id            = aws_vpc.elastic_vpc.id
  availability_zone = each.key
  cidr_block        = each.value
  tags = {
    Name = "elastic_subnet_${each.key}"
  }
}
variable "az_name" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
#elasticsearch
resource "aws_security_group" "elasticsearch_sg" {
  vpc_id = aws_vpc.elastic_vpc.id
  ingress {
    description = "ingress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }
  ingress {
    description = "ingress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 9200
    protocol    = "tcp"
    to_port     = 9300
  }
  egress {
    description = "egress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
  tags = {
    Name = "elasticsearch_sg"
  }
}

data "aws_key_pair" "elastic_ssh_key" {
  key_name = "terra-hp"

}

resource "aws_instance" "elastic_nodes" {
  count                       = 3
  ami                         = "ami-08e4e35cccc6189f4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.elastic_subnet[var.az_name[count.index]].id
  vpc_security_group_ids      = [aws_security_group.elasticsearch_sg.id]
  key_name                    = data.aws_key_pair.elastic_ssh_key.key_name
  associate_public_ip_address = true
  tags = {
    Name = "elasticsearch_${count.index}"
  }
}
data "template_file" "init_elasticsearch" {
  depends_on = [
    aws_instance.elastic_nodes
  ]
  count    = 3
  template = file("./elasticsearch_config.tpl")
  vars = {
    cluster_name = "cluster1"
    node_name    = "node_${count.index}"
    node         = aws_instance.elastic_nodes[count.index].private_ip
    node1        = aws_instance.elastic_nodes[0].private_ip
    node2        = aws_instance.elastic_nodes[1].private_ip
    node3        = aws_instance.elastic_nodes[2].private_ip
  }
}
resource "null_resource" "move_elasticsearch_file" {
  count = 3
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("terra-hp.pem")
    host        = aws_instance.elastic_nodes[count.index].public_ip
  }
  provisioner "file" {
    content     = data.template_file.init_elasticsearch[count.index].rendered
    destination = "elasticsearch.yml"
  }
  provisioner "file" {
    source      = "auth.sh"
    destination = "auth.sh"
  }
  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "bootstrap.sh"
  }
}
resource "null_resource" "start_es" {
  depends_on = [
    null_resource.move_elasticsearch_file
  ]
  count = 3
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("terra-hp.pem")
    host        = aws_instance.elastic_nodes[count.index].public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "sudo yum update -y",
      "sudo rpm -i https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.16.3-x86_64.rpm",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable elasticsearch.service",
      "sudo sed -i 's@-Xms1g@-Xms512m@m' /etc/elasticsearch/jvm.options",
      "sudo sed -i 's@-Xmx1g@-Xmx512m@m' /etc/elasticsearch/jvm.options",
      "sudo rm /etc/elasticsearch/elasticsearch.yml",
      "sudo cp elasticsearch.yml /etc/elasticsearch/",
      "sudo cp auth.sh /usr/share/elasticsearch/",
      "sudo cp bootstrap.sh /usr/share/elasticsearch/",
      "cd /usr/share/elasticsearch/",
      "sudo chmod +x auth.sh",
      "sudo chmod +x bootstrap.sh",
      "sudo ./bootstrap.sh",
      "sudo systemctl start elasticsearch.service",
      "echo ${aws_instance.elastic_nodes[count.index].public_ip}",
      "export ip=${aws_instance.elastic_nodes[count.index].public_ip}",
      "./auth.sh"

    ]
  }
}

output "elasticsearch_ip_addr" {
  value = join(":", [aws_instance.elastic_nodes[0].public_ip, "9200"])
}

