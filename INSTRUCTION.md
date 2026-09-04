# Deployment Instructions and Validation Guide

## Prerequisites

- Kubernetes cluster running (via Kind or similar)
- `kubectl` installed and configured
- Cluster configured with local storage provisioner for PersistentVolumes

## Deployment

### Step 1: Deploy All Resources

Run the bootstrap script to deploy all required resources:

```bash
bash bootstrap.sh
```

This script will:
1. Create the `todoapp` and `mysql` namespaces
2. Deploy MySQL StatefulSet with 3 replicas
3. Deploy the TodoApp application
4. Configure all Services, Secrets, and ConfigMaps
5. Set up Horizontal Pod Autoscaler

## Validation Steps

### 1. Verify Namespaces

```bash
kubectl get namespaces
```

Expected output should show:
- `todoapp` namespace
- `mysql` namespace

### 2. Verify MySQL StatefulSet

```bash
kubectl get statefulsets -n mysql
kubectl get pods -n mysql
```

Expected output:
- StatefulSet `mysql` with 3 replicas ready
- Pods: `mysql-0`, `mysql-1`, `mysql-2` all in `Running` state

Check MySQL pod status in detail:

```bash
kubectl get pods -n mysql -o wide
```

Verify MySQL is healthy:

```bash
kubectl logs mysql-0 -n mysql | grep "ready for connections"
```

### 3. Verify MySQL Service

```bash
kubectl get svc -n mysql
```

Expected output:
- Service `mysql` with type `ClusterIP: None` (headless service)
- Port mapping: 3306:3306

### 4. Verify Secrets

Check application secret contains database credentials:

```bash
kubectl get secret app-secret -n todoapp -o yaml
```

Expected keys in `data`:
- `SECRET_KEY` - Django secret key
- `HOST` - Database host (mysql-0.mysql.mysql.svc.cluster.local)
- `NAME` - Database name (tododb)
- `USER` - Database user (todoapp)
- `PASSWORD` - Database password

Verify MySQL secret:

```bash
kubectl get secret mysql-secret -n mysql -o yaml
```

Expected keys in `data`:
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_USER`
- `MYSQL_PASSWORD`

### 5. Verify ConfigMaps

Check application config:

```bash
kubectl get configmap app-config -n todoapp -o yaml
```

Expected data:
- `PYTHONUNBUFFERED: "1"`

Check MySQL init config:

```bash
kubectl get configmap mysql-init -n mysql -o yaml
```

Expected data:
- `init.sql` with database and user creation commands

### 6. Verify Persistent Volumes and Claims

```bash
kubectl get pv
kubectl get pvc -n todoapp
```

Expected output:
- PersistentVolume `pv-data` in `Bound` state
- PersistentVolumeClaim `pvc-data` in `Bound` state

### 7. Verify TodoApp Deployment

```bash
kubectl get deployment -n todoapp
kubectl get pods -n todoapp
```

Expected output:
- Deployment `todoapp` with desired replicas
- Pods running and ready

Check detailed pod status:

```bash
kubectl describe pod <pod-name> -n todoapp
```

### 8. Verify Application Services

```bash
kubectl get svc -n todoapp
```

Expected output:
- Service `todoapp-service` (ClusterIP)
- Service `todoapp-nodeport` (NodePort on port 30007)

### 9. Verify Database Connection

Check if the application is connected to MySQL:

```bash
kubectl logs -f deployment/todoapp -n todoapp
```

Look for successful database connection logs (no connection errors).

Execute into the application pod to verify database connectivity:

```bash
# Get a pod name
POD_NAME=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}')

# Execute into the pod
kubectl exec -it $POD_NAME -n todoapp -- python manage.py dbshell
```

If successfully connected to MySQL, you should see the MySQL prompt: `mysql>`

Verify database exists:

```sql
SHOW DATABASES;
```

Expected output should include `tododb`.

### 10. Test Application Health

Check application health endpoints:

```bash
# Get the pod IP
POD_IP=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].status.podIP}')

# Test health endpoint
kubectl exec -it $POD_NAME -n todoapp -- curl -s http://localhost:8080/api/health
```

Expected output: `{"status": "ok"}` or similar health check response.

### 11. Verify HPA (Horizontal Pod Autoscaler)

```bash
kubectl get hpa -n todoapp
kubectl describe hpa todoapp -n todoapp
```

Expected output:
- HPA `todoapp` configured
- Min replicas: 2
- Max replicas: 5
- Target CPU utilization: 70%
- Target memory utilization: 70%

### 12. Access the Application

Get the NodePort service:

```bash
kubectl get svc todoapp-nodeport -n todoapp
```

Access the application via browser:

```
http://localhost:30007
```

Or via curl:

```bash
curl http://localhost:30007
```

## Troubleshooting

### MySQL Pod not starting

```bash
# Check pod logs
kubectl logs mysql-0 -n mysql

# Describe pod for events
kubectl describe pod mysql-0 -n mysql
```

### Application not connecting to database

```bash
# Check application logs
kubectl logs -f deployment/todoapp -n todoapp

# Check environment variables
kubectl exec -it <pod-name> -n todoapp -- env | grep DB_
```

Verify the database host is resolvable from the application pod:

```bash
kubectl exec -it <pod-name> -n todoapp -- nslookup mysql.mysql.svc.cluster.local
```

### PersistentVolume not binding

```bash
# Check PV status
kubectl get pv -o wide

# Check PVC status
kubectl describe pvc pvc-data -n todoapp
```

### Application startup issues

```bash
# Check application pod logs
kubectl logs -f <pod-name> -n todoapp

# Check for resource constraints
kubectl describe pod <pod-name> -n todoapp | grep -A 10 "Events:"
```

## Environment Variables Verification

Verify that the application is reading database credentials from Kubernetes Secrets:

```bash
# Check that environment variables are set
kubectl exec -it <pod-name> -n todoapp -- env | grep -E "DB_|SECRET_KEY"
```

Expected environment variables:
- `DB_ENGINE=django.db.backends.mysql`
- `DB_HOST=mysql-0.mysql.mysql.svc.cluster.local` (or similar)
- `DB_PORT=3306`
- `DB_NAME=tododb`
- `DB_USER=todoapp`
- `DB_PASSWORD=123456`
- `SECRET_KEY=<base64-decoded-secret-key>`

## Database Schema Verification

Verify that database migrations have been applied:

```bash
# Connect to the database from the application pod
POD_NAME=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}')

# Check Django tables
kubectl exec -it $POD_NAME -n todoapp -- python manage.py showmigrations

# Apply migrations if needed
kubectl exec -it $POD_NAME -n todoapp -- python manage.py migrate
```

## Cleanup

To remove all deployed resources:

```bash
# Delete resources in reverse order
kubectl delete -f ./.infrastructure/hpa.yml
kubectl delete -f ./.infrastructure/deployment.yml
kubectl delete -f ./.infrastructure/nodeport.yml
kubectl delete -f ./.infrastructure/clusterIp.yml
kubectl delete -f ./.infrastructure/pvc.yml
kubectl delete -f ./.infrastructure/pv.yml
kubectl delete -f ./.infrastructure/confgiMap.yml
kubectl delete -f ./.infrastructure/secret.yml
kubectl delete -f ./.infrastructure/service-mysql.yml
kubectl delete -f ./.infrastructure/statefulSet.yml
kubectl delete -f ./.infrastructure/configMap-mysql.yml
kubectl delete -f ./.infrastructure/secret-mysql.yml
kubectl delete -f ./.infrastructure/namespace-mysql.yml
kubectl delete -f ./.infrastructure/namespace.yml
```

Or delete the namespaces (which will cascade delete all resources):

```bash
kubectl delete namespace todoapp mysql
```
