# Local infrastructure architecture

```text
Browser
  |
  v
Angular frontend (host port 80)
  |
  v
API Gateway (host port 8085)
  |---- user-service ------ mysql-user
  |---- product-service --- mysql-product
  |---- order-service ----- mysql-order
  |---- payment-service --- mysql-payment
  `---- delivery-service -- mysql-delivery

Event-driven communication: Kafka (`kafka:9092`)
Authentication: Keycloak (`keycloak:8080`)
```

All services share the `gwatcho-network` bridge network. Each business service has a separate MySQL database. Named volumes preserve database, Kafka, and Keycloak data across ordinary `docker compose down` operations.
