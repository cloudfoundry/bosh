-- MySQL dump 10.13  Distrib 5.7.18, for osx10.12 (x86_64)
--
-- Host: localhost    Database: b801f0a856db44d28cafff1d090652b5
-- ------------------------------------------------------
-- Server version	5.7.18

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `cloud_configs`
--

DROP TABLE IF EXISTS `cloud_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cloud_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `properties` longtext,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `cloud_configs_created_at_index` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cloud_configs`
--

LOCK TABLES `cloud_configs` WRITE;
/*!40000 ALTER TABLE `cloud_configs` DISABLE KEYS */;
INSERT INTO `cloud_configs` VALUES (1,'azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n- name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nresource_pools:\n- cloud_properties: {}\n  env:\n    bosh:\n      password: foobar\n  name: a\n  stemcell:\n    name: ubuntu-stemcell\n    version: \"1\"\n','2017-06-19 19:43:44');
/*!40000 ALTER TABLE `cloud_configs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `compiled_packages`
--

DROP TABLE IF EXISTS `compiled_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compiled_packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(255) NOT NULL,
  `dependency_key` longtext NOT NULL,
  `build` int(11) NOT NULL,
  `package_id` int(11) NOT NULL,
  `dependency_key_sha1` varchar(255) NOT NULL,
  `stemcell_os` varchar(255) DEFAULT NULL,
  `stemcell_version` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `package_stemcell_build_idx` (`package_id`,`stemcell_os`,`stemcell_version`,`build`),
  UNIQUE KEY `package_stemcell_dependency_idx` (`package_id`,`stemcell_os`,`stemcell_version`,`dependency_key_sha1`),
  CONSTRAINT `compiled_packages_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `compiled_packages`
--

LOCK TABLES `compiled_packages` WRITE;
/*!40000 ALTER TABLE `compiled_packages` DISABLE KEYS */;
INSERT INTO `compiled_packages` VALUES (1,'cef8ad4e-4f12-4196-4b95-475a54f68ba8','39a4e1d20e924f5fda74ed82047b03ebcb8d43c1','[]',1,2,'97d170e1550eee4afc0af065b78cda302a97674c','toronto-os','1'),(2,'8fd78649-90b9-4f3f-5934-18007fb99005','c6261bbaccd70660e91efe65d087db93a1ab7142','[[\"pkg_2\",\"fa48497a19f12e925b32fcb8f5ca2b42144e4444\"]]',1,3,'b048798b462817f4ae6a5345dd9a0c45d1a1c8ea','toronto-os','1');
/*!40000 ALTER TABLE `compiled_packages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `delayed_jobs`
--

DROP TABLE IF EXISTS `delayed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `delayed_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `priority` int(11) NOT NULL DEFAULT '0',
  `attempts` int(11) NOT NULL DEFAULT '0',
  `handler` longtext NOT NULL,
  `last_error` longtext,
  `run_at` datetime DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `failed_at` datetime DEFAULT NULL,
  `locked_by` varchar(255) DEFAULT NULL,
  `queue` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `delayed_jobs_priority` (`priority`,`run_at`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `delayed_jobs`
--

LOCK TABLES `delayed_jobs` WRITE;
/*!40000 ALTER TABLE `delayed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `delayed_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployment_problems`
--

DROP TABLE IF EXISTS `deployment_problems`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployment_problems` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `deployment_id` int(11) NOT NULL,
  `state` varchar(255) NOT NULL,
  `resource_id` int(11) NOT NULL,
  `type` varchar(255) NOT NULL,
  `data_json` longtext NOT NULL,
  `created_at` datetime NOT NULL,
  `last_seen_at` datetime NOT NULL,
  `counter` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `deployment_problems_deployment_id_type_state_index` (`deployment_id`,`type`,`state`),
  KEY `deployment_problems_deployment_id_state_created_at_index` (`deployment_id`,`state`,`created_at`),
  CONSTRAINT `deployment_problems_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployment_problems`
--

LOCK TABLES `deployment_problems` WRITE;
/*!40000 ALTER TABLE `deployment_problems` DISABLE KEYS */;
/*!40000 ALTER TABLE `deployment_problems` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployment_properties`
--

DROP TABLE IF EXISTS `deployment_properties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployment_properties` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `deployment_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `value` longtext NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `deployment_id` (`deployment_id`,`name`),
  CONSTRAINT `deployment_properties_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployment_properties`
--

LOCK TABLES `deployment_properties` WRITE;
/*!40000 ALTER TABLE `deployment_properties` DISABLE KEYS */;
/*!40000 ALTER TABLE `deployment_properties` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployments`
--

DROP TABLE IF EXISTS `deployments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `manifest` longtext,
  `cloud_config_id` int(11) DEFAULT NULL,
  `link_spec_json` longtext,
  `runtime_config_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `cloud_config_id` (`cloud_config_id`),
  KEY `runtime_config_id` (`runtime_config_id`),
  CONSTRAINT `deployments_ibfk_1` FOREIGN KEY (`cloud_config_id`) REFERENCES `cloud_configs` (`id`),
  CONSTRAINT `deployments_ibfk_2` FOREIGN KEY (`runtime_config_id`) REFERENCES `runtime_configs` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'simple','---\ndirector_uuid: deadbeef\njobs:\n- azs:\n  - z1\n  instances: 1\n  name: my_api\n  networks:\n  - name: a\n  properties: {}\n  resource_pool: a\n  templates:\n  - consumes:\n      backup_db:\n        from: link_alias\n      db:\n        from: link_alias\n    name: api_server\n- azs:\n  - z1\n  instances: 1\n  name: aliased_postgres\n  networks:\n  - name: a\n  properties: {}\n  resource_pool: a\n  templates:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: link_alias\n- azs:\n  - z1\n  instances: 1\n  lifecycle: errand\n  name: my_errand\n  networks:\n  - name: a\n  properties: {}\n  resource_pool: a\n  templates:\n  - consumes:\n      backup_db:\n        from: link_alias\n      db:\n        from: link_alias\n    name: errand_with_links\n- azs:\n  - z1\n  instances: 1\n  name: job_with_no_links\n  networks:\n  - name: a\n  properties: {}\n  resource_pool: a\n  templates:\n  - name: provider\nname: simple\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n',1,'{}',NULL);
/*!40000 ALTER TABLE `deployments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployments_release_versions`
--

DROP TABLE IF EXISTS `deployments_release_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments_release_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `release_version_id` int(11) NOT NULL,
  `deployment_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_version_id` (`release_version_id`,`deployment_id`),
  KEY `deployment_id` (`deployment_id`),
  CONSTRAINT `deployments_release_versions_ibfk_1` FOREIGN KEY (`release_version_id`) REFERENCES `release_versions` (`id`),
  CONSTRAINT `deployments_release_versions_ibfk_2` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_release_versions`
--

LOCK TABLES `deployments_release_versions` WRITE;
/*!40000 ALTER TABLE `deployments_release_versions` DISABLE KEYS */;
INSERT INTO `deployments_release_versions` VALUES (1,1,1);
/*!40000 ALTER TABLE `deployments_release_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployments_stemcells`
--

DROP TABLE IF EXISTS `deployments_stemcells`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments_stemcells` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `deployment_id` int(11) NOT NULL,
  `stemcell_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `deployment_id` (`deployment_id`,`stemcell_id`),
  KEY `stemcell_id` (`stemcell_id`),
  CONSTRAINT `deployments_stemcells_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`),
  CONSTRAINT `deployments_stemcells_ibfk_2` FOREIGN KEY (`stemcell_id`) REFERENCES `stemcells` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_stemcells`
--

LOCK TABLES `deployments_stemcells` WRITE;
/*!40000 ALTER TABLE `deployments_stemcells` DISABLE KEYS */;
INSERT INTO `deployments_stemcells` VALUES (1,1,1);
/*!40000 ALTER TABLE `deployments_stemcells` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployments_teams`
--

DROP TABLE IF EXISTS `deployments_teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments_teams` (
  `deployment_id` int(11) NOT NULL,
  `team_id` int(11) NOT NULL,
  UNIQUE KEY `deployment_id` (`deployment_id`,`team_id`),
  KEY `team_id` (`team_id`),
  CONSTRAINT `deployments_teams_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `deployments_teams_ibfk_2` FOREIGN KEY (`team_id`) REFERENCES `teams` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_teams`
--

LOCK TABLES `deployments_teams` WRITE;
/*!40000 ALTER TABLE `deployments_teams` DISABLE KEYS */;
/*!40000 ALTER TABLE `deployments_teams` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `director_attributes`
--

DROP TABLE IF EXISTS `director_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `director_attributes` (
  `value` longtext,
  `name` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_attribute_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `director_attributes`
--

LOCK TABLES `director_attributes` WRITE;
/*!40000 ALTER TABLE `director_attributes` DISABLE KEYS */;
INSERT INTO `director_attributes` VALUES ('deadbeef','uuid',1);
/*!40000 ALTER TABLE `director_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `dns_schema`
--

DROP TABLE IF EXISTS `dns_schema`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dns_schema` (
  `filename` varchar(255) NOT NULL,
  PRIMARY KEY (`filename`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `dns_schema`
--

LOCK TABLES `dns_schema` WRITE;
/*!40000 ALTER TABLE `dns_schema` DISABLE KEYS */;
INSERT INTO `dns_schema` VALUES ('20120123234908_initial.rb');
/*!40000 ALTER TABLE `dns_schema` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `domains`
--

DROP TABLE IF EXISTS `domains`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `domains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `master` varchar(128) DEFAULT NULL,
  `last_check` int(11) DEFAULT NULL,
  `type` varchar(6) NOT NULL,
  `notified_serial` int(11) DEFAULT NULL,
  `account` varchar(40) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `domains`
--

LOCK TABLES `domains` WRITE;
/*!40000 ALTER TABLE `domains` DISABLE KEYS */;
INSERT INTO `domains` VALUES (1,'bosh',NULL,NULL,'NATIVE',NULL,NULL),(2,'1.168.192.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL);
/*!40000 ALTER TABLE `domains` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ephemeral_blobs`
--

DROP TABLE IF EXISTS `ephemeral_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ephemeral_blobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ephemeral_blobs`
--

LOCK TABLES `ephemeral_blobs` WRITE;
/*!40000 ALTER TABLE `ephemeral_blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `ephemeral_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `events` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `parent_id` bigint(20) DEFAULT NULL,
  `user` varchar(255) NOT NULL,
  `timestamp` datetime NOT NULL,
  `action` varchar(255) NOT NULL,
  `object_type` varchar(255) NOT NULL,
  `object_name` varchar(255) DEFAULT NULL,
  `error` longtext,
  `task` varchar(255) DEFAULT NULL,
  `deployment` varchar(255) DEFAULT NULL,
  `instance` varchar(255) DEFAULT NULL,
  `context_json` longtext,
  PRIMARY KEY (`id`),
  KEY `events_timestamp_index` (`timestamp`)
) ENGINE=InnoDB AUTO_INCREMENT=46 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,NULL,'test','2017-06-19 19:43:44','update','cloud-config',NULL,NULL,NULL,NULL,NULL,'{}'),(2,NULL,'test','2017-06-19 19:43:44','create','deployment','simple',NULL,'3','simple',NULL,'{}'),(3,NULL,'test','2017-06-19 19:43:44','create','instance','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(4,NULL,'test','2017-06-19 19:43:44','create','vm',NULL,NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(5,4,'test','2017-06-19 19:43:44','create','vm','26886',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(6,3,'test','2017-06-19 19:43:44','create','instance','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(7,NULL,'test','2017-06-19 19:43:45','delete','instance','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(8,NULL,'test','2017-06-19 19:43:45','delete','vm','26886',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(9,8,'test','2017-06-19 19:43:45','delete','vm','26886',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(10,7,'test','2017-06-19 19:43:45','delete','instance','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17',NULL,'3','simple','compilation-397480dd-c8e2-4172-b1cf-375e2af27939/2029b6a1-3211-4fde-b7a8-0361a8bdac17','{}'),(11,NULL,'test','2017-06-19 19:43:46','create','instance','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(12,NULL,'test','2017-06-19 19:43:46','create','vm',NULL,NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(13,12,'test','2017-06-19 19:43:46','create','vm','26890',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(14,11,'test','2017-06-19 19:43:47','create','instance','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(15,NULL,'test','2017-06-19 19:43:48','delete','instance','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(16,NULL,'test','2017-06-19 19:43:48','delete','vm','26890',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(17,16,'test','2017-06-19 19:43:48','delete','vm','26890',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(18,15,'test','2017-06-19 19:43:48','delete','instance','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085',NULL,'3','simple','compilation-d7eb49fa-6437-46d8-ac76-93f1155a2412/e53fdbc3-f8d7-4d36-9ac3-45bd6a379085','{}'),(19,NULL,'test','2017-06-19 19:43:48','create','vm',NULL,NULL,'3','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(20,NULL,'test','2017-06-19 19:43:48','create','vm',NULL,NULL,'3','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(21,NULL,'test','2017-06-19 19:43:48','create','vm',NULL,NULL,'3','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(22,19,'test','2017-06-19 19:43:48','create','vm','26895',NULL,'3','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(23,20,'test','2017-06-19 19:43:48','create','vm','26897',NULL,'3','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(24,21,'test','2017-06-19 19:43:48','create','vm','26896',NULL,'3','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(25,NULL,'test','2017-06-19 19:43:49','create','instance','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9',NULL,'3','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{\"az\":\"z1\"}'),(26,25,'test','2017-06-19 19:43:55','create','instance','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9',NULL,'3','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(27,NULL,'test','2017-06-19 19:43:55','create','instance','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c',NULL,'3','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{\"az\":\"z1\"}'),(28,27,'test','2017-06-19 19:44:01','create','instance','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c',NULL,'3','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(29,NULL,'test','2017-06-19 19:44:01','create','instance','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b',NULL,'3','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{\"az\":\"z1\"}'),(30,29,'test','2017-06-19 19:44:07','create','instance','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b',NULL,'3','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(31,2,'test','2017-06-19 19:44:07','create','deployment','simple',NULL,'3','simple',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(32,NULL,'test','2017-06-19 19:44:08','update','deployment','simple',NULL,'4','simple',NULL,'{}'),(33,NULL,'test','2017-06-19 19:44:08','stop','instance','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9',NULL,'4','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(34,NULL,'test','2017-06-19 19:44:09','delete','vm','26896',NULL,'4','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(35,34,'test','2017-06-19 19:44:09','delete','vm','26896',NULL,'4','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(36,33,'test','2017-06-19 19:44:09','stop','instance','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9',NULL,'4','simple','my_api/f874703e-1d88-468e-9bd9-57cb91ffd3e9','{}'),(37,NULL,'test','2017-06-19 19:44:09','stop','instance','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c',NULL,'4','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(38,NULL,'test','2017-06-19 19:44:09','delete','vm','26897',NULL,'4','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(39,38,'test','2017-06-19 19:44:09','delete','vm','26897',NULL,'4','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(40,37,'test','2017-06-19 19:44:09','stop','instance','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c',NULL,'4','simple','aliased_postgres/5f9cc0ab-a474-40ed-995e-97680c02189c','{}'),(41,NULL,'test','2017-06-19 19:44:09','stop','instance','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b',NULL,'4','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(42,NULL,'test','2017-06-19 19:44:09','delete','vm','26895',NULL,'4','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(43,42,'test','2017-06-19 19:44:09','delete','vm','26895',NULL,'4','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(44,41,'test','2017-06-19 19:44:09','stop','instance','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b',NULL,'4','simple','job_with_no_links/4b158758-db2e-4cad-97a9-791e1e6e2f1b','{}'),(45,32,'test','2017-06-19 19:44:09','update','deployment','simple',NULL,'4','simple',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}');
/*!40000 ALTER TABLE `events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `instances`
--

DROP TABLE IF EXISTS `instances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instances` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(255) NOT NULL,
  `index` int(11) NOT NULL,
  `deployment_id` int(11) NOT NULL,
  `vm_id` int(11) DEFAULT NULL,
  `state` varchar(255) NOT NULL,
  `resurrection_paused` tinyint(1) DEFAULT '0',
  `uuid` varchar(255) DEFAULT NULL,
  `availability_zone` varchar(255) DEFAULT NULL,
  `cloud_properties` longtext,
  `compilation` tinyint(1) DEFAULT '0',
  `bootstrap` tinyint(1) DEFAULT '0',
  `dns_records` longtext,
  `spec_json` longtext,
  `vm_cid` varchar(255) DEFAULT NULL,
  `agent_id` varchar(255) DEFAULT NULL,
  `credentials_json` longtext,
  `trusted_certs_sha1` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  `update_completed` tinyint(1) DEFAULT '0',
  `ignore` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `vm_id` (`vm_id`),
  UNIQUE KEY `uuid` (`uuid`),
  UNIQUE KEY `vm_cid` (`vm_cid`),
  UNIQUE KEY `agent_id` (`agent_id`),
  KEY `deployment_id` (`deployment_id`),
  CONSTRAINT `instances_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`),
  CONSTRAINT `instances_ibfk_2` FOREIGN KEY (`vm_id`) REFERENCES `vms` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'my_api',0,1,NULL,'detached',0,'f874703e-1d88-468e-9bd9-57cb91ffd3e9','z1','{}',0,1,'[\"0.my-api.a.simple.bosh\",\"f874703e-1d88-468e-9bd9-57cb91ffd3e9.my-api.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"my_api\",\"templates\":[{\"name\":\"api_server\",\"version\":\"76ff26229b603294a6f540e53faf68a2424cdf59\",\"sha1\":\"1ed133671ae62207caf6f5c974adc30d1782816f\",\"blobstore_id\":\"65141b20-f5d7-44d9-be8d-9510d7e7a0ce\"}],\"template\":\"api_server\",\"version\":\"76ff26229b603294a6f540e53faf68a2424cdf59\",\"sha1\":\"1ed133671ae62207caf6f5c974adc30d1782816f\",\"blobstore_id\":\"65141b20-f5d7-44d9-be8d-9510d7e7a0ce\"},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"my_api\",\"id\":\"f874703e-1d88-468e-9bd9-57cb91ffd3e9\",\"az\":\"z1\",\"networks\":{\"a\":{\"ip\":\"192.168.1.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{\"bosh\":{\"password\":\"foobar\"}},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"c6261bbaccd70660e91efe65d087db93a1ab7142\",\"blobstore_id\":\"8fd78649-90b9-4f3f-5934-18007fb99005\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"db\":{\"deployment_name\":\"simple\",\"networks\":[\"a\"],\"properties\":null,\"instances\":[{\"name\":\"aliased_postgres\",\"index\":0,\"bootstrap\":true,\"id\":\"5f9cc0ab-a474-40ed-995e-97680c02189c\",\"az\":\"z1\",\"address\":\"192.168.1.3\"}]},\"backup_db\":{\"deployment_name\":\"simple\",\"networks\":[\"a\"],\"properties\":null,\"instances\":[{\"name\":\"aliased_postgres\",\"index\":0,\"bootstrap\":true,\"id\":\"5f9cc0ab-a474-40ed-995e-97680c02189c\",\"az\":\"z1\",\"address\":\"192.168.1.3\"}]}},\"address\":\"192.168.1.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"5dbd7f4384193b7d22872de9dcd8a577f449a4de\"},\"rendered_templates_archive\":{\"blobstore_id\":\"d07a87b8-163c-41ed-b513-030361bcab8a\",\"sha1\":\"e6b1c0ad3e2b6751d8372b894196198c3a6c9f99\"},\"configuration_hash\":\"0125968ca3f0dc196a37d2ca9aa446bbdf05bde4\"}',NULL,NULL,'null',NULL,1,0),(2,'aliased_postgres',0,1,NULL,'detached',0,'5f9cc0ab-a474-40ed-995e-97680c02189c','z1','{}',0,1,'[\"0.aliased-postgres.a.simple.bosh\",\"5f9cc0ab-a474-40ed-995e-97680c02189c.aliased-postgres.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"aliased_postgres\",\"templates\":[{\"name\":\"backup_database\",\"version\":\"29322b71c9a475beae1249873d8f6e136335448b\",\"sha1\":\"2e0510f7f6669c21bd89778f8e6f9caa510717eb\",\"blobstore_id\":\"2dd9102e-009d-46a2-b59d-6bdedb54ce33\"}],\"template\":\"backup_database\",\"version\":\"29322b71c9a475beae1249873d8f6e136335448b\",\"sha1\":\"2e0510f7f6669c21bd89778f8e6f9caa510717eb\",\"blobstore_id\":\"2dd9102e-009d-46a2-b59d-6bdedb54ce33\"},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"aliased_postgres\",\"id\":\"5f9cc0ab-a474-40ed-995e-97680c02189c\",\"az\":\"z1\",\"networks\":{\"a\":{\"ip\":\"192.168.1.3\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{\"bosh\":{\"password\":\"foobar\"}},\"packages\":{},\"properties\":{\"backup_database\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.3\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true},\"persistent_disk\":0,\"template_hashes\":{\"backup_database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"85c3210c-2a0b-44c0-92df-f8afaea2cd9e\",\"sha1\":\"44fb3c677b9969e2541412d24a64b6ee7e30e7d0\"},\"configuration_hash\":\"4e4c9c0b7e76b5bc955b215edbd839e427d581aa\"}',NULL,NULL,'null',NULL,1,0),(3,'my_errand',0,1,NULL,'started',0,'4dba0056-c148-444e-b57d-8af4359c09ad','z1',NULL,0,1,'[]',NULL,NULL,NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',0,0),(4,'job_with_no_links',0,1,NULL,'detached',0,'4b158758-db2e-4cad-97a9-791e1e6e2f1b','z1','{}',0,1,'[\"0.job-with-no-links.a.simple.bosh\",\"4b158758-db2e-4cad-97a9-791e1e6e2f1b.job-with-no-links.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"job_with_no_links\",\"templates\":[{\"name\":\"provider\",\"version\":\"e1ff4ff9a6304e1222484570a400788c55154b1c\",\"sha1\":\"8f4acc18bf8eba32c3333088c9a16e39008ae959\",\"blobstore_id\":\"b9d0849c-c36e-4816-a263-5a9a9daa8ea6\"}],\"template\":\"provider\",\"version\":\"e1ff4ff9a6304e1222484570a400788c55154b1c\",\"sha1\":\"8f4acc18bf8eba32c3333088c9a16e39008ae959\",\"blobstore_id\":\"b9d0849c-c36e-4816-a263-5a9a9daa8ea6\"},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"job_with_no_links\",\"id\":\"4b158758-db2e-4cad-97a9-791e1e6e2f1b\",\"az\":\"z1\",\"networks\":{\"a\":{\"ip\":\"192.168.1.4\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{\"bosh\":{\"password\":\"foobar\"}},\"packages\":{},\"properties\":{\"provider\":{\"a\":\"default_a\",\"b\":null,\"c\":\"default_c\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.4\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true},\"persistent_disk\":0,\"template_hashes\":{\"provider\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"43eca40b-402f-4e3a-987c-be754c1ec58b\",\"sha1\":\"0f48286800bd819218cde66a3e06a602aed7fe4f\"},\"configuration_hash\":\"90c5d1358d128117989fc21f2897a25c99205e50\"}',NULL,NULL,'null',NULL,1,0);
/*!40000 ALTER TABLE `instances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `instances_templates`
--

DROP TABLE IF EXISTS `instances_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instances_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) NOT NULL,
  `template_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `instance_id` (`instance_id`,`template_id`),
  KEY `template_id` (`template_id`),
  CONSTRAINT `instances_templates_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`),
  CONSTRAINT `instances_templates_ibfk_2` FOREIGN KEY (`template_id`) REFERENCES `templates` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances_templates`
--

LOCK TABLES `instances_templates` WRITE;
/*!40000 ALTER TABLE `instances_templates` DISABLE KEYS */;
INSERT INTO `instances_templates` VALUES (1,1,2),(2,2,8),(3,4,19);
/*!40000 ALTER TABLE `instances_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ip_addresses`
--

DROP TABLE IF EXISTS `ip_addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ip_addresses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `network_name` varchar(255) DEFAULT NULL,
  `address` bigint(20) DEFAULT NULL,
  `static` tinyint(1) DEFAULT NULL,
  `instance_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `task_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `address` (`address`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `ip_addresses_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'a',3232235778,0,1,'2017-06-19 19:43:44','3'),(2,'a',3232235779,0,2,'2017-06-19 19:43:44','3'),(3,'a',3232235780,0,4,'2017-06-19 19:43:44','3');
/*!40000 ALTER TABLE `ip_addresses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_blobs`
--

DROP TABLE IF EXISTS `local_dns_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_blobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  `version` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `blobstore_id_sha1_idx` (`blobstore_id`,`sha1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_blobs`
--

LOCK TABLES `local_dns_blobs` WRITE;
/*!40000 ALTER TABLE `local_dns_blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `local_dns_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_records`
--

DROP TABLE IF EXISTS `local_dns_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `ip` varchar(255) NOT NULL,
  `instance_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_ip_idx` (`name`,`ip`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `local_dns_records_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_records`
--

LOCK TABLES `local_dns_records` WRITE;
/*!40000 ALTER TABLE `local_dns_records` DISABLE KEYS */;
/*!40000 ALTER TABLE `local_dns_records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `locks`
--

DROP TABLE IF EXISTS `locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `locks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `expired_at` datetime NOT NULL,
  `name` varchar(255) NOT NULL,
  `uid` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `uid` (`uid`),
  UNIQUE KEY `locks_name_index` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `locks`
--

LOCK TABLES `locks` WRITE;
/*!40000 ALTER TABLE `locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `locks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `log_bundles`
--

DROP TABLE IF EXISTS `log_bundles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `log_bundles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blobstore_id` varchar(255) NOT NULL,
  `timestamp` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `blobstore_id` (`blobstore_id`),
  KEY `log_bundles_timestamp_index` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `log_bundles`
--

LOCK TABLES `log_bundles` WRITE;
/*!40000 ALTER TABLE `log_bundles` DISABLE KEYS */;
/*!40000 ALTER TABLE `log_bundles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orphan_disks`
--

DROP TABLE IF EXISTS `orphan_disks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `orphan_disks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `disk_cid` varchar(255) NOT NULL,
  `size` int(11) DEFAULT NULL,
  `availability_zone` varchar(255) DEFAULT NULL,
  `deployment_name` varchar(255) NOT NULL,
  `instance_name` varchar(255) NOT NULL,
  `cloud_properties_json` longtext,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `disk_cid` (`disk_cid`),
  KEY `orphan_disks_orphaned_at_index` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orphan_disks`
--

LOCK TABLES `orphan_disks` WRITE;
/*!40000 ALTER TABLE `orphan_disks` DISABLE KEYS */;
/*!40000 ALTER TABLE `orphan_disks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orphan_snapshots`
--

DROP TABLE IF EXISTS `orphan_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `orphan_snapshots` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `orphan_disk_id` int(11) NOT NULL,
  `snapshot_cid` varchar(255) NOT NULL,
  `clean` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `snapshot_created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `snapshot_cid` (`snapshot_cid`),
  KEY `orphan_disk_id` (`orphan_disk_id`),
  KEY `orphan_snapshots_orphaned_at_index` (`created_at`),
  CONSTRAINT `orphan_snapshots_ibfk_1` FOREIGN KEY (`orphan_disk_id`) REFERENCES `orphan_disks` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orphan_snapshots`
--

LOCK TABLES `orphan_snapshots` WRITE;
/*!40000 ALTER TABLE `orphan_snapshots` DISABLE KEYS */;
/*!40000 ALTER TABLE `orphan_snapshots` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `packages`
--

DROP TABLE IF EXISTS `packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `version` varchar(255) NOT NULL,
  `blobstore_id` varchar(255) DEFAULT NULL,
  `sha1` varchar(255) DEFAULT NULL,
  `dependency_set_json` longtext NOT NULL,
  `release_id` int(11) NOT NULL,
  `fingerprint` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_id` (`release_id`,`name`,`version`),
  KEY `packages_fingerprint_index` (`fingerprint`),
  KEY `packages_sha1_index` (`sha1`),
  CONSTRAINT `packages_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages`
--

LOCK TABLES `packages` WRITE;
/*!40000 ALTER TABLE `packages` DISABLE KEYS */;
INSERT INTO `packages` VALUES (1,'pkg_1','7a4094dc99aa72d2d156d99e022d3baa37fb7c4b','6a860d32-b15a-461c-835a-2030c8414dc5','93105dab77ece0a8a107e98d939874d6aa07eb12','[]',1,'7a4094dc99aa72d2d156d99e022d3baa37fb7c4b'),(2,'pkg_2','fa48497a19f12e925b32fcb8f5ca2b42144e4444','b6ca44d0-6a00-43be-90b1-2d901282f35b','a10b9c8dce4c90c033ab3c3b75b1137dc06c6d5b','[]',1,'fa48497a19f12e925b32fcb8f5ca2b42144e4444'),(3,'pkg_3_depends_on_2','2dfa256bc0b0750ae9952118c428b0dcd1010305','4a33de48-8fae-4071-bca0-983ba1f3912f','1fdf95f253d4f280eef07a949d78a36f83a9b4f1','[\"pkg_2\"]',1,'2dfa256bc0b0750ae9952118c428b0dcd1010305');
/*!40000 ALTER TABLE `packages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `packages_release_versions`
--

DROP TABLE IF EXISTS `packages_release_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `packages_release_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `package_id` int(11) NOT NULL,
  `release_version_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `package_id` (`package_id`,`release_version_id`),
  KEY `release_version_id` (`release_version_id`),
  CONSTRAINT `packages_release_versions_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`),
  CONSTRAINT `packages_release_versions_ibfk_2` FOREIGN KEY (`release_version_id`) REFERENCES `release_versions` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages_release_versions`
--

LOCK TABLES `packages_release_versions` WRITE;
/*!40000 ALTER TABLE `packages_release_versions` DISABLE KEYS */;
INSERT INTO `packages_release_versions` VALUES (1,1,1),(2,2,1),(3,3,1);
/*!40000 ALTER TABLE `packages_release_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `persistent_disks`
--

DROP TABLE IF EXISTS `persistent_disks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `persistent_disks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) NOT NULL,
  `disk_cid` varchar(255) NOT NULL,
  `size` int(11) DEFAULT NULL,
  `active` tinyint(1) DEFAULT '0',
  `cloud_properties_json` longtext,
  `name` varchar(255) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `disk_cid` (`disk_cid`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `persistent_disks_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `persistent_disks`
--

LOCK TABLES `persistent_disks` WRITE;
/*!40000 ALTER TABLE `persistent_disks` DISABLE KEYS */;
/*!40000 ALTER TABLE `persistent_disks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `records`
--

DROP TABLE IF EXISTS `records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `type` varchar(10) DEFAULT NULL,
  `content` varchar(4098) DEFAULT NULL,
  `ttl` int(11) DEFAULT NULL,
  `prio` int(11) DEFAULT NULL,
  `change_date` int(11) DEFAULT NULL,
  `domain_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `records_name_index` (`name`),
  KEY `records_domain_id_index` (`domain_id`),
  KEY `records_name_type_index` (`name`,`type`),
  CONSTRAINT `records_ibfk_1` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1497901448,1),(2,'bosh','NS','ns.bosh',14400,NULL,1497901448,1),(3,'ns.bosh','A',NULL,18000,NULL,1497901448,1),(4,'0.my-api.a.simple.bosh','A','192.168.1.2',300,NULL,1497901430,1),(5,'1.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'1.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.1.168.192.in-addr.arpa','PTR','0.my-api.a.simple.bosh',300,NULL,1497901430,2),(8,'f874703e-1d88-468e-9bd9-57cb91ffd3e9.my-api.a.simple.bosh','A','192.168.1.2',300,NULL,1497901430,1),(9,'2.1.168.192.in-addr.arpa','PTR','f874703e-1d88-468e-9bd9-57cb91ffd3e9.my-api.a.simple.bosh',300,NULL,1497901430,2),(10,'0.aliased-postgres.a.simple.bosh','A','192.168.1.3',300,NULL,1497901436,1),(11,'3.1.168.192.in-addr.arpa','PTR','0.aliased-postgres.a.simple.bosh',300,NULL,1497901436,2),(12,'5f9cc0ab-a474-40ed-995e-97680c02189c.aliased-postgres.a.simple.bosh','A','192.168.1.3',300,NULL,1497901436,1),(13,'3.1.168.192.in-addr.arpa','PTR','5f9cc0ab-a474-40ed-995e-97680c02189c.aliased-postgres.a.simple.bosh',300,NULL,1497901436,2),(14,'0.job-with-no-links.a.simple.bosh','A','192.168.1.4',300,NULL,1497901442,1),(15,'4.1.168.192.in-addr.arpa','PTR','0.job-with-no-links.a.simple.bosh',300,NULL,1497901442,2),(16,'4b158758-db2e-4cad-97a9-791e1e6e2f1b.job-with-no-links.a.simple.bosh','A','192.168.1.4',300,NULL,1497901442,1),(17,'4.1.168.192.in-addr.arpa','PTR','4b158758-db2e-4cad-97a9-791e1e6e2f1b.job-with-no-links.a.simple.bosh',300,NULL,1497901442,2);
/*!40000 ALTER TABLE `records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `release_versions`
--

DROP TABLE IF EXISTS `release_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `release_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `version` varchar(255) NOT NULL,
  `release_id` int(11) NOT NULL,
  `commit_hash` varchar(255) DEFAULT 'unknown',
  `uncommitted_changes` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `release_id` (`release_id`),
  CONSTRAINT `release_versions_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions`
--

LOCK TABLES `release_versions` WRITE;
/*!40000 ALTER TABLE `release_versions` DISABLE KEYS */;
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'f419326ca',1);
/*!40000 ALTER TABLE `release_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `release_versions_templates`
--

DROP TABLE IF EXISTS `release_versions_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `release_versions_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `release_version_id` int(11) NOT NULL,
  `template_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_version_id` (`release_version_id`,`template_id`),
  KEY `template_id` (`template_id`),
  CONSTRAINT `release_versions_templates_ibfk_1` FOREIGN KEY (`release_version_id`) REFERENCES `release_versions` (`id`),
  CONSTRAINT `release_versions_templates_ibfk_2` FOREIGN KEY (`template_id`) REFERENCES `templates` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions_templates`
--

LOCK TABLES `release_versions_templates` WRITE;
/*!40000 ALTER TABLE `release_versions_templates` DISABLE KEYS */;
INSERT INTO `release_versions_templates` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5),(6,1,6),(7,1,7),(8,1,8),(9,1,9),(10,1,10),(11,1,11),(12,1,12),(13,1,13),(14,1,14),(15,1,15),(16,1,16),(17,1,17),(18,1,18),(19,1,19),(20,1,20);
/*!40000 ALTER TABLE `release_versions_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `releases`
--

DROP TABLE IF EXISTS `releases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `releases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `releases`
--

LOCK TABLES `releases` WRITE;
/*!40000 ALTER TABLE `releases` DISABLE KEYS */;
INSERT INTO `releases` VALUES (1,'bosh-release');
/*!40000 ALTER TABLE `releases` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `rendered_templates_archives`
--

DROP TABLE IF EXISTS `rendered_templates_archives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rendered_templates_archives` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) NOT NULL,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(255) NOT NULL,
  `content_sha1` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `instance_id` (`instance_id`),
  KEY `rendered_templates_archives_created_at_index` (`created_at`),
  CONSTRAINT `rendered_templates_archives_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rendered_templates_archives`
--

LOCK TABLES `rendered_templates_archives` WRITE;
/*!40000 ALTER TABLE `rendered_templates_archives` DISABLE KEYS */;
INSERT INTO `rendered_templates_archives` VALUES (1,1,'d07a87b8-163c-41ed-b513-030361bcab8a','e6b1c0ad3e2b6751d8372b894196198c3a6c9f99','0125968ca3f0dc196a37d2ca9aa446bbdf05bde4','2017-06-19 19:43:44'),(2,2,'85c3210c-2a0b-44c0-92df-f8afaea2cd9e','44fb3c677b9969e2541412d24a64b6ee7e30e7d0','4e4c9c0b7e76b5bc955b215edbd839e427d581aa','2017-06-19 19:43:44'),(3,4,'43eca40b-402f-4e3a-987c-be754c1ec58b','0f48286800bd819218cde66a3e06a602aed7fe4f','90c5d1358d128117989fc21f2897a25c99205e50','2017-06-19 19:43:44');
/*!40000 ALTER TABLE `rendered_templates_archives` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `runtime_configs`
--

DROP TABLE IF EXISTS `runtime_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `runtime_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `properties` longtext,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `runtime_configs_created_at_index` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `runtime_configs`
--

LOCK TABLES `runtime_configs` WRITE;
/*!40000 ALTER TABLE `runtime_configs` DISABLE KEYS */;
/*!40000 ALTER TABLE `runtime_configs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schema_migrations` (
  `filename` varchar(255) NOT NULL,
  PRIMARY KEY (`filename`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schema_migrations`
--

LOCK TABLES `schema_migrations` WRITE;
/*!40000 ALTER TABLE `schema_migrations` DISABLE KEYS */;
INSERT INTO `schema_migrations` VALUES ('20110209010747_initial.rb'),('20110406055800_add_task_user.rb'),('20110518225809_remove_cid_constrain.rb'),('20110617211923_add_deployments_release_versions.rb'),('20110622212607_add_task_checkpoint_timestamp.rb'),('20110628023039_add_state_to_instances.rb'),('20110709012332_add_disk_size_to_instances.rb'),('20110906183441_add_log_bundles.rb'),('20110907194830_add_logs_json_to_templates.rb'),('20110915205610_add_persistent_disks.rb'),('20111005180929_add_properties.rb'),('20111110024617_add_deployment_problems.rb'),('20111216214145_recreate_support_for_vms.rb'),('20120102084027_add_credentials_to_vms.rb'),('20120427235217_allow_multiple_releases_per_deployment.rb'),('20120524175805_add_task_type.rb'),('20120614001930_delete_redundant_deployment_release_relation.rb'),('20120822004528_add_fingerprint_to_templates_and_packages.rb'),('20120830191244_add_properties_to_templates.rb'),('20121106190739_persist_vm_env.rb'),('20130222232131_add_sha1_to_stemcells.rb'),('20130312211407_add_commit_hash_to_release_versions.rb'),('20130409235338_snapshot.rb'),('20130530164918_add_paused_flag_to_instance.rb'),('20130531172604_add_director_attributes.rb'),('20131121182231_add_rendered_templates_archives.rb'),('20131125232201_rename_rendered_templates_archives_blob_id_and_checksum_columns.rb'),('20140116002324_pivot_director_attributes.rb'),('20140124225348_proper_pk_for_attributes.rb'),('20140731215410_increase_text_limit_for_data_columns.rb'),('20141204234517_add_cloud_properties_to_persistent_disk.rb'),('20150102234124_denormalize_task_user_id_to_task_username.rb'),('20150223222605_increase_manifest_text_limit.rb'),('20150224193313_use_larger_text_types.rb'),('20150331002413_add_cloud_configs.rb'),('20150401184803_add_cloud_config_to_deployments.rb'),('20150513225143_ip_addresses.rb'),('20150611193110_add_trusted_certs_sha1_to_vms.rb'),('20150619135210_add_os_name_and_version_to_stemcells.rb'),('20150702004608_add_links.rb'),('20150708231924_add_link_spec.rb'),('20150716170926_allow_null_on_blobstore_id_and_sha1_on_package.rb'),('20150724183256_add_debugging_to_ip_addresses.rb'),('20150730225029_add_uuid_to_instances.rb'),('20150803215805_add_availabililty_zone_and_cloud_properties_to_instances.rb'),('20150804211419_add_compilation_flag_to_instance.rb'),('20150918003455_add_bootstrap_node_to_instance.rb'),('20151008232214_add_dns_records.rb'),('20151015172551_add_orphan_disks_and_snapshots.rb'),('20151030222853_add_templates_to_instance.rb'),('20151031001039_add_spec_to_instance.rb'),('20151109190602_rename_orphan_columns.rb'),('20151223172000_rename_requires_json.rb'),('20151229184742_add_vm_attributes_to_instance.rb'),('20160106162749_runtime_configs.rb'),('20160106163433_add_runtime_configs_to_deployments.rb'),('20160108191637_drop_vm_env_json_from_instance.rb'),('20160121003800_drop_vms_fkeys.rb'),('20160202162216_add_post_start_completed_to_instance.rb'),('20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb'),('20160211174110_add_events.rb'),('20160211193904_add_scopes_to_deployment.rb'),('20160219175840_add_column_teams_to_deployments.rb'),('20160224222508_add_deployment_name_to_task.rb'),('20160225182206_rename_post_start_completed.rb'),('20160324181932_create_delayed_jobs.rb'),('20160324182211_add_locks.rb'),('20160329201256_set_instances_with_nil_serial_to_false.rb'),('20160331225404_backfill_stemcell_os.rb'),('20160411104407_add_task_started_at.rb'),('20160414183654_set_teams_on_task.rb'),('20160427164345_add_teams.rb'),('20160511191928_ephemeral_blobs.rb'),('20160513102035_add_tracking_to_instance.rb'),('20160531164756_add_local_dns_blobs.rb'),('20160614182106_change_text_to_longtext_for_mysql.rb'),('20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb'),('20160706131605_change_events_id_type.rb'),('20160708234509_add_local_dns_records.rb'),('20160712171230_add_version_to_local_dns_blobs.rb'),('20160803151600_add_name_to_persistent_disks.rb'),('20161031204534_populate_lifecycle_on_instance_spec.rb');
/*!40000 ALTER TABLE `schema_migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `snapshots`
--

DROP TABLE IF EXISTS `snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `snapshots` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `persistent_disk_id` int(11) NOT NULL,
  `clean` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `snapshot_cid` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `snapshot_cid` (`snapshot_cid`),
  KEY `persistent_disk_id` (`persistent_disk_id`),
  CONSTRAINT `snapshots_ibfk_1` FOREIGN KEY (`persistent_disk_id`) REFERENCES `persistent_disks` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `snapshots`
--

LOCK TABLES `snapshots` WRITE;
/*!40000 ALTER TABLE `snapshots` DISABLE KEYS */;
/*!40000 ALTER TABLE `snapshots` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stemcells`
--

DROP TABLE IF EXISTS `stemcells`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stemcells` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `version` varchar(255) NOT NULL,
  `cid` varchar(255) NOT NULL,
  `sha1` varchar(255) DEFAULT NULL,
  `operating_system` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`version`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stemcells`
--

LOCK TABLES `stemcells` WRITE;
/*!40000 ALTER TABLE `stemcells` DISABLE KEYS */;
INSERT INTO `stemcells` VALUES (1,'ubuntu-stemcell','1','68aab7c44c857217641784806e2eeac4a3a99d1c','shawone','toronto-os');
/*!40000 ALTER TABLE `stemcells` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tasks`
--

DROP TABLE IF EXISTS `tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `state` varchar(255) NOT NULL,
  `timestamp` datetime NOT NULL,
  `description` varchar(255) NOT NULL,
  `result` longtext,
  `output` varchar(255) DEFAULT NULL,
  `checkpoint_time` datetime DEFAULT NULL,
  `type` varchar(255) NOT NULL,
  `username` varchar(255) DEFAULT NULL,
  `deployment_name` varchar(255) DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tasks_state_index` (`state`),
  KEY `tasks_timestamp_index` (`timestamp`),
  KEY `tasks_description_index` (`description`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2017-06-19 19:43:43','create release','Created release \'bosh-release/0+dev.1\'','/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-26400/sandbox/boshdir/tasks/1','2017-06-19 19:43:42','update_release','test',NULL,'2017-06-19 19:43:42'),(2,'done','2017-06-19 19:43:43','create stemcell','/stemcells/ubuntu-stemcell/1','/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-26400/sandbox/boshdir/tasks/2','2017-06-19 19:43:43','update_stemcell','test',NULL,'2017-06-19 19:43:43'),(3,'done','2017-06-19 19:44:07','create deployment','/deployments/simple','/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-26400/sandbox/boshdir/tasks/3','2017-06-19 19:43:44','update_deployment','test','simple','2017-06-19 19:43:44'),(4,'done','2017-06-19 19:44:09','create deployment','/deployments/simple','/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-26400/sandbox/boshdir/tasks/4','2017-06-19 19:44:08','update_deployment','test','simple','2017-06-19 19:44:08');
/*!40000 ALTER TABLE `tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tasks_teams`
--

DROP TABLE IF EXISTS `tasks_teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tasks_teams` (
  `task_id` int(11) NOT NULL,
  `team_id` int(11) NOT NULL,
  UNIQUE KEY `task_id` (`task_id`,`team_id`),
  KEY `team_id` (`team_id`),
  CONSTRAINT `tasks_teams_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `tasks_teams_ibfk_2` FOREIGN KEY (`team_id`) REFERENCES `teams` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks_teams`
--

LOCK TABLES `tasks_teams` WRITE;
/*!40000 ALTER TABLE `tasks_teams` DISABLE KEYS */;
/*!40000 ALTER TABLE `tasks_teams` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teams`
--

DROP TABLE IF EXISTS `teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `teams` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teams`
--

LOCK TABLES `teams` WRITE;
/*!40000 ALTER TABLE `teams` DISABLE KEYS */;
/*!40000 ALTER TABLE `teams` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `templates`
--

DROP TABLE IF EXISTS `templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `version` varchar(255) NOT NULL,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(255) NOT NULL,
  `package_names_json` longtext NOT NULL,
  `release_id` int(11) NOT NULL,
  `logs_json` longtext,
  `fingerprint` varchar(255) DEFAULT NULL,
  `properties_json` longtext,
  `consumes_json` varchar(255) DEFAULT NULL,
  `provides_json` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_id` (`release_id`,`name`,`version`),
  KEY `templates_fingerprint_index` (`fingerprint`),
  KEY `templates_sha1_index` (`sha1`),
  CONSTRAINT `templates_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `templates`
--

LOCK TABLES `templates` WRITE;
/*!40000 ALTER TABLE `templates` DISABLE KEYS */;
INSERT INTO `templates` VALUES (1,'addon','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','be3cec2f-5077-4bcc-8eaf-9e310e11b71d','f9d97ea17974f2ab5e7a9c1b12e93d5553b9afdc','[]',1,'null','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','{}','[{\"name\":\"db\",\"type\":\"db\"}]',NULL),(2,'api_server','76ff26229b603294a6f540e53faf68a2424cdf59','65141b20-f5d7-44d9-be8d-9510d7e7a0ce','1ed133671ae62207caf6f5c974adc30d1782816f','[\"pkg_3_depends_on_2\"]',1,'null','76ff26229b603294a6f540e53faf68a2424cdf59','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}]',NULL),(3,'api_server_with_bad_link_types','058b26819bd6561a75c2fed45ec49e671c9fbc6a','c1cf8c19-6abf-4770-97d1-6a5797282419','70fbd7230f784098c11fcb242b44ac69e38736e0','[\"pkg_3_depends_on_2\"]',1,'null','058b26819bd6561a75c2fed45ec49e671c9fbc6a','{}','[{\"name\":\"db\",\"type\":\"bad_link\"},{\"name\":\"backup_db\",\"type\":\"bad_link_2\"},{\"name\":\"some_link_name\",\"type\":\"bad_link_3\"}]',NULL),(4,'api_server_with_bad_optional_links','8a2485f1de3d99657e101fd269202c39cf3b5d73','496c56ff-b513-4eb7-b654-eb633a839510','6989eac182ee1b39eadf95e6cf8324c381fe891c','[\"pkg_3_depends_on_2\"]',1,'null','8a2485f1de3d99657e101fd269202c39cf3b5d73','{}','[{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}]',NULL),(5,'api_server_with_optional_db_link','00831c288b4a42454543ff69f71360634bd06b7b','8ff6716b-e5c0-478c-adc2-804a57008f32','1fe30527b295bd62b852ba917257cbcdd230e9ae','[\"pkg_3_depends_on_2\"]',1,'null','00831c288b4a42454543ff69f71360634bd06b7b','{}','[{\"name\":\"db\",\"type\":\"db\",\"optional\":true}]',NULL),(6,'api_server_with_optional_links_1','0efc908dd04d84858e3cf8b75c326f35af5a5a98','4f2a9c1d-a5b7-40ec-817f-ec480d7becae','b6d595ecd007e222e3e812b4a0d351ad1372ce50','[\"pkg_3_depends_on_2\"]',1,'null','0efc908dd04d84858e3cf8b75c326f35af5a5a98','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"},{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}]',NULL),(7,'api_server_with_optional_links_2','15f815868a057180e21dbac61629f73ad3558fec','6080c1c5-aafa-45de-9651-df06e1c1d776','c0aa87b22ba3742b52a60088ff2bca87f5bcc2cf','[\"pkg_3_depends_on_2\"]',1,'null','15f815868a057180e21dbac61629f73ad3558fec','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\",\"optional\":true}]',NULL),(8,'backup_database','29322b71c9a475beae1249873d8f6e136335448b','2dd9102e-009d-46a2-b59d-6bdedb54ce33','2e0510f7f6669c21bd89778f8e6f9caa510717eb','[]',1,'null','29322b71c9a475beae1249873d8f6e136335448b','{}',NULL,'[{\"name\":\"backup_db\",\"type\":\"db\"}]'),(9,'consumer','142c10d6cd586cd9b092b2618922194b608160f7','02df3409-0a45-43d4-b36a-81ac5b58a759','9351f0016eb2800c2b32b3217b0159ceacd2e07a','[]',1,'null','142c10d6cd586cd9b092b2618922194b608160f7','{}','[{\"name\":\"provider\",\"type\":\"provider\"}]',NULL),(10,'database','f2929b306c9d89bede1b37cc27f8fa71bb1fd8e8','a9e0fd21-b7f6-45cc-91a8-6af27da5c6bc','f9150293b4e94a1f3a8ae8a5f5859d990c076038','[]',1,'null','f2929b306c9d89bede1b37cc27f8fa71bb1fd8e8','{\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}',NULL,'[{\"name\":\"db\",\"type\":\"db\"}]'),(11,'database_with_two_provided_link_of_same_type','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','fbb7d721-9a17-41ed-adce-71ffef84cb0a','7ddea1ea3ec58019df5b88e81c83161e89d619eb','[]',1,'null','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','{\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}',NULL,'[{\"name\":\"db1\",\"type\":\"db\"},{\"name\":\"db2\",\"type\":\"db\"}]'),(12,'errand_with_links','87c3457f84c8e06f950c08c7e114df2cad29c43d','b814ba55-7071-4ae1-a4c4-a9b464ca550e','ab8f4832ea641459aa3a9f7e4da83c82cb662add','[]',1,'null','87c3457f84c8e06f950c08c7e114df2cad29c43d','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}]',NULL),(13,'http_endpoint_provider_with_property_types','30978e9fd0d29e52fe0369262e11fbcea1283889','31ea3e28-49a2-43c2-a49e-32efeb048576','3adf9a51de2a90c10b64c7cd13e95b3b19282bb3','[]',1,'null','30978e9fd0d29e52fe0369262e11fbcea1283889','{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"Has a type password and no default value\",\"type\":\"password\"}}',NULL,'[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}]'),(14,'http_proxy_with_requires','4592ccbff484de43750068a1b7eab120bcf80b50','a3b813f5-4ddb-4858-9299-2d39bcb0b531','0f2cd9625664d546342a57288c02fc209bfd4c33','[]',1,'null','4592ccbff484de43750068a1b7eab120bcf80b50','{\"http_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"http_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null}}','[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"},{\"name\":\"logs_http_endpoint\",\"type\":\"http_endpoint2\",\"optional\":true}]',NULL),(15,'http_server_with_provides','64244f12f2db2e7d93ccfbc13be744df87013389','c18a1426-1747-4cb6-931a-fe164191b469','ed3d9cfec9a11d57de8a6262156e5caccc67d4ff','[]',1,'null','64244f12f2db2e7d93ccfbc13be744df87013389','{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}',NULL,'[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}]'),(16,'kv_http_server','044ec02730e6d068ecf88a0d37fe48937687bdba','eefcc4d0-6d1b-4593-aa6c-8726c522afd6','e0721601ad3329cae1b350c10d6466f1b998d65e','[]',1,'null','044ec02730e6d068ecf88a0d37fe48937687bdba','{\"kv_http_server.listen_port\":{\"description\":\"Port to listen on\",\"default\":8080}}','[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}]','[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}]'),(17,'mongo_db','6a6e241c0bd5c203397f0213bee9d3d28a4ff35f','f1fdc762-809b-419a-9044-1673af19c710','21c8c1475cd8b9a2ef799ede32e8fb91c8913b3a','[\"pkg_1\"]',1,'null','6a6e241c0bd5c203397f0213bee9d3d28a4ff35f','{}',NULL,'[{\"name\":\"read_only_db\",\"type\":\"db\"}]'),(18,'node','c12835da15038bedad6c49d20a2dda00375a0dc0','743cf230-0c7f-4686-8939-c5c471f9dd03','db5b20b2005e48edc0e22cf2c215208d14fa6980','[]',1,'null','c12835da15038bedad6c49d20a2dda00375a0dc0','{}','[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}]','[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}]'),(19,'provider','e1ff4ff9a6304e1222484570a400788c55154b1c','b9d0849c-c36e-4816-a263-5a9a9daa8ea6','8f4acc18bf8eba32c3333088c9a16e39008ae959','[]',1,'null','e1ff4ff9a6304e1222484570a400788c55154b1c','{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"b\":{\"description\":\"description for b\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}',NULL,'[{\"name\":\"provider\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}]'),(20,'provider_fail','314c385e96711cb5d56dd909a086563dae61bc37','73e31522-75cf-4222-a501-34dfa943c8d1','b755e487a4f5b2d808cf615e414d286802886283','[]',1,'null','314c385e96711cb5d56dd909a086563dae61bc37','{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}',NULL,'[{\"name\":\"provider_fail\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}]');
/*!40000 ALTER TABLE `templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vms`
--

DROP TABLE IF EXISTS `vms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `agent_id` varchar(255) NOT NULL,
  `cid` varchar(255) DEFAULT NULL,
  `deployment_id` int(11) NOT NULL,
  `credentials_json` text,
  `env_json` text,
  `trusted_certs_sha1` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  PRIMARY KEY (`id`),
  UNIQUE KEY `agent_id` (`agent_id`),
  KEY `deployment_id` (`deployment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vms`
--

LOCK TABLES `vms` WRITE;
/*!40000 ALTER TABLE `vms` DISABLE KEYS */;
/*!40000 ALTER TABLE `vms` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-06-19 15:44:16
