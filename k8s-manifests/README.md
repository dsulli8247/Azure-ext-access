# Kubernetes Manifests for AKS Cluster

This directory contains Kubernetes manifests to deploy applications to the AKS cluster in the DMZ.

## Hello World Application

The `hello-world.yaml` manifest deploys a sample "Hello World" application to demonstrate the AKS cluster functionality.

### Application Components

- **Deployment**: Runs 3 replicas of the hello-world container
- **Service**: Exposes the application using a LoadBalancer service type
- **Image**: Uses Microsoft's sample hello-world image from Azure Container Registry

### Deploying the Application

After the AKS cluster is deployed, you can deploy the Hello World app using:

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-hub-spoke-network --name aks-dmz-cluster

# Deploy the application
kubectl apply -f k8s-manifests/hello-world.yaml

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Get the external IP address (may take a few minutes to provision)
kubectl get service hello-world --watch
```

### Accessing the Application

Once the LoadBalancer service has been assigned an external IP address, you can access the application at:

```
http://<EXTERNAL-IP>
```

The application will display a "Hello World from Azure Kubernetes Service in DMZ!" message.

### Application Gateway Integration (Optional)

To route traffic through the Application Gateway WAF instead of directly to the LoadBalancer:

1. Change the Service type from `LoadBalancer` to `ClusterIP`
2. Configure the Application Gateway backend pool to point to the service's cluster IP
3. Update Application Gateway health probes and routing rules

### Cleanup

To remove the Hello World application:

```bash
kubectl delete -f k8s-manifests/hello-world.yaml
```
