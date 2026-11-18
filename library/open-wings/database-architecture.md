# 🗄️ Database Architecture: MongoDB as a Container in a Local Cluster

### *A small, simple, open-source non-relational database for local Kubernetes environments*

> **Author:** *Renato Barufi* | **Domain:** Data Architecture | **Reading time:** ~10 min

---

## Introduction

Not every solution needs a managed database service or a multi-node cluster. For **local development, labs, proofs of concept, and small internal tools**, a single non-relational database running as a container in a local Kubernetes cluster (kind, minikube, k3s, or Rancher Desktop) is often enough. It is cheap, reproducible, and close to how production runs.

This document describes a **small and simple document database architecture** based on **MongoDB Community Edition**, with its deployment model, security baseline, backup approach, and the open-source alternatives to consider.

---

## 1. 📐 The Solution at a Glance

Design goals:

- **Small footprint** — one replica, minimal CPU and memory
- **Simple** — plain Kubernetes manifests, no operator required
- **Persistent** — data survives pod restarts through a PersistentVolumeClaim
- **Secure by default** — authentication enabled, credentials stored in a Secret, no public exposure
- **Open source friendly** — clear fallback if the license model is a concern

```
┌──────────────────────────────────────────────────────────────┐
│                     LOCAL KUBERNETES CLUSTER                 │
│                   (kind / minikube / k3s / Rancher)          │
│                                                              │
│  Namespace: data                                             │
│                                                              │
│  ┌──────────────────┐                                        │
│  │  Application Pod │                                        │
│  │  (Service A, B)  │                                        │
│  └────────┬─────────┘                                        │
│           │ mongodb://mongodb.data.svc:27017                 │
│           ▼                                                  │
│  ┌──────────────────┐        ┌──────────────────────────┐    │
│  │  Service         │        │  Secret: mongodb-auth    │    │
│  │  (ClusterIP /    │        │  (root user / password)  │    │
│  │   headless)      │        └────────────┬─────────────┘    │
│  └────────┬─────────┘                     │                  │
│           ▼                               ▼                  │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  StatefulSet: mongodb  (replicas: 1)                 │    │
│  │  Container: mongo:7    Port: 27017                   │    │
│  └────────────────────────┬─────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  PersistentVolumeClaim: data-mongodb-0  (1Gi)        │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  CronJob: mongodb-backup  →  PVC: mongodb-backup     │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. 🤔 Why a Non-Relational Database Here?

| Need | Why MongoDB fits |
|---|---|
| Flexible or evolving schema | Documents are JSON-like (BSON). Fields can change without migrations |
| Fast iteration in labs and MVPs | No DDL step before storing data |
| Nested or hierarchical data | Embedded documents and arrays are stored natively |
| Wide driver support | Official drivers for Node.js, Go, Python, Java, .NET |
| Small local footprint | A single instance runs in roughly 500 MB of RAM |

> 💡 **When *not* to use it:** if your data is strongly relational, needs multi-table joins, or requires strict cross-entity transactions, use PostgreSQL instead.

---

## 3. 🧱 Component Design

| Component | Kubernetes resource | Purpose |
|---|---|---|
| Namespace | `Namespace` | Isolates the data layer from application workloads |
| Credentials | `Secret` | Holds the root username and password |
| Database | `StatefulSet` (1 replica) | Gives MongoDB a stable identity and stable storage |
| Storage | `volumeClaimTemplates` | Creates a PVC per pod, so data survives restarts |
| Network access | Headless `Service` | Stable DNS name: `mongodb-0.mongodb.data.svc` |
| Access control | `NetworkPolicy` | Restricts which pods can reach port 27017 |
| Backup | `CronJob` + PVC | Scheduled `mongodump` archives |

**Why a StatefulSet and not a Deployment?** A database needs a stable network identity and its own volume per replica. A Deployment treats pods as interchangeable, which is the wrong model for stateful workloads.

---

## 4. 🚀 Deployment Manifests

### Suggested folder layout

```
k8s/database/
├── namespace.yaml
├── secret.yaml
├── service.yaml
├── statefulset.yaml
├── networkpolicy.yaml
└── backup/
    ├── pvc.yaml
    └── cronjob.yaml
```

### 4.1 Namespace and credentials

```yaml
# k8s/database/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: data
---
# k8s/database/secret.yaml  (local use only: do NOT commit real credentials)
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-auth
  namespace: data
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: admin
  MONGO_INITDB_ROOT_PASSWORD: change-me-locally
```

> ⚠️ Prefer creating the Secret from the command line, or from a secrets tool such as Sealed Secrets or SOPS, so credentials never reach Git:
> `kubectl create secret generic mongodb-auth -n data --from-literal=MONGO_INITDB_ROOT_USERNAME=admin --from-literal=MONGO_INITDB_ROOT_PASSWORD='<password>'`

### 4.2 Service

```yaml
# k8s/database/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: data
spec:
  clusterIP: None          # headless: stable per-pod DNS for the StatefulSet
  selector:
    app: mongodb
  ports:
    - name: mongo
      port: 27017
      targetPort: 27017
```

### 4.3 StatefulSet

```yaml
# k8s/database/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: data
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:7
          ports:
            - containerPort: 27017
              name: mongo
          envFrom:
            - secretRef:
                name: mongodb-auth
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 1Gi
          readinessProbe:
            exec:
              command: ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
            initialDelaySeconds: 30
            periodSeconds: 20
          volumeMounts:
            - name: data
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

> 💡 `MONGO_INITDB_ROOT_*` variables are only applied the **first time** the data directory is initialized. Changing the Secret later does not change the existing user.

### 4.4 Network access control

```yaml
# k8s/database/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mongodb-allow-apps
  namespace: data
spec:
  podSelector:
    matchLabels:
      app: mongodb
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              mongodb-access: "true"
      ports:
        - protocol: TCP
          port: 27017
```

Label the namespaces that are allowed to connect:

```bash
kubectl label namespace my-app mongodb-access=true
```

> ⚠️ The default CNI in **kind** (kindnet) does not enforce NetworkPolicy. Use Calico or Cilium if you need it to be enforced locally.

---

## 5. 🔌 Connecting to the Database

### From applications inside the cluster

```
mongodb://<user>:<password>@mongodb-0.mongodb.data.svc.cluster.local:27017/<database>?authSource=admin
```

Inject the connection string through a Secret and an environment variable, never hard-code it in the image.

```yaml
env:
  - name: MONGODB_URI
    valueFrom:
      secretKeyRef:
        name: app-mongodb-uri
        key: uri
```

### From your workstation (local debugging)

Do **not** expose MongoDB with a NodePort or LoadBalancer. Use a port-forward instead:

```bash
kubectl port-forward -n data svc/mongodb 27017:27017
mongosh "mongodb://admin:<password>@localhost:27017/?authSource=admin"
```

> Since the Service is headless, `port-forward` to the pod directly if the Service form fails: `kubectl port-forward -n data pod/mongodb-0 27017:27017`.

---

## 6. 💾 Backup and Restore

Local clusters are easily recreated, so backups matter even for small data sets.

### Scheduled backup

```yaml
# k8s/database/backup/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-backup
  namespace: data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 2Gi
---
# k8s/database/backup/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  namespace: data
spec:
  schedule: "0 2 * * *"            # every day at 02:00
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: mongo:7
              envFrom:
                - secretRef:
                    name: mongodb-auth
              command:
                - /bin/sh
                - -c
                - >
                  mongodump
                  --host mongodb-0.mongodb.data.svc.cluster.local
                  --username "$MONGO_INITDB_ROOT_USERNAME"
                  --password "$MONGO_INITDB_ROOT_PASSWORD"
                  --authenticationDatabase admin
                  --gzip
                  --archive=/backup/mongodb-$(date +%Y%m%d-%H%M%S).gz
              volumeMounts:
                - name: backup
                  mountPath: /backup
          volumes:
            - name: backup
              persistentVolumeClaim:
                claimName: mongodb-backup
```

### Restore

```bash
mongorestore --host <host> --username admin --password '<password>' \
  --authenticationDatabase admin --gzip --archive=/backup/mongodb-<timestamp>.gz
```

> 💡 The backup PVC lives in the same cluster. For anything you cannot afford to lose, copy the archives outside the cluster (object storage or a local folder) as well.

---

## 7. 🔐 Security Baseline

| Control | Implementation |
|---|---|
| Authentication | Root user created at first start through `MONGO_INITDB_ROOT_*` |
| Credential storage | Kubernetes `Secret`, never committed to Git |
| Network exposure | `ClusterIP`/headless only, with port-forward for debugging |
| Network segmentation | `NetworkPolicy` that allows only labeled namespaces |
| Least privilege | Create **per-application users** with `readWrite` on a single database instead of using root |
| Resource limits | CPU and memory limits protect the local node |
| Image hygiene | Pin the image tag (`mongo:7`, or an exact digest) rather than `latest` |

Example of a per-application user:

```javascript
use orders_db
db.createUser({
  user: "orders-svc",
  pwd: "<password>",
  roles: [{ role: "readWrite", db: "orders_db" }]
})
```

---

## 8. 📊 Observability

A database you cannot observe is hard to run, even locally.

| Signal | Approach |
|---|---|
| **Metrics** | Run the open-source **MongoDB exporter** (Percona) as a sidecar and scrape it with Prometheus |
| **Logs** | MongoDB writes to stdout. Collect with `kubectl logs` locally, or Loki/Fluent Bit in a fuller setup |
| **Health** | Readiness and liveness probes (`db.adminCommand('ping')`) |
| **Alerts** | Pod restarts, PVC usage above 80%, connection count, replication lag (when replicated) |

---

## 9. ⚖️ Open-Source Licensing and Alternatives

MongoDB Community Edition is published under the **Server Side Public License (SSPL)**. It is source-available and free to run, but it is **not OSI-approved open source**. This is usually fine for local labs and internal use. It can matter if you plan to offer MongoDB as a service.

| Option | License | When to choose it |
|---|---|---|
| **MongoDB Community** | SSPL | Maturity, documentation, widest ecosystem |
| **FerretDB** | Apache 2.0 | You need an OSI-approved license and MongoDB driver compatibility (backed by PostgreSQL or SQLite) |
| **CouchDB** | Apache 2.0 | HTTP/REST API and built-in replication matter more than MongoDB compatibility |
| **Valkey** | BSD-3 | The workload is key-value or cache, not documents |

Because FerretDB speaks the MongoDB wire protocol, migrating later only needs a change of image and connection endpoint in most cases.

---

## 10. ⚠️ Limitations and Evolution Path

| Limitation | Impact | Evolution |
|---|---|---|
| Single replica | No high availability. A pod or node failure means downtime | Move to a 3-member replica set |
| Local node storage | Data can be lost if the cluster is deleted | Use a durable storage class, and keep backups outside the cluster |
| No automated failover | Manual recovery | Adopt the **MongoDB Community Operator** or **Percona Operator** |
| No TLS in-cluster | Traffic is unencrypted inside the cluster | Enable TLS through cert-manager |

**Recommended progression:**

```
Phase 1 (Local lab)   → Single StatefulSet, Secret, PVC, port-forward
Phase 2 (Shared dev)  → Add backups, NetworkPolicy, per-app users, metrics
Phase 3 (Pre-prod)    → Operator-managed 3-member replica set, TLS, off-cluster backups
```

---

## 11. ✅ Key Architectural Principles — Summary

1. **One database, one purpose** — keep this instance small and scoped to the applications that need documents.
2. **StatefulSet plus PVC** — stable identity and persistent storage are the baseline for any database in Kubernetes.
3. **Never expose the database publicly** — use ClusterIP and port-forward.
4. **Credentials in Secrets, not in Git** — and use per-application users instead of root.
5. **Each service owns its own database** — use separate databases (and users) per service to avoid tight coupling.
6. **Back up from day one** — local clusters are disposable, your data should not be.
7. **Choose the license deliberately** — SSPL for MongoDB, or FerretDB if an OSI-approved license is required.

---

## Conclusion

A single MongoDB container running as a StatefulSet in a local Kubernetes cluster gives you a **small, simple, and capable non-relational database** with very little operational overhead. Add authentication, persistent storage, network restrictions, and scheduled backups, and it becomes a solid base for labs and early-stage solutions. When the workload grows, the same design evolves into an operator-managed replica set without changing how applications connect.

The architecture described here gives you:
- 🧩 **Simplicity** — a handful of plain Kubernetes manifests
- 📦 **Portability** — runs on kind, minikube, k3s, or Rancher Desktop
- 🔐 **Security basics** — authentication, Secrets, and network restrictions
- 💾 **Recoverability** — scheduled `mongodump` backups
- 🔀 **Flexibility** — swap to FerretDB or scale to a replica set when needed

---

*Tags: `#mongodb` `#nosql` `#kubernetes` `#statefulset` `#database-architecture` `#open-source` `#data-architecture` `#local-cluster` `#backup` `#observability`*
