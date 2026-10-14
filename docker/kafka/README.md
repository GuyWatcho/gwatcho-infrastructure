# Kafka

The local Compose stack runs Apache Kafka in combined broker/controller KRaft mode.

- Bootstrap server inside Docker: `kafka:9092`
- Bootstrap server from the host: `localhost:9092`
- Kafka data is persisted in the `kafka-data` named volume.

The broker configuration is intended for local development only.
