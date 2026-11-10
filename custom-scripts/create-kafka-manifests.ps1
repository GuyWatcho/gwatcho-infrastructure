$ErrorActionPreference = "Stop"

# Resolve repository root (parent of custom-scripts)
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Kafka manifest directory
$KafkaDir = Join-Path $RepoRoot "kubernetes\base\kafka"

Write-Host "Repository root: $RepoRoot"
Write-Host "Kafka directory: $KafkaDir"

New-Item -ItemType Directory -Path $KafkaDir -Force | Out-Null

# 1. namespace.yaml
@'
apiVersion: v1
kind: Namespace
metadata:
  name: gwatcho-local
'@ | Set-Content "$KafkaDir\namespace.yaml" -Encoding utf8

# 2. pvc.yaml
@'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kafka-data
  namespace: gwatcho-local
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: hostpath
  resources:
    requests:
      storage: 5Gi
'@ | Set-Content "$KafkaDir\pvc.yaml" -Encoding utf8

# 3. service.yaml
@'
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  namespace: gwatcho-local
spec:
  clusterIP: None
  selector:
    app: kafka
  ports:
    - name: controller
      port: 9093
      targetPort: 9093
---
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: gwatcho-local
spec:
  type: ClusterIP
  selector:
    app: kafka
  ports:
    - name: kafka
      port: 9092
      targetPort: 9092
'@ | Set-Content "$KafkaDir\service.yaml" -Encoding utf8

# 4. deployment.yaml
@'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: gwatcho-local
spec:
  serviceName: kafka-headless
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
        - name: kafka
          image: apache/kafka:4.0.0
          ports:
            - name: kafka
              containerPort: 9092
            - name: controller
              containerPort: 9093
          env:
            - name: KAFKA_NODE_ID
              value: "1"
            - name: KAFKA_PROCESS_ROLES
              value: broker,controller
            - name: KAFKA_LISTENERS
              value: PLAINTEXT://:9092,CONTROLLER://:9093
            - name: KAFKA_ADVERTISED_LISTENERS
              value: PLAINTEXT://kafka.gwatcho-local.svc.cluster.local:9092
            - name: KAFKA_CONTROLLER_LISTENER_NAMES
              value: CONTROLLER
            - name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
              value: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
            - name: KAFKA_CONTROLLER_QUORUM_VOTERS
              value: 1@localhost:9093
            - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
              value: "1"
            - name: KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
              value: "1"
            - name: KAFKA_TRANSACTION_STATE_LOG_MIN_ISR
              value: "1"
            - name: KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS
              value: "0"
            - name: KAFKA_NUM_PARTITIONS
              value: "3"
          volumeMounts:
            - name: kafka-data
              mountPath: /var/lib/kafka/data
      volumes:
        - name: kafka-data
          persistentVolumeClaim:
            claimName: kafka-data
'@ | Set-Content "$KafkaDir\deployment.yaml" -Encoding utf8

# 5. kustomization.yaml
@'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: gwatcho-local
resources:
  - namespace.yaml
  - pvc.yaml
  - service.yaml
  - deployment.yaml
'@ | Set-Content "$KafkaDir\kustomization.yaml" -Encoding utf8

Write-Host "`nKafka Kubernetes manifests created successfully:" -ForegroundColor Green
Get-ChildItem $KafkaDir