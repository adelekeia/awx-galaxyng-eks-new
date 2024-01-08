---

apiVersion: repo-manager.pulpproject.org/v1beta2
kind: Pulp
metadata:
  name: ${galaxy_ng_instance}
  namespace: pulp
spec:
  deployment_type: galaxy
  image: quay.io/pulp/galaxy-minimal
  image_version: 4.9.0
  image_web: quay.io/pulp/galaxy-web
  image_web_version: 4.9.0
  # no_log: false
  #admin_password_secret: "example-pulp-admin-password"
  #signing_secret: "signing-galaxy"
  #signing_scripts: "signing-scripts"
  ingress_type: nodeport
  nodeport_port: 30000
  # k3s local-path requires this
  #file_storage_access_mode: "ReadWriteMany"
  # We have a little over 10GB free on GHA VMs/instances
  #file_storage_size: "10Gi"
  #file_storage_storage_class: efs1
  pvc: efs-claim
  pulp_settings:
    token_server: http://${lb_hostname}/token/
    content_origin: http://${lb_hostname}
    ansible_api_hostname: http://${lb_hostname}
    api_root: "/api/galaxy/pulp/"
    allowed_export_paths:
      - /tmp
    allowed_import_paths:
      - /tmp
    analytics: false
    galaxy_feature_flags:
      execution_environments: True
      ai_deny_index: True
  database:
  # postgres_storage_class: standard
    external_db_secret: external-database
  unmanaged: ${unmanaged_flag}
  api:
    replicas: 1
  content:
    replicas: 1
    resource_requirements:
      requests:
        cpu: 150m
        memory: 256Mi
      limits:
        cpu: 800m
        memory: 1Gi
  worker:
    replicas: 1
    resource_requirements:
      requests:
        cpu: 150m
        memory: 256Mi
      limits:
        cpu: 800m
        memory: 1Gi
  web:
    replicas: 1
    resource_requirements:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 800m
        memory: 1Gi