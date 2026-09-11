# Load Generator Module: Distributed EC2 Cluster for High-Throughput Stress Testing

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "load_gen" {
  name               = "${var.environment}-load-generator-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.load_gen.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "load_gen" {
  name = "${var.environment}-load-generator-instance-profile"
  role = aws_iam_role.load_gen.name
  tags = var.tags
}

resource "aws_security_group" "load_gen" {
  name        = "${var.environment}-load-generator-sg"
  description = "Security group for distributed k6 load testing fleet"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound HTTPS to API Gateway and AWS Systems Manager"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-load-generator-sg"
    Role = "load-generator"
  })
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e

    sysctl -w net.ipv4.ip_local_port_range="1024 65535"
    sysctl -w net.ipv4.tcp_tw_reuse=1
    sysctl -w net.core.somaxconn=65535

    cat << 'SYSCTL_CONF' >> /etc/sysctl.d/99-k6-tuning.conf
    net.ipv4.ip_local_port_range = 1024 65535
    net.ipv4.tcp_tw_reuse = 1
    net.core.somaxconn = 65535
    SYSCTL_CONF

    cat << 'LIMITS' >> /etc/security/limits.conf
    * soft nofile 65535
    * hard nofile 65535
    root soft nofile 65535
    root hard nofile 65535
    ubuntu soft nofile 65535
    ubuntu hard nofile 65535
    LIMITS

    ulimit -n 65535

    apt-get update -y
    apt-get install -y ca-certificates gnupg curl
    curl -fsSL https://dl.k6.io/key.gpg | gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | tee /etc/apt/sources.list.d/k6.list
    apt-get update -y
    apt-get install -y k6

    cat << 'K6_SCRIPT' > /home/ubuntu/load_test.js
    import http from 'k6/http';
    import { check } from 'k6';

    export const options = {
      vus: 250,
      duration: '60s',
      thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<100'],
      },
    };

    const TEAMS = ['Team Alpha', 'Team Beta', 'Team Gamma', 'Team Delta'];
    const TARGET_URL = __ENV.VOTE_URL || '${var.vote_endpoint}';

    export default function () {
      const randomTeam = TEAMS[Math.floor(Math.random() * TEAMS.length)];
      const payload = JSON.stringify({ team_id: randomTeam, votes: 1 });
      const params = {
        headers: { 'Content-Type': 'application/json' },
        timeout: '5s',
      };

      const res = http.post(TARGET_URL, payload, params);
      check(res, {
        'status is 200 or 202': (r) => r.status === 200 || r.status === 202,
      });
    }
    K6_SCRIPT

    chown ubuntu:ubuntu /home/ubuntu/load_test.js
    chmod 644 /home/ubuntu/load_test.js
  EOF
}

resource "aws_instance" "load_nodes" {
  count                  = var.instance_count
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = length(var.subnet_ids) > 0 ? var.subnet_ids[count.index % length(var.subnet_ids)] : null
  vpc_security_group_ids = [aws_security_group.load_gen.id]
  iam_instance_profile   = aws_iam_instance_profile.load_gen.name

  user_data = local.user_data

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-load-generator-${count.index + 1}"
    Role = "load-generator"
    Tier = "Testing"
  })
}
