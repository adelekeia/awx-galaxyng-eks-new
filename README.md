# AWX and Galaxy NG Setup On EKS

This terraform code will create an EKS cluster and an instance of RDS for PostgreSQL and deploy AWX and Galaxy NG on it. Then it exposes the applications through load balancers and print the connection details and user credentials.

To run it:

* Switch to cluster directory and initialize terraform    
    ```
    terraform init
    ```

* Run terraform and apply changes
    ```
    terraform apply -auto-approve
    ```

Terraform should output the connection details and user credentials for both AWX and Galaxy NG. The URL might not be available right away so you might have to wait a few minutes for the login page to come up for the first time.