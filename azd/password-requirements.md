# Azure VM Password Requirements

When running `azd up`, you'll be prompted for passwords. They must meet these requirements:

## Password Requirements
- **Length**: 6-72 characters
- **Complexity**: Must satisfy at least 3 of the following:
  1. Contains an uppercase character (A-Z)
  2. Contains a lowercase character (a-z)
  3. Contains a numeric digit (0-9)
  4. Contains a special character (!@#$%^&*()_+-=[]{}|;':\",./<>?)
  5. Control characters are not allowed

## Valid Password Examples
- `OpenInfra2025!` (uppercase, lowercase, digit, special)
- `myPassword123@` (lowercase, uppercase, digit, special)
- `Azure2025#Demo` (uppercase, lowercase, digit, special)

## What Changed
- Removed hardcoded passwords from `.env` file
- Cleared password environment variables with `azd env set`
- Now `azd up` will prompt for passwords each time, ensuring they reset

## Usage
When you run `azd up`, you'll be prompted to enter:
1. `ADMIN_PASSWORD` - Password for VM admin user
2. `BASTION_PASSWORD` - Password for bastion host

Enter secure passwords that meet the complexity requirements above.
