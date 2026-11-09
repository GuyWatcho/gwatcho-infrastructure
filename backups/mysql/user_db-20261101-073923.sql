-- MySQL dump 10.13  Distrib 8.4.11, for Linux (x86_64)
--
-- Host: localhost    Database: user_db
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
-- Current Database: `user_db`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `user_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `user_db`;

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `city` varchar(100) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `email` varchar(255) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `house_number` varchar(20) DEFAULT NULL,
  `keycloak_id` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `postal_code` varchar(20) DEFAULT NULL,
  `street` varchar(255) DEFAULT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_keycloak_id` (`keycloak_id`),
  UNIQUE KEY `uk_customer_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customers`
--

LOCK TABLES `customers` WRITE;
/*!40000 ALTER TABLE `customers` DISABLE KEYS */;
INSERT INTO `customers` VALUES (1,'Neckarsulm','Germany','2026-10-10 04:31:04.038060','customer1@gwatcho-shop.local','Customer','18','6c917f4d-31b8-4ef6-86c9-2dbd9a052052','One','+4917627861055','74172','Sebastian-Bach-Weg','2026-10-14 04:44:11.503591'),(2,'Weinfelden','Switzerland','2026-10-13 01:23:41.527439','admin@gwatcho-shop.local','Guy','60','69554358-631a-4a64-bc2e-36a652d8c155','Bami Admin','+41763885280','8570','Frauenfelderstrasse','2026-10-14 07:05:13.723830');
/*!40000 ALTER TABLE `customers` ENABLE KEYS */;
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
  `aggregate_type` varchar(100) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `event_id` binary(16) NOT NULL,
  `event_type` varchar(100) NOT NULL,
  `payload` longtext NOT NULL,
  `published_at` datetime(6) DEFAULT NULL,
  `status` enum('NEW','PUBLISHED') NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKc7pmgf9c7t5nt657in8sec87v` (`event_id`),
  KEY `idx_outbox_status_created` (`status`,`created_at`)
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
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `email` varchar(255) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `status` enum('ACTIVE','INACTIVE') NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'user_db'
--

--
-- Dumping routines for database 'user_db'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-01  6:39:24
