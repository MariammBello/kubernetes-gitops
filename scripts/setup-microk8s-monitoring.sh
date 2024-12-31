#!/bin/bash

# Create monitoring namespace
kubectl create namespace monitoring

# Apply Prometheus config
kubectl apply -f ../monitoring/prometheus/config-map.yaml

# Apply Grafana dashboard config
kubectl apply -f ../monitoring/grafana/dashboard-config.yaml

# Wait for pods to be ready
echo "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s

echo "Monitoring setup complete!"
echo "To access Grafana:"
echo "1. Get the Grafana service IP:"
echo "kubectl get svc -n monitoring"
echo "2. Access Grafana using the NodePort"