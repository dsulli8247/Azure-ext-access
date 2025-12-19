# Kubernetes Manifests for GKE Cluster

This directory contains Kubernetes manifests to deploy applications to the GKE cluster in the DMZ.

## Hello World Application

The `hello-world.yaml` manifest deploys a sample "Hello World" application to demonstrate the GKE cluster functionality.

### Application Components

- **Deployment**: Runs 3 replicas of the hello-world container
- **Service**: Exposes the application using a LoadBalancer service type
- **Image**: Uses Google's sample hello-app image from Google Container Registry

### Deploying the Application

After the GKE cluster is deployed, you can deploy the Hello World app using:

```bash
# Get GKE credentials
gcloud container clusters get-credentials gke-dmz-cluster --region us-east1 --project <your-project-id>

# Verify connection to cluster
kubectl cluster-info

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

The application will display a "Hello, World!" message along with the hostname and Kubernetes metadata.

### Cloud Load Balancer Integration (Optional)

To route traffic through the Cloud Load Balancer with Cloud Armor instead of directly to the LoadBalancer:

1. Change the Service type from `LoadBalancer` to `ClusterIP` or `NodePort`
2. Configure the Cloud Load Balancer backend to point to the GKE service
3. Update Cloud Armor security policy as needed
4. Configure health checks and routing rules

### Ingress Example (Alternative)

For more advanced routing, you can use a GKE Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "web-static-ip"
spec:
  rules:
  - http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: hello-world
            port:
              number: 80
```

### Monitoring and Logging

View logs and metrics in Google Cloud Console:

```bash
# View pod logs
kubectl logs -l app=hello-world --tail=50

# View cluster details
kubectl describe deployment hello-world
kubectl describe service hello-world

# Check cluster health
kubectl get nodes
kubectl top nodes
kubectl top pods
```

Or use Cloud Console:
- **Kubernetes Engine** → **Workloads** for deployments
- **Kubernetes Engine** → **Services & Ingress** for services
- **Logging** → **Logs Explorer** for application logs
- **Monitoring** → **Dashboards** for metrics

### Cleanup

To remove the Hello World application:

```bash
kubectl delete -f k8s-manifests/hello-world.yaml
```

### Security Best Practices

1. **Network Policies**: Define network policies to control pod-to-pod communication
2. **Workload Identity**: Use Workload Identity for secure access to GCP services
3. **Binary Authorization**: Enable Binary Authorization to ensure only verified images are deployed
4. **Pod Security Standards**: Apply Pod Security Standards for enhanced security
5. **Private GKE**: Consider using a private GKE cluster for production workloads

### Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Service not getting external IP:**
```bash
kubectl describe service hello-world
# Check GCP quotas for external IPs
```

**Connection issues:**
```bash
# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- hello-world
```

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
