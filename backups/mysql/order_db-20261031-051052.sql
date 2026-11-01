-- MySQL dump 10.13  Distrib 8.4.11, for Linux (x86_64)
--
-- Host: localhost    Database: order_db
-- ------------------------------------------------------
-- Server version	8.4.11

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `order_db`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `order_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `order_db`;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `line_total` decimal(19,2) NOT NULL,
  `product_id` bigint NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `quantity` int NOT NULL,
  `sku` varchar(50) NOT NULL,
  `unit_price` decimal(19,2) NOT NULL,
  `order_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKbioxgbv59vetrxe0ejfubep1w` (`order_id`),
  CONSTRAINT `FKbioxgbv59vetrxe0ejfubep1w` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items`
--

LOCK TABLES `order_items` WRITE;
/*!40000 ALTER TABLE `order_items` DISABLE KEYS */;
INSERT INTO `order_items` VALUES (1,284.44,3,'GWatcho Tablet 003',2,'GW-TAB-0003',142.22,1),(2,291.86,7,'GWatcho Headset 007',1,'GW-HEA-0007',291.86,1),(3,254.45,6,'GWatcho Mouse 006',1,'GW-MOU-0006',254.45,1),(4,217.04,5,'GWatcho Keyboard 005',1,'GW-KEY-0005',217.04,1),(5,329.27,8,'GWatcho Camera 008',1,'GW-CAM-0008',329.27,1),(6,142.22,3,'GWatcho Tablet 003',1,'GW-TAB-0003',142.22,2),(7,179.63,4,'GWatcho Monitor 004',1,'GW-MON-0004',179.63,2),(8,217.04,5,'GWatcho Keyboard 005',1,'GW-KEY-0005',217.04,3),(9,291.86,7,'GWatcho Headset 007',1,'GW-HEA-0007',291.86,3),(10,441.50,11,'GWatcho Laptop 011',1,'GW-LAP-0011',441.50,3),(11,142.22,3,'GWatcho Tablet 003',1,'GW-TAB-0003',142.22,4),(12,568.88,3,'GWatcho Tablet 003',4,'GW-TAB-0003',142.22,5),(13,875.58,7,'GWatcho Headset 007',3,'GW-HEA-0007',291.86,6),(14,104.81,2,'GWatcho Smartphone 002',1,'GW-SMA-0002',104.81,7),(15,67.40,1,'GWatcho Laptop 001',1,'GW-LAP-0001',67.40,7),(16,142.22,3,'GWatcho Tablet 003',1,'GW-TAB-0003',142.22,7),(17,104.81,2,'GWatcho Smartphone 002',1,'GW-SMA-0002',104.81,8),(18,142.22,3,'GWatcho Tablet 003',1,'GW-TAB-0003',142.22,8),(19,179.63,4,'GWatcho Monitor 004',1,'GW-MON-0004',179.63,8);
/*!40000 ALTER TABLE `order_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_outbox_events`
--

DROP TABLE IF EXISTS `order_outbox_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_outbox_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `aggregate_id` bigint NOT NULL,
  `aggregate_type` varchar(100) NOT NULL,
  `attempts` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `event_id` varchar(36) NOT NULL,
  `event_type` varchar(100) NOT NULL,
  `last_error` varchar(255) DEFAULT NULL,
  `payload` text NOT NULL,
  `published_at` datetime(6) DEFAULT NULL,
  `status` enum('FAILED','NEW','PENDING','PUBLISHED') NOT NULL,
  `topic` varchar(200) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK6jhqp1xwxgtsmlci68wsbds4w` (`event_id`),
  KEY `idx_order_outbox_status` (`status`),
  KEY `idx_order_outbox_event_id` (`event_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_outbox_events`
--

LOCK TABLES `order_outbox_events` WRITE;
/*!40000 ALTER TABLE `order_outbox_events` DISABLE KEYS */;
INSERT INTO `order_outbox_events` VALUES (1,1,'Order',0,'2026-10-11 07:21:00.847400','4acd8a1f-fce3-4bb4-bd2b-6cd71acabf7c','OrderCreated',NULL,'{\"eventId\":\"4acd8a1f-fce3-4bb4-bd2b-6cd71acabf7c\",\"eventType\":\"OrderCreated\",\"orderId\":1,\"customerId\":1,\"status\":\"CREATED\",\"totalAmount\":1377.06,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Sebastian-Bach-Weg\",\"postalCode\":\"74172\",\"city\":\"Neckarsulm\",\"country\":\"Germany\",\"items\":[{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":2,\"lineTotal\":284.44},{\"productId\":7,\"sku\":\"GW-HEA-0007\",\"productName\":\"GWatcho Headset 007\",\"unitPrice\":291.86,\"quantity\":1,\"lineTotal\":291.86},{\"productId\":6,\"sku\":\"GW-MOU-0006\",\"productName\":\"GWatcho Mouse 006\",\"unitPrice\":254.45,\"quantity\":1,\"lineTotal\":254.45},{\"productId\":5,\"sku\":\"GW-KEY-0005\",\"productName\":\"GWatcho Keyboard 005\",\"unitPrice\":217.04,\"quantity\":1,\"lineTotal\":217.04},{\"productId\":8,\"sku\":\"GW-CAM-0008\",\"productName\":\"GWatcho Camera 008\",\"unitPrice\":329.27,\"quantity\":1,\"lineTotal\":329.27}],\"createdAt\":\"2026-10-11T07:21:00.708947925\"}','2026-10-11 07:21:02.902195','PUBLISHED','order.created'),(2,2,'Order',0,'2026-10-11 09:35:13.567986','848b3a51-1327-4671-938c-f0944086942c','OrderCreated',NULL,'{\"eventId\":\"848b3a51-1327-4671-938c-f0944086942c\",\"eventType\":\"OrderCreated\",\"orderId\":2,\"customerId\":1,\"status\":\"CREATED\",\"totalAmount\":321.85,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Sebastian-Bach-Weg\",\"postalCode\":\"74172\",\"city\":\"Neckarsulm\",\"country\":\"Germany\",\"items\":[{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":1,\"lineTotal\":142.22},{\"productId\":4,\"sku\":\"GW-MON-0004\",\"productName\":\"GWatcho Monitor 004\",\"unitPrice\":179.63,\"quantity\":1,\"lineTotal\":179.63}],\"createdAt\":\"2026-10-11T09:35:13.470260915\"}','2026-10-11 09:35:14.733229','PUBLISHED','order.created'),(3,3,'Order',0,'2026-10-11 09:59:58.338338','00b18718-7268-449a-94cc-2d839ed36e2b','OrderCreated',NULL,'{\"eventId\":\"00b18718-7268-449a-94cc-2d839ed36e2b\",\"eventType\":\"OrderCreated\",\"orderId\":3,\"customerId\":1,\"status\":\"CREATED\",\"totalAmount\":950.40,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Sebastian-Bach-Weg\",\"postalCode\":\"74172\",\"city\":\"Neckarsulm\",\"country\":\"Germany\",\"items\":[{\"productId\":5,\"sku\":\"GW-KEY-0005\",\"productName\":\"GWatcho Keyboard 005\",\"unitPrice\":217.04,\"quantity\":1,\"lineTotal\":217.04},{\"productId\":7,\"sku\":\"GW-HEA-0007\",\"productName\":\"GWatcho Headset 007\",\"unitPrice\":291.86,\"quantity\":1,\"lineTotal\":291.86},{\"productId\":11,\"sku\":\"GW-LAP-0011\",\"productName\":\"GWatcho Laptop 011\",\"unitPrice\":441.50,\"quantity\":1,\"lineTotal\":441.50}],\"createdAt\":\"2026-10-11T09:59:58.275948027\"}','2026-10-11 09:59:59.388272','PUBLISHED','order.created'),(4,4,'Order',0,'2026-10-14 07:26:42.009345','6ce767f8-0aca-45c8-b380-86cc4a3cb0bb','OrderCreated',NULL,'{\"eventId\":\"6ce767f8-0aca-45c8-b380-86cc4a3cb0bb\",\"eventType\":\"OrderCreated\",\"orderId\":4,\"customerId\":2,\"status\":\"CREATED\",\"totalAmount\":142.22,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Frauenfelderstrasse\",\"postalCode\":\"8570\",\"city\":\"Weinfelden\",\"country\":\"Switzerland\",\"items\":[{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":1,\"lineTotal\":142.22}],\"createdAt\":\"2026-10-14T07:26:41.836158777\"}','2026-10-14 07:26:43.236968','PUBLISHED','order.created'),(5,5,'Order',0,'2026-10-14 10:08:00.915187','2539e7b7-f815-4742-b91e-5478726eb54d','OrderCreated',NULL,'{\"eventId\":\"2539e7b7-f815-4742-b91e-5478726eb54d\",\"eventType\":\"OrderCreated\",\"orderId\":5,\"customerId\":2,\"status\":\"CREATED\",\"totalAmount\":568.88,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Frauenfelderstrasse\",\"postalCode\":\"8570\",\"city\":\"Weinfelden\",\"country\":\"Switzerland\",\"items\":[{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":4,\"lineTotal\":568.88}],\"createdAt\":\"2026-10-14T10:08:00.75216224\"}','2026-10-14 10:08:01.942408','PUBLISHED','order.created'),(6,6,'Order',0,'2026-10-14 10:21:46.615469','20146d5f-efa0-4954-a3ee-f5e2f4f4219a','OrderCreated',NULL,'{\"eventId\":\"20146d5f-efa0-4954-a3ee-f5e2f4f4219a\",\"eventType\":\"OrderCreated\",\"orderId\":6,\"customerId\":2,\"status\":\"CREATED\",\"totalAmount\":875.58,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Frauenfelderstrasse\",\"postalCode\":\"8570\",\"city\":\"Weinfelden\",\"country\":\"Switzerland\",\"items\":[{\"productId\":7,\"sku\":\"GW-HEA-0007\",\"productName\":\"GWatcho Headset 007\",\"unitPrice\":291.86,\"quantity\":3,\"lineTotal\":875.58}],\"createdAt\":\"2026-10-14T10:21:46.601623196\"}','2026-10-14 10:21:47.452933','PUBLISHED','order.created'),(7,7,'Order',0,'2026-10-14 11:35:31.892816','8c001b7c-52b0-426c-b09c-998dad47c510','OrderCreated',NULL,'{\"eventId\":\"8c001b7c-52b0-426c-b09c-998dad47c510\",\"eventType\":\"OrderCreated\",\"orderId\":7,\"customerId\":2,\"status\":\"CREATED\",\"totalAmount\":314.43,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Frauenfelderstrasse\",\"postalCode\":\"8570\",\"city\":\"Weinfelden\",\"country\":\"Switzerland\",\"items\":[{\"productId\":2,\"sku\":\"GW-SMA-0002\",\"productName\":\"GWatcho Smartphone 002\",\"unitPrice\":104.81,\"quantity\":1,\"lineTotal\":104.81},{\"productId\":1,\"sku\":\"GW-LAP-0001\",\"productName\":\"GWatcho Laptop 001\",\"unitPrice\":67.40,\"quantity\":1,\"lineTotal\":67.40},{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":1,\"lineTotal\":142.22}],\"createdAt\":\"2026-10-14T11:35:31.790430956\"}','2026-10-14 11:35:32.773197','PUBLISHED','order.created'),(8,8,'Order',0,'2026-10-21 10:31:06.641690','5a9ac155-0379-49a1-95fe-2f4410b5f76c','OrderCreated',NULL,'{\"eventId\":\"5a9ac155-0379-49a1-95fe-2f4410b5f76c\",\"eventType\":\"OrderCreated\",\"orderId\":8,\"customerId\":2,\"status\":\"CREATED\",\"totalAmount\":426.66,\"currency\":\"EUR\",\"paymentMethod\":\"CREDIT_CARD\",\"street\":\"Frauenfelderstrasse\",\"postalCode\":\"8570\",\"city\":\"Weinfelden\",\"country\":\"Switzerland\",\"items\":[{\"productId\":2,\"sku\":\"GW-SMA-0002\",\"productName\":\"GWatcho Smartphone 002\",\"unitPrice\":104.81,\"quantity\":1,\"lineTotal\":104.81},{\"productId\":3,\"sku\":\"GW-TAB-0003\",\"productName\":\"GWatcho Tablet 003\",\"unitPrice\":142.22,\"quantity\":1,\"lineTotal\":142.22},{\"productId\":4,\"sku\":\"GW-MON-0004\",\"productName\":\"GWatcho Monitor 004\",\"unitPrice\":179.63,\"quantity\":1,\"lineTotal\":179.63}],\"createdAt\":\"2026-10-21T10:31:06.423814739\"}','2026-10-21 10:31:09.447191','PUBLISHED','order.created');
/*!40000 ALTER TABLE `order_outbox_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `currency` varchar(3) NOT NULL,
  `customer_id` bigint NOT NULL,
  `city` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `street` varchar(255) DEFAULT NULL,
  `payment_method` varchar(50) NOT NULL,
  `status` enum('CANCELLED','COMPLETED','CREATED','DELIVERED','PAID','PAYMENT_FAILED','PAYMENT_PENDING','SHIPPED','STOCK_FAILED','STOCK_PENDING','STOCK_RESERVED') NOT NULL,
  `total_amount` decimal(19,2) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `version` bigint DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (1,'2026-10-11 07:21:00.708948','EUR',1,'Neckarsulm','Germany','74172','Sebastian-Bach-Weg','CREDIT_CARD','CREATED',1377.06,'2026-10-11 07:21:00.708948',0),(2,'2026-10-11 09:35:13.470261','EUR',1,'Neckarsulm','Germany','74172','Sebastian-Bach-Weg','CREDIT_CARD','COMPLETED',321.85,'2026-10-14 10:20:44.050084',1),(3,'2026-10-11 09:59:58.275948','EUR',1,'Neckarsulm','Germany','74172','Sebastian-Bach-Weg','CREDIT_CARD','COMPLETED',950.40,'2026-10-13 10:46:51.864253',1),(4,'2026-10-14 07:26:41.836159','EUR',2,'Weinfelden','Switzerland','8570','Frauenfelderstrasse','CREDIT_CARD','CREATED',142.22,'2026-10-14 07:26:41.836159',0),(5,'2026-10-14 10:08:00.752162','EUR',2,'Weinfelden','Switzerland','8570','Frauenfelderstrasse','CREDIT_CARD','COMPLETED',568.88,'2026-10-14 10:20:22.282980',1),(6,'2026-10-14 10:21:46.601623','EUR',2,'Weinfelden','Switzerland','8570','Frauenfelderstrasse','CREDIT_CARD','COMPLETED',875.58,'2026-10-14 10:22:24.390793',1),(7,'2026-10-14 11:35:31.790431','EUR',2,'Weinfelden','Switzerland','8570','Frauenfelderstrasse','CREDIT_CARD','COMPLETED',314.43,'2026-10-14 11:36:20.716071',1),(8,'2026-10-21 10:31:06.423815','EUR',2,'Weinfelden','Switzerland','8570','Frauenfelderstrasse','CREDIT_CARD','COMPLETED',426.66,'2026-10-21 10:32:00.032799',1);
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `outbox_event`
--

DROP TABLE IF EXISTS `outbox_event`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outbox_event` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `aggregate_id` varchar(100) NOT NULL,
  `aggregate_type` varchar(50) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `event_id` binary(16) NOT NULL,
  `event_type` varchar(100) NOT NULL,
  `last_error` varchar(2000) DEFAULT NULL,
  `payload` tinytext NOT NULL,
  `published_at` datetime(6) DEFAULT NULL,
  `retry_count` int NOT NULL,
  `status` enum('FAILED','NEW','PENDING','PUBLISHED') NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKc7pmgf9c7t5nt657in8sec87v` (`event_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `outbox_event`
--

LOCK TABLES `outbox_event` WRITE;
/*!40000 ALTER TABLE `outbox_event` DISABLE KEYS */;
/*!40000 ALTER TABLE `outbox_event` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'order_db'
--

--
-- Dumping routines for database 'order_db'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-31  4:10:52
