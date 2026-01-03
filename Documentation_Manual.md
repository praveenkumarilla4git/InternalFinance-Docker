Operations Manual: InternalFinance-Docker
Objective: Deploy a Python Flask application using Docker and Terraform on AWS EC2. 
OS Version: Amazon Linux 2023 
Author: Praveen

Phase 1: Local Development (On Laptop)
Create a main folder named InternalFinance-Docker. Inside it, create the following structure:
As first step create all the files (empty for now) in the following folder structure

InternalFinance-Docker/        
├── app/
│   ├── core.py
│   ├── main.py
│   ├── schema.py
│   └── templates/
│       └── index.html
├── Ops-Infra/
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
├── .gitignore
├── Dockerfile
└── requirements.txt

1. requirements.txt
Content of requirements.txt file:

Flask

2. app/core.py (Business Logic)
Content of core.py file (python):


def calculate_savings(monthly_amount):
    # Project monthly savings to an annual total
    return monthly_amount * 12
	
3. app/schema.py (Database Setup)
Content of schema.py file (python):


import sqlite3

# Creates DB in the current working directory
connection = sqlite3.connect("finance.db")
cursor = connection.cursor()

# Create table if it doesn't exist
cursor.execute("""
    CREATE TABLE IF NOT EXISTS users_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT,
        estimated_annual REAL,
        reason_text TEXT,
        db_data TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
""")
connection.commit()
connection.close()

4. app/main.py (The Web Server)
Content of main.py file (python):


from flask import Flask, render_template, request
import sqlite3
import core
import schema  # Runs the DB setup immediately

app = Flask(__name__)

@app.route("/", methods=["GET", "POST"])
def home():
    estimated_annual = 0
    current_user = "Praveen"
    reason_text = ""
    
    if request.method == "POST":
        monthly_input = float(request.form.get("monthly_amount"))
        reason_text = request.form.get("reason_goal")
        estimated_annual = core.calculate_savings(monthly_input)

        # Save to DB
        connection = sqlite3.connect("finance.db")
        cursor = connection.cursor()
        cursor.execute("INSERT INTO users_data (user_name, estimated_annual, reason_text) VALUES (?, ?, ?)", 
                       (current_user, estimated_annual, reason_text))
        connection.commit()
        connection.close()

    # Read History
    connection = sqlite3.connect("finance.db")
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM users_data")
    db_data = cursor.fetchall()
    connection.close()

    return render_template("index.html", 
                           user_name=current_user, 
                           money=estimated_annual, 
                           reason=reason_text,
                           history=db_data)

if __name__ == "__main__":
    # HOST 0.0.0.0 IS REQUIRED FOR DOCKER/CLOUD ACCESS
    app.run(debug=True, host="0.0.0.0", port=5000)
	
	
	
5. app/templates/index.html
Content of index.html file (html):


<!DOCTYPE html>
<html>
<head><title>Finance Portal</title></head>
<body style="text-align:center; font-family: sans-serif;">
    <h2>Internal Finance Portal (Docker Edition)</h2>
    <p>Welcome back, <b>{{ user_name }}</b></p>
    <form method="POST">
        Reason / Goal: <input type="text" name="reason_goal" required> <br><br>
        Monthly Amount: <input type="number" name="monthly_amount" required>
        <button type="submit">Calculate</button>
    </form>
    <hr>
    <h3>Savings Projection History</h3>
    <table border="1" style="margin: 0 auto;">
        <tr>
            <th>ID</th>
            <th>Reason</th>
            <th>Annual Projection</th>
        </tr>
        {% for row in history %}
        <tr>
            <td>{{ row[0] }}</td>
            <td>{{ row[3] }}</td>
            <td>{{ row[2] }}</td>
        </tr>
        {% endfor %}
    </table>
</body>
</html>

6. Dockerfile
Dockerfile Content (make sure file name is exact with no extention)


FROM python:3.10-slim

# Set working directory to a clear, named folder
WORKDIR /finance_docker_app

# Copy requirements first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app folder
COPY app/ ./app/

# Switch context to app folder so imports work
WORKDIR /finance_docker_app/app

# Initialize DB
RUN python schema.py

# Open Port 5000
EXPOSE 5000

# Run the App
CMD ["python", "main.py"]




Phase 2: Infrastructure as Code (Terraform)
Create these three files inside the Ops-Infra/ folder.
main.tf, variables.tf, outputs.tf

1. Ops-Infra/variables.tf

variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  description = "Name of your existing EC2 Key Pair (without .pem)"
  default     = "batch3"  # <--- REPLACE THIS F NEEDED
}

2. Ops-Infra/main.tf

provider "aws" {
  region = var.aws_region
}

# --- Security Group ---
resource "aws_security_group" "finance_docker_sg" {
  name        = "finance-docker-sg"
  description = "Allow SSH and Port 5000"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask App"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 Instance ---
resource "aws_instance" "finance_server" {
  ami           = "ami-051f7e7f6c2f40dc1" # Amazon Linux 2023 (US-East-1)
  instance_type = "t2.micro"
  key_name      = var.key_name
  security_groups = [aws_security_group.finance_docker_sg.name]

  tags = {
    Name = "Finance-Docker-Server"
  }

  # AUTOMATED SETUP SCRIPT
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf remove -y podman podman-docker
              dnf install -y docker git
              service docker start
              systemctl enable docker
              usermod -a -G docker ec2-user
              EOF
}

Phase 3: Push to GitHub
Important: Create a NEW repository on GitHub named InternalFinance-Docker before running this.
