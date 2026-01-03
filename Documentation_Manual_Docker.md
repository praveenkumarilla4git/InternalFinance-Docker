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
  default     = "batch3"  # <--- REPLACE THIS IF NEEDED
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
  ami           = "ami-068c0051b15cdb816" # Amazon Linux 2023 (US-East-1)
  instance_type = "t3.micro"
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
Make sure we include the .gitignore file properly
*.pem
Ops-Infra/.terraform/
*.tfstate
finance.db
Ops-Infra/batch3.pem

Now we need to do common steps:
git init
git add .
git branch -m main
git add remote add origin https://github.com/praveenkumarilla4git/InternalFinance-Docker.git
git push -u origin main

Phase 4: Launch Infrastructure (Terraform Execution)
Location: On your Laptop (VS Code Terminal)
Now that your code is on GitHub, let's create the AWS Server that will run it.

1. Open Terminal in VS Code.

2. Move to the Infra folder:

cd Ops-Infra

3. Initialize Terraform: (Downloads the AWS plugins)
terraform init
terraform validate

4. Create the Server:
terraform apply -auto-approve

Error: No valid credential sources found
│
│   with provider["registry.terraform.io/hashicorp/aws"],
│   on main.tf line 1, in provider "aws":
│    1: provider "aws" {
│
│ Please see https://registry.terraform.io/providers/hashicorp/aws
│ for more information about providing credentials.
│
│ Error: failed to refresh cached credentials, no EC2 IMDS role found, operation error ec2imds: GetMetadata, exceeded maximum       
│ number of attempts, 3, request send failed, Get "http://169.254.169.254/latest/meta-data/iam/security-credentials/": dial tcp     
│ 169.254.169.254:80: connectex: A socket operation was attempted to an unreachable network.
│

when we run into this we need to provide aws access token 
$Env:AWS_ACCESS_KEY_ID=
$Env:AWS_SECRET_ACCESS_KEY=
$Env:AWS_DEFAULT_REGION=

So instead of giving these access token everytime it would be better if we provide them in the terraform.tfvars file inside the project but we should make sure it is added into .gitignore

Step 1: Update variables.tf
You need to tell Terraform that it should expect two new variables (Access Key and Secret Key). Add these lines to your existing Ops-Infra/variables.tf file:
# Add these to Ops-Infra/variables.tf

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

Step 2: Update main.tf
Now, update the provider "aws" block in Ops-Infra/main.tf to actually use those variables.

Terraform

# Update the provider block in Ops-Infra/main.tf

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key  # <--- NEW
  secret_key = var.aws_secret_key  # <--- NEW
}

We need to update in variables.tf
variables.tf takes the original values from terraform.tfvars
so in logs we will not see the exact access token values;

Step 3: Create the terraform.tfvars file
Create a new file inside your Ops-Infra folder named exactly terraform.tfvars. Paste your actual AWS keys here.

# Ops-Infra/terraform.tfvars

aws_access_key = "AKIA................"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiVYEXAMPLEKEY"

Step 4: 🚨 FINAL SECURITY CHECK
Before you do anything else, run git status in your terminal.

If you see terraform.tfvars in GREEN or RED: STOP. Do not commit. Add *.tfvars to your .gitignore file immediately.

If you do NOT see terraform.tfvars: You are safe! Git is ignoring the file, but Terraform can still read it locally.

Make sure chmod 400 applied on batch3.pem (your ssh key)
After updating the respective files we can do the terraform apply


Phase 5: Deploy Application (Inside the Server)
We are now having one ec2 instance 

1. Connect to your Server Open your terminal (PowerShell or Git Bash) where your .pem key file is located and run:
if we now login to ssh -i batch3 ec2-user@<YOUR_IP>

2. Verify Installation After waiting, check if the tools are ready:

docker --version

3. Download Your Code Clone your repository (since we pushed the new structure to GitHub):

git clone https://github.com/praveenkumarilla4git/InternalFinance-Docker.git
cd InternalFinance-Docker
make sure the requirements.txt is in main folder
check if requirements.txt is moved to app/ earlier; use below command as needed
mv app/requirements.txt .

4. Build the Docker Image This tells Docker to read your Dockerfile, install Python, and set up your app.

docker build -t finance-app .

This step needs to be success

5. Run the Container This starts your app in the background (-d) and maps the ports (-p).

docker run -d -p 5000:5000 finance-app

6. Verify it is Running

docker ps

Go to your browser on your laptop and visit:
http://34.201.47.69:5000

(You should see a container ID and "0.0.0.0:5000->5000/tcp" under PORTS).
Remember we have defined port as 5000 earlier as well in Dockerfile, main.tf


