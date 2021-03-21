#!/bin/bash

# Task 1
gcloud config set compute/zone us-central1-a
gcloud container clusters create test-cluster --num-nodes=3  --enable-ip-alias

# cat << EOF > gb_frontend_pod.yaml
# apiVersion: v1
# kind: Pod
# metadata:
#   labels:
#     app: gb-frontend
#   name: gb-frontend
# spec:
#     containers:
#     - name: gb-frontend
#       image: gcr.io/google-samples/gb-frontend:v5
#       resources:
#         requests:
#           cpu: 100m
#           memory: 256Mi
#       ports:
#       - containerPort: 80
# EOF
kubectl apply -f gb_frontend_pod.yaml

# Task 2

# cat << EOF > gb_frontend_cluster_ip.yaml
# apiVersion: v1
# kind: Service
# metadata:
#   name: gb-frontend-svc
#   annotations:
#     cloud.google.com/neg: '{"ingress": true}'
# spec:
#   type: ClusterIP
#   selector:
#     app: gb-frontend
#   ports:
#   - port: 80
#     protocol: TCP
#     targetPort: 80
# EOF
kubectl apply -f gb_frontend_cluster_ip.yaml

# cat << EOF > gb_frontend_ingress.yaml
# apiVersion: networking.k8s.io/v1beta1
# kind: Ingress
# metadata:
#   name: gb-frontend-ingress
# spec:
#   backend:
#     serviceName: gb-frontend-svc
#     servicePort: 80
# EOF
kubectl apply -f gb_frontend_ingress.yaml

BACKEND_SERVICE=$(gcloud compute backend-services list | tail -1 | cut -d ' ' -f1)
gcloud compute backend-services get-health $BACKEND_SERVICE --global
kubectl get ingress gb-frontend-ingress

# Task 3

GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)

# gsutil cp -r gs://spls/gsp769/locust-image .
gcloud builds submit \
    --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/locust-tasks:latest locust-image

# gsutil cp gs://spls/gsp769/locust_deploy.yaml .
sed 's/${GOOGLE_CLOUD_PROJECT}/'$GOOGLE_CLOUD_PROJECT'/g' locust_deploy.yaml | kubectl apply -f -

# Task 4

# cat << EOF > liveness-demo.yaml
# apiVersion: v1
# kind: Pod
# metadata:
#   labels:
#     demo: liveness-probe
#   name: liveness-demo-pod
# spec:
#   containers:
#   - name: liveness-demo-pod
#     image: centos
#     args:
#     - /bin/sh
#     - -c
#     - touch /tmp/alive; sleep infinity
#     livenessProbe:
#       exec:
#         command:
#         - cat
#         - /tmp/alive
#       initialDelaySeconds: 5
#       periodSeconds: 10
# EOF

kubectl apply -f liveness-demo.yaml

kubectl exec liveness-demo-pod -- rm /tmp/alive

# cat << EOF > readiness-demo.yaml
# apiVersion: v1
# kind: Pod
# metadata:
#   labels:
#     demo: readiness-probe
#   name: readiness-demo-pod
# spec:
#   containers:
#   - name: readiness-demo-pod
#     image: nginx
#     ports:
#     - containerPort: 80
#     readinessProbe:
#       exec:
#         command:
#         - cat
#         - /tmp/healthz
#       initialDelaySeconds: 5
#       periodSeconds: 5
# ---
# apiVersion: v1
# kind: Service
# metadata:
#   name: readiness-demo-svc
#   labels:
#     demo: readiness-probe
# spec:
#   type: LoadBalancer
#   ports:
#     - port: 80
#       targetPort: 80
#       protocol: TCP
#   selector:
#     demo: readiness-probe
# EOF

kubectl apply -f readiness-demo.yaml

kubectl exec readiness-demo-pod -- touch /tmp/healthz

kubectl describe pod readiness-demo-pod | grep ^Conditions -A 5

# Task 5

kubectl delete pod gb-frontend

# cat << EOF > gb_frontend_deployment.yaml
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: gb-frontend
#   labels:
#     run: gb-frontend
# spec:
#   replicas: 5
#   selector:
#     matchLabels:
#       run: gb-frontend
#   template:
#     metadata:
#       labels:
#         run: gb-frontend
#     spec:
#       containers:
#         - name: gb-frontend
#           image: gcr.io/google-samples/gb-frontend:v5
#           resources:
#             requests:
#               cpu: 100m
#               memory: 128Mi
#           ports:
#             - containerPort: 80
#               protocol: TCP
# EOF

kubectl apply -f gb_frontend_deployment.yaml

