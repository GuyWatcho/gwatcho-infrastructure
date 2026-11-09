-- MySQL dump 10.13  Distrib 8.4.11, for Linux (x86_64)
--
-- Host: localhost    Database: delivery_db
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
-- Current Database: `delivery_db`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `delivery_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `delivery_db`;

--
-- Table structure for table `deliveries`
--

DROP TABLE IF EXISTS `deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deliveries` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `amount` decimal(19,2) NOT NULL,
  `city` varchar(255) NOT NULL,
  `country` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `currency` varchar(255) NOT NULL,
  `customer_id` bigint NOT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `order_id` bigint NOT NULL,
  `payment_id` bigint NOT NULL,
  `postal_code` varchar(255) NOT NULL,
  `status` enum('CANCELLED','CREATED','DELIVERED','PREPARING','SHIPPED') NOT NULL,
  `street` varchar(255) NOT NULL,
  `transaction_id` varchar(255) DEFAULT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_delivery_order` (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deliveries`
--

LOCK TABLES `deliveries` WRITE;
/*!40000 ALTER TABLE `deliveries` DISABLE KEYS */;
INSERT INTO `deliveries` VALUES (1,321.85,'Neckarsulm','Germany','2026-10-11 09:42:35.210912','EUR',1,'2026-10-14 10:20:44.030739',2,2,'74172','DELIVERED','Sebastian-Bach-Weg','TXN-c9a9f0fe-15e3-4aa7-8021-ad08e71cb782','2026-10-14 10:20:44.032391'),(2,950.40,'Neckarsulm','Germany','2026-10-11 09:59:59.899328','EUR',1,'2026-10-13 10:46:51.112362',3,3,'74172','DELIVERED','Sebastian-Bach-Weg','TXN-c2c002eb-f740-4d85-ab29-7c118b27470a','2026-10-13 10:46:51.231110'),(3,568.88,'Weinfelden','Switzerland','2026-10-14 10:08:03.056202','EUR',2,'2026-10-14 10:20:22.060975',5,5,'8570','DELIVERED','Frauenfelderstrasse','TXN-cb41028f-dee5-4d49-9924-f8ee55ce5caf','2026-10-14 10:20:22.136773'),(4,875.58,'Weinfelden','Switzerland','2026-10-14 10:21:47.976992','EUR',2,'2026-10-14 10:22:24.377022',6,6,'8570','DELIVERED','Frauenfelderstrasse','TXN-539c5ad1-c90c-4a31-be41-cf3d83344bab','2026-10-14 10:22:24.379544'),(5,314.43,'Weinfelden','Switzerland','2026-10-14 11:35:33.827662','EUR',2,'2026-10-14 11:36:20.638822',7,7,'8570','DELIVERED','Frauenfelderstrasse','TXN-dbde755e-ce52-4b36-908c-045aca683473','2026-10-14 11:36:20.695380'),(6,426.66,'Weinfelden','Switzerland','2026-10-21 10:31:12.573782','EUR',2,'2026-10-21 10:31:59.883424',8,8,'8570','DELIVERED','Frauenfelderstrasse','TXN-446a15b8-9aa4-4d8d-b658-ef6535fccaa1','2026-10-21 10:31:59.973352');
/*!40000 ALTER TABLE `deliveries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'delivery_db'
--

--
-- Dumping routines for database 'delivery_db'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-01  4:21:17
