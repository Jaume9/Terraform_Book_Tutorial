# Terraform: Up & Running Code

This repo contains the code samples for the book *[Terraform: Up and Running](http://www.terraformupandrunning.com)*, 
by [Yevgeniy Brikman](http://www.ybrikman.com).




## Looking for the 1st, 2nd, or 3rd edition?

*Terraform: Up & Running* is now on its **3rd edition**; all the code in `master` is for this edition. If you're looking
for code examples for other editions, please see the following branches:

* [1st-edition branch](https://github.com/brikis98/terraform-up-and-running-code/tree/1st-edition).
* [2nd-edition branch](https://github.com/brikis98/terraform-up-and-running-code/tree/2nd-edition).
* [3rd-edition branch](https://github.com/brikis98/terraform-up-and-running-code/tree/3rd-edition).



## Quick start

All the code is in the [code](/code) folder. The code examples are organized first by the tool or language and then
by chapter. For example, if you're looking at an example of Terraform code in Chapter 2, you'll find it in the 
[code/terraform/02-intro-to-terraform-syntax](code/terraform/02-intro-to-terraform-syntax) folder; if you're looking at 
an OPA (Rego) example in Chapter 9, you'll find it in the 
[code/opa/09-testing-terraform-code](code/opa/09-testing-terraform-code) folder.

Since this code comes from a book about Terraform, the vast majority of the code consists of Terraform examples in the 
[code/terraform](/code/terraform) folder.

For instructions on running the code, please consult the README in each folder, and, of course, the
*[Terraform: Up and Running](http://www.terraformupandrunning.com)* book.

## 1 use cmd variable entorno

 $env:PATH += ';C:\Users\pe2756\terraform_1.14.7_windows_386'


## AWS Credentials Configuration (Persistent)

To use Terraform with AWS, you need to configure your AWS credentials. This section explains how to set up persistent AWS credentials that will work across all PowerShell sessions and survive computer restarts.

### Option 1: AWS Credentials File (Recommended)

This is the standard way to configure AWS credentials and works with all AWS tools and SDKs.

#### Step 1: Create the AWS Configuration Directory

Open PowerShell and run:

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.aws" -Force
```

This creates the `C:\Users\<YourUsername>\.aws` directory where AWS tools look for credentials.

#### Step 2: Create the Credentials File

Run the following PowerShell command to create the credentials file without BOM (important for Terraform compatibility):

```powershell
$content = '[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$env:USERPROFILE\.aws\credentials", $content, $utf8NoBom)
```

Replace `YOUR_ACCESS_KEY_ID` and `YOUR_SECRET_ACCESS_KEY` with your actual AWS credentials.

#### Step 3: Create the Config File (Optional but Recommended)

```powershell
$content = '[default]
region = us-east-1
output = json'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$env:USERPROFILE\.aws\config", $content, $utf8NoBom)
```

Change `us-east-1` to your preferred AWS region.

#### Step 4: Verify the Configuration

Test that your credentials are set up correctly:

```powershell
# List the contents of the credentials file
Get-Content "$env:USERPROFILE\.aws\credentials"

# List the contents of the config file
Get-Content "$env:USERPROFILE\.aws\config"
```

#### Step 5: Verify Terraform Can Access the Credentials

Navigate to any Terraform folder and run:

```bash
terraform init -backend=false
terraform validate
```

If successful, you'll see "Success! The configuration is valid."

### Important Notes

* **File Encoding:** The credentials file must be saved as UTF-8 **without BOM** (Byte Order Mark). The PowerShell commands above handle this automatically.
* **Sensitive Data:** Keep your credentials file private. Never commit it to version control or share it with others.
* **Multiple Profiles:** You can add multiple profiles to your credentials file for different AWS accounts:

```ini
[default]
aws_access_key_id = YOUR_DEFAULT_ACCESS_KEY
aws_secret_access_key = YOUR_DEFAULT_SECRET_KEY

[production]
aws_access_key_id = YOUR_PROD_ACCESS_KEY
aws_secret_access_key = YOUR_PROD_SECRET_KEY
```

Then specify which profile to use in your Terraform code:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "production"
}
```

* **Persistence:** Once configured, these credentials are persistent and will:
  * Work across all PowerShell sessions
  * Survive computer restarts
  * Be available to Terraform, AWS CLI, and other AWS tools automatically



## License

This code is released under the MIT License. See LICENSE.txt.