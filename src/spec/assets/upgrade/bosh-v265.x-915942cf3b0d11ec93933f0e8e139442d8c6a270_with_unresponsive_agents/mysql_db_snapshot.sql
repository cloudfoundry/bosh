-- MySQL dump 10.13  Distrib 5.7.21, for osx10.12 (x86_64)
--
-- Host: 127.0.0.1    Database: b79b650239464d22b19f6cf4ee634d97
-- ------------------------------------------------------
-- Server version	5.7.21

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
-- Table structure for table `agent_dns_versions`
--

DROP TABLE IF EXISTS `agent_dns_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agent_dns_versions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `agent_id` varchar(255) NOT NULL,
  `dns_version` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `agent_id` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `agent_dns_versions`
--

LOCK TABLES `agent_dns_versions` WRITE;
/*!40000 ALTER TABLE `agent_dns_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `agent_dns_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blobs`
--

DROP TABLE IF EXISTS `blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blobstore_id` varchar(255) NOT NULL,
  `sha1` varchar(512) NOT NULL,
  `created_at` datetime NOT NULL,
  `type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blobs`
--

LOCK TABLES `blobs` WRITE;
/*!40000 ALTER TABLE `blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `blobs` ENABLE KEYS */;
UNLOCK TABLES;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cloud_configs`
--

LOCK TABLES `cloud_configs` WRITE;
/*!40000 ALTER TABLE `cloud_configs` DISABLE KEYS */;
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
  `sha1` varchar(512) NOT NULL,
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
INSERT INTO `compiled_packages` VALUES (1,'c5761eb9-6abd-4f20-5221-abb1a68c8afc','bed2a685fc460da83cadfc87120848805d34d654','[]',1,8,'97d170e1550eee4afc0af065b78cda302a97674c','toronto-os','1'),(2,'b25cb9e8-8f0a-4940-51c4-2fa4a8528e7b','51d5c98a29cb7048d97c8d9d15e4b8df985c3625','[[\"foo\",\"0ee95716c58cf7aab3ef7301ff907118552c2dda\"]]',1,3,'2ab05f5881c448e1fdf9f2438f31a41d654c27e6','toronto-os','1');
/*!40000 ALTER TABLE `compiled_packages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `configs`
--

DROP TABLE IF EXISTS `configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `type` varchar(255) NOT NULL,
  `content` longtext NOT NULL,
  `created_at` datetime NOT NULL,
  `deleted` tinyint(1) DEFAULT '0',
  `team_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `configs`
--

LOCK TABLES `configs` WRITE;
/*!40000 ALTER TABLE `configs` DISABLE KEYS */;
INSERT INTO `configs` VALUES (1,'default','cloud','azs:\n- cloud_properties: {}\n  name: zone-1\n- cloud_properties: {}\n  name: zone-2\n- cloud_properties: {}\n  name: zone-3\ncompilation:\n  az: zone-1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: zone-1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n  - az: zone-2\n    cloud_properties: {}\n    dns:\n    - 192.168.2.1\n    - 192.168.2.2\n    gateway: 192.168.2.1\n    range: 192.168.2.0/24\n    reserved: []\n    static:\n    - 192.168.2.10\n  - az: zone-3\n    cloud_properties: {}\n    dns:\n    - 192.168.3.1\n    - 192.168.3.2\n    gateway: 192.168.3.1\n    range: 192.168.3.0/24\n    reserved: []\n    static:\n    - 192.168.3.10\nvm_types:\n- cloud_properties: {}\n  name: a\n','2018-04-10 17:43:08',0,NULL);
/*!40000 ALTER TABLE `configs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cpi_configs`
--

DROP TABLE IF EXISTS `cpi_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cpi_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `properties` longtext,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `cpi_configs_created_at_index` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cpi_configs`
--

LOCK TABLES `cpi_configs` WRITE;
/*!40000 ALTER TABLE `cpi_configs` DISABLE KEYS */;
/*!40000 ALTER TABLE `cpi_configs` ENABLE KEYS */;
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
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
  `link_spec_json` longtext,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'simple','---\ndirector_uuid: deadbeef\njobs:\n- azs:\n  - zone-1\n  - zone-2\n  - zone-3\n  instances: 3\n  name: foobar\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  templates:\n  - name: foobar\n  vm_type: a\nname: simple\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}');
/*!40000 ALTER TABLE `deployments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deployments_configs`
--

DROP TABLE IF EXISTS `deployments_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments_configs` (
  `deployment_id` int(11) NOT NULL,
  `config_id` int(11) NOT NULL,
  UNIQUE KEY `deployment_id_config_id_unique` (`deployment_id`,`config_id`),
  KEY `config_id` (`config_id`),
  CONSTRAINT `deployments_configs_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `deployments_configs_ibfk_2` FOREIGN KEY (`config_id`) REFERENCES `configs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_configs`
--

LOCK TABLES `deployments_configs` WRITE;
/*!40000 ALTER TABLE `deployments_configs` DISABLE KEYS */;
INSERT INTO `deployments_configs` VALUES (1,1);
/*!40000 ALTER TABLE `deployments_configs` ENABLE KEYS */;
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `director_attributes`
--

LOCK TABLES `director_attributes` WRITE;
/*!40000 ALTER TABLE `director_attributes` DISABLE KEYS */;
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `domains`
--

LOCK TABLES `domains` WRITE;
/*!40000 ALTER TABLE `domains` DISABLE KEYS */;
INSERT INTO `domains` VALUES (1,'bosh',NULL,NULL,'NATIVE',NULL,NULL),(2,'1.168.192.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL),(3,'2.168.192.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL),(4,'3.168.192.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL);
/*!40000 ALTER TABLE `domains` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `errand_runs`
--

DROP TABLE IF EXISTS `errand_runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `errand_runs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `deployment_id` int(11) NOT NULL DEFAULT '-1',
  `errand_name` longtext,
  `successful_state_hash` varchar(512) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `deployment_id` (`deployment_id`),
  CONSTRAINT `errand_runs_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `errand_runs`
--

LOCK TABLES `errand_runs` WRITE;
/*!40000 ALTER TABLE `errand_runs` DISABLE KEYS */;
/*!40000 ALTER TABLE `errand_runs` ENABLE KEYS */;
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
INSERT INTO `events` VALUES (1,NULL,'_director','2018-04-10 17:43:03','start','director','deadbeef',NULL,NULL,NULL,NULL,'{\"version\":\"0.0.0\"}'),(2,NULL,'_director','2018-04-10 17:43:03','start','worker','worker_0',NULL,NULL,NULL,NULL,'{}'),(3,NULL,'_director','2018-04-10 17:43:03','start','worker','worker_2',NULL,NULL,NULL,NULL,'{}'),(4,NULL,'_director','2018-04-10 17:43:03','start','worker','worker_1',NULL,NULL,NULL,NULL,'{}'),(5,NULL,'test','2018-04-10 17:43:04','acquire','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(6,NULL,'test','2018-04-10 17:43:06','release','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(7,NULL,'test','2018-04-10 17:43:08','update','cloud-config','default',NULL,NULL,NULL,NULL,'{}'),(8,NULL,'test','2018-04-10 17:43:09','create','deployment','simple',NULL,'3','simple',NULL,'{}'),(9,NULL,'test','2018-04-10 17:43:09','acquire','lock','lock:deployment:simple',NULL,'3','simple',NULL,'{}'),(10,NULL,'test','2018-04-10 17:43:09','acquire','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(11,NULL,'test','2018-04-10 17:43:09','release','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(12,NULL,'test','2018-04-10 17:43:09','acquire','lock','lock:compile:8:toronto-os/1',NULL,'3','simple',NULL,'{}'),(13,NULL,'test','2018-04-10 17:43:09','create','instance','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(14,NULL,'test','2018-04-10 17:43:09','create','vm',NULL,NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(15,14,'test','2018-04-10 17:43:10','create','vm','49385',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(16,13,'test','2018-04-10 17:43:10','create','instance','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(17,NULL,'test','2018-04-10 17:43:11','delete','instance','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(18,NULL,'test','2018-04-10 17:43:11','delete','vm','49385',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(19,18,'test','2018-04-10 17:43:11','delete','vm','49385',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(20,17,'test','2018-04-10 17:43:11','delete','instance','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70',NULL,'3','simple','compilation-05e2b9ef-e347-4e5f-a401-7b593db0b309/745f945e-f2c8-4c70-aa95-7795e866bf70','{}'),(21,NULL,'test','2018-04-10 17:43:11','release','lock','lock:compile:8:toronto-os/1',NULL,'3','simple',NULL,'{}'),(22,NULL,'test','2018-04-10 17:43:11','acquire','lock','lock:compile:3:toronto-os/1',NULL,'3','simple',NULL,'{}'),(23,NULL,'test','2018-04-10 17:43:11','create','instance','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(24,NULL,'test','2018-04-10 17:43:11','create','vm',NULL,NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(25,24,'test','2018-04-10 17:43:12','create','vm','49402',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(26,23,'test','2018-04-10 17:43:12','create','instance','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(27,NULL,'test','2018-04-10 17:43:13','delete','instance','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(28,NULL,'test','2018-04-10 17:43:13','delete','vm','49402',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(29,28,'test','2018-04-10 17:43:13','delete','vm','49402',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(30,27,'test','2018-04-10 17:43:13','delete','instance','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0',NULL,'3','simple','compilation-10ac4804-daf8-4dae-8136-e07286b3ad22/7e6cd081-3a7a-4a88-a2b5-919b37c92ed0','{}'),(31,NULL,'test','2018-04-10 17:43:13','release','lock','lock:compile:3:toronto-os/1',NULL,'3','simple',NULL,'{}'),(32,NULL,'test','2018-04-10 17:43:14','create','vm',NULL,NULL,'3','simple','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98','{}'),(33,NULL,'test','2018-04-10 17:43:14','create','vm',NULL,NULL,'3','simple','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9','{}'),(34,NULL,'test','2018-04-10 17:43:14','create','vm',NULL,NULL,'3','simple','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051','{}'),(35,32,'test','2018-04-10 17:43:14','create','vm','49426',NULL,'3','simple','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98','{}'),(36,33,'test','2018-04-10 17:43:14','create','vm','49430',NULL,'3','simple','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9','{}'),(37,34,'test','2018-04-10 17:43:14','create','vm','49431',NULL,'3','simple','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051','{}'),(38,NULL,'test','2018-04-10 17:43:15','create','instance','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9',NULL,'3','simple','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9','{\"az\":\"zone-1\"}'),(39,38,'test','2018-04-10 17:43:21','create','instance','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9',NULL,'3','simple','foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9','{}'),(40,NULL,'test','2018-04-10 17:43:21','create','instance','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98',NULL,'3','simple','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98','{\"az\":\"zone-2\"}'),(41,40,'test','2018-04-10 17:43:23','create','instance','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98',NULL,'3','simple','foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98','{}'),(42,NULL,'test','2018-04-10 17:43:23','create','instance','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051',NULL,'3','simple','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051','{\"az\":\"zone-3\"}'),(43,42,'test','2018-04-10 17:43:26','create','instance','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051',NULL,'3','simple','foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051','{}'),(44,8,'test','2018-04-10 17:43:26','create','deployment','simple',NULL,'3','simple',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(45,NULL,'test','2018-04-10 17:43:26','release','lock','lock:deployment:simple',NULL,'3','simple',NULL,'{}');
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
  `state` varchar(255) NOT NULL,
  `resurrection_paused` tinyint(1) DEFAULT '0',
  `uuid` varchar(255) DEFAULT NULL,
  `availability_zone` varchar(255) DEFAULT NULL,
  `cloud_properties` longtext,
  `compilation` tinyint(1) DEFAULT '0',
  `bootstrap` tinyint(1) DEFAULT '0',
  `dns_records` longtext,
  `spec_json` longtext,
  `vm_cid_bak` varchar(255) DEFAULT NULL,
  `agent_id_bak` varchar(255) DEFAULT NULL,
  `trusted_certs_sha1_bak` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  `update_completed` tinyint(1) DEFAULT '0',
  `ignore` tinyint(1) DEFAULT '0',
  `variable_set_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  UNIQUE KEY `vm_cid` (`vm_cid_bak`),
  UNIQUE KEY `agent_id` (`agent_id_bak`),
  KEY `deployment_id` (`deployment_id`),
  KEY `instance_table_variable_set_fkey` (`variable_set_id`),
  CONSTRAINT `instance_table_variable_set_fkey` FOREIGN KEY (`variable_set_id`) REFERENCES `variable_sets` (`id`),
  CONSTRAINT `instances_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'foobar',0,1,'started',0,'96be0e58-afa4-4015-882c-a1fbb615e4f9','zone-1','{}',0,1,'[\"0.foobar.a.simple.bosh\",\"96be0e58-afa4-4015-882c-a1fbb615e4f9.foobar.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"foobar\",\"templates\":[{\"name\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]}],\"template\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"foobar\",\"id\":\"96be0e58-afa4-4015-882c-a1fbb615e4f9\",\"az\":\"zone-1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"foo\":{\"name\":\"foo\",\"version\":\"0ee95716c58cf7aab3ef7301ff907118552c2dda.1\",\"sha1\":\"bed2a685fc460da83cadfc87120848805d34d654\",\"blobstore_id\":\"c5761eb9-6abd-4f20-5221-abb1a68c8afc\"},\"bar\":{\"name\":\"bar\",\"version\":\"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1\",\"sha1\":\"51d5c98a29cb7048d97c8d9d15e4b8df985c3625\",\"blobstore_id\":\"b25cb9e8-8f0a-4940-51c4-2fa4a8528e7b\"}},\"properties\":{\"foobar\":{\"test_property\":1,\"drain_type\":\"static\",\"dynamic_drain_wait1\":-3,\"dynamic_drain_wait2\":-2,\"network_name\":null,\"networks\":null}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"foobar\":\"277c90a7a6af9c09b651fa96f6240bb912b5ba47\"},\"rendered_templates_archive\":{\"blobstore_id\":\"52dca8b5-950f-4261-ba3c-8ba2e57a6231\",\"sha1\":\"e62d8691228726490720459d2917a7f697430a09\"},\"configuration_hash\":\"16729075ff69d072dfde2d4c9272eaf5bb2082af\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1),(2,'foobar',1,1,'started',0,'4f7103f4-e6a7-4fa9-a277-7fec76af1d98','zone-2','{}',0,0,'[\"1.foobar.a.simple.bosh\",\"4f7103f4-e6a7-4fa9-a277-7fec76af1d98.foobar.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"foobar\",\"templates\":[{\"name\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]}],\"template\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]},\"index\":1,\"bootstrap\":false,\"lifecycle\":\"service\",\"name\":\"foobar\",\"id\":\"4f7103f4-e6a7-4fa9-a277-7fec76af1d98\",\"az\":\"zone-2\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.2.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.2.1\",\"192.168.2.2\"],\"gateway\":\"192.168.2.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"foo\":{\"name\":\"foo\",\"version\":\"0ee95716c58cf7aab3ef7301ff907118552c2dda.1\",\"sha1\":\"bed2a685fc460da83cadfc87120848805d34d654\",\"blobstore_id\":\"c5761eb9-6abd-4f20-5221-abb1a68c8afc\"},\"bar\":{\"name\":\"bar\",\"version\":\"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1\",\"sha1\":\"51d5c98a29cb7048d97c8d9d15e4b8df985c3625\",\"blobstore_id\":\"b25cb9e8-8f0a-4940-51c4-2fa4a8528e7b\"}},\"properties\":{\"foobar\":{\"test_property\":1,\"drain_type\":\"static\",\"dynamic_drain_wait1\":-3,\"dynamic_drain_wait2\":-2,\"network_name\":null,\"networks\":null}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.2.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"foobar\":\"b64f50ead2117fbf809c6286ed92a216f60d5e48\"},\"rendered_templates_archive\":{\"blobstore_id\":\"b91887e3-1e3b-4c9f-b24d-11944083e0e3\",\"sha1\":\"5b88258110b41ea988350c8d94ab1ab3836f7dc1\"},\"configuration_hash\":\"56f75dca9c0460c56d5e20dc99f78533285efbc9\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1),(3,'foobar',2,1,'started',0,'b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051','zone-3','{}',0,0,'[\"2.foobar.a.simple.bosh\",\"b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051.foobar.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"foobar\",\"templates\":[{\"name\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]}],\"template\":\"foobar\",\"version\":\"47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"sha1\":\"6bd7fcfc936d567d33dadab3ccda36a7b445903b\",\"blobstore_id\":\"8cb34e85-8fb3-423f-9d5f-027bdb6205fb\",\"logs\":[]},\"index\":2,\"bootstrap\":false,\"lifecycle\":\"service\",\"name\":\"foobar\",\"id\":\"b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051\",\"az\":\"zone-3\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.3.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.3.1\",\"192.168.3.2\"],\"gateway\":\"192.168.3.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"foo\":{\"name\":\"foo\",\"version\":\"0ee95716c58cf7aab3ef7301ff907118552c2dda.1\",\"sha1\":\"bed2a685fc460da83cadfc87120848805d34d654\",\"blobstore_id\":\"c5761eb9-6abd-4f20-5221-abb1a68c8afc\"},\"bar\":{\"name\":\"bar\",\"version\":\"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1\",\"sha1\":\"51d5c98a29cb7048d97c8d9d15e4b8df985c3625\",\"blobstore_id\":\"b25cb9e8-8f0a-4940-51c4-2fa4a8528e7b\"}},\"properties\":{\"foobar\":{\"test_property\":1,\"drain_type\":\"static\",\"dynamic_drain_wait1\":-3,\"dynamic_drain_wait2\":-2,\"network_name\":null,\"networks\":null}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.3.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"foobar\":\"61dc45838cd8b4036f44fd2d78582caf84f51939\"},\"rendered_templates_archive\":{\"blobstore_id\":\"afa23157-4544-41de-acca-254e82e865cb\",\"sha1\":\"9365968a8fceed2a41762bb04c401e26f856d295\"},\"configuration_hash\":\"8fd71c8894a22d140ee9875d53730b8a2e60a1c2\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1);
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
INSERT INTO `instances_templates` VALUES (1,1,5),(2,2,5),(3,3,5);
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
  `static` tinyint(1) DEFAULT NULL,
  `instance_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `task_id` varchar(255) DEFAULT NULL,
  `address_str` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip_addresses_address_str_index` (`address_str`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `ip_addresses_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'a',0,1,'2018-04-10 17:43:09','3','3232235778'),(2,'a',0,2,'2018-04-10 17:43:09','3','3232236034'),(3,'a',0,3,'2018-04-10 17:43:09','3','3232236290');
/*!40000 ALTER TABLE `ip_addresses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_blobs`
--

DROP TABLE IF EXISTS `local_dns_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_blobs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `blob_id` int(11) NOT NULL,
  `version` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `local_dns_blobs_blob_id_fkey` (`blob_id`),
  CONSTRAINT `local_dns_blobs_blob_id_fkey` FOREIGN KEY (`blob_id`) REFERENCES `blobs` (`id`)
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
-- Table structure for table `local_dns_encoded_azs`
--

DROP TABLE IF EXISTS `local_dns_encoded_azs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_encoded_azs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_azs`
--

LOCK TABLES `local_dns_encoded_azs` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_azs` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_azs` VALUES (1,'zone-1'),(2,'zone-2'),(3,'zone-3');
/*!40000 ALTER TABLE `local_dns_encoded_azs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_encoded_instance_groups`
--

DROP TABLE IF EXISTS `local_dns_encoded_instance_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_encoded_instance_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `deployment_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `local_dns_encoded_instance_groups_name_deployment_id_index` (`name`,`deployment_id`),
  KEY `deployment_id` (`deployment_id`),
  CONSTRAINT `local_dns_encoded_instance_groups_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_instance_groups`
--

LOCK TABLES `local_dns_encoded_instance_groups` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_instance_groups` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_instance_groups` VALUES (1,'foobar',1);
/*!40000 ALTER TABLE `local_dns_encoded_instance_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_encoded_networks`
--

DROP TABLE IF EXISTS `local_dns_encoded_networks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_encoded_networks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_networks`
--

LOCK TABLES `local_dns_encoded_networks` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_networks` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_networks` VALUES (1,'a');
/*!40000 ALTER TABLE `local_dns_encoded_networks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `local_dns_records`
--

DROP TABLE IF EXISTS `local_dns_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `local_dns_records` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ip` varchar(255) NOT NULL,
  `az` varchar(255) DEFAULT NULL,
  `instance_group` varchar(255) DEFAULT NULL,
  `network` varchar(255) DEFAULT NULL,
  `deployment` varchar(255) DEFAULT NULL,
  `instance_id` int(11) DEFAULT NULL,
  `agent_id` varchar(255) DEFAULT NULL,
  `domain` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `local_dns_records_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_records`
--

LOCK TABLES `local_dns_records` WRITE;
/*!40000 ALTER TABLE `local_dns_records` DISABLE KEYS */;
INSERT INTO `local_dns_records` VALUES (1,'192.168.1.2','zone-1','foobar','a','simple',1,'28340494-a6e2-4bdb-b841-d04ac79d005f','bosh'),(2,'192.168.2.2','zone-2','foobar','a','simple',2,'7c3f1e58-a69b-4ccd-84e7-d49c76dd5c40','bosh'),(3,'192.168.3.2','zone-3','foobar','a','simple',3,'45cb1d41-d631-4dd1-9704-cee9da7a113d','bosh');
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
  `task_id` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `uid` (`uid`),
  UNIQUE KEY `locks_name_index` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
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
  `cpi` varchar(255) DEFAULT '',
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
  `sha1` varchar(512) DEFAULT NULL,
  `dependency_set_json` longtext NOT NULL,
  `release_id` int(11) NOT NULL,
  `fingerprint` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_id` (`release_id`,`name`,`version`),
  KEY `packages_fingerprint_index` (`fingerprint`),
  KEY `packages_sha1_index` (`sha1`),
  CONSTRAINT `packages_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages`
--

LOCK TABLES `packages` WRITE;
/*!40000 ALTER TABLE `packages` DISABLE KEYS */;
INSERT INTO `packages` VALUES (1,'a','821fcd0a441062473a386e9297e9cb48b5f189f4','0df0e3bf-aeaf-450a-843e-49d65c06a6ac','b8e6d53c143fdce484704ca0200a5479e7d99217','[\"b\"]',1,'821fcd0a441062473a386e9297e9cb48b5f189f4'),(2,'b','ec25004a81fc656a6c39871564f352d70268c637','98555db0-4671-4845-9b88-b19da9b0d84e','4755407d1d6b89e79a5d9151c4d267341452ebfc','[\"c\"]',1,'ec25004a81fc656a6c39871564f352d70268c637'),(3,'bar','f1267e1d4e06b60c91ef648fb9242e33ddcffa73','65336bc8-a119-4795-ba9e-87a9672abab9','459f6dcbc9bc1f5ca8601b622ab6a5dc0a809a9c','[\"foo\"]',1,'f1267e1d4e06b60c91ef648fb9242e33ddcffa73'),(4,'blocking_package','2ae8315faf952e6f69da493286387803ccfad248','9e06e62b-2638-40df-b653-68cd28ce873e','2bc5c706ea64b5a7551378b2182b2b408ebc401d','[]',1,'2ae8315faf952e6f69da493286387803ccfad248'),(5,'c','5bc40b65cca962dcc486673c6999d3b085b4a9ab','df91d505-de81-417a-99c7-0b0ec72e6c53','e703fc7042b92d3e053f90375e3829bbb7ff99b2','[]',1,'5bc40b65cca962dcc486673c6999d3b085b4a9ab'),(6,'errand1','7976e3d21a6d6d00885c44b0192f6daa8afc0587','a86a8c85-4267-4a48-b1d6-d023e197541e','0172d40395337ef5d6cf235e45cf6cdee1bd3a36','[]',1,'7976e3d21a6d6d00885c44b0192f6daa8afc0587'),(7,'fails_with_too_much_output','e505f41e8cec5608209392c06950bba5d995bdd8','26d47576-5b66-479a-b0d1-9640d3910033','1b3872c6cc27f51deffdffccaede9d3a2ff62fba','[]',1,'e505f41e8cec5608209392c06950bba5d995bdd8'),(8,'foo','0ee95716c58cf7aab3ef7301ff907118552c2dda','ca235d7d-a7ee-416b-bbd6-3453e449ce92','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(9,'foo_1','0ee95716c58cf7aab3ef7301ff907118552c2dda','bda8d5a5-902f-41e7-b4ae-1e6fec9dfa54','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(10,'foo_10','0ee95716c58cf7aab3ef7301ff907118552c2dda','fabebbba-602b-4282-a749-f7fa683c1eb7','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(11,'foo_2','0ee95716c58cf7aab3ef7301ff907118552c2dda','8265f379-27c7-4351-b8a0-054ed67f6541','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(12,'foo_3','0ee95716c58cf7aab3ef7301ff907118552c2dda','e676302f-8f08-4987-8edd-06055aaca427','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(13,'foo_4','0ee95716c58cf7aab3ef7301ff907118552c2dda','8258196f-3db0-49b5-b954-53c93051626b','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(14,'foo_5','0ee95716c58cf7aab3ef7301ff907118552c2dda','231bf5a0-5d41-4da5-8289-8b4dcdd98937','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(15,'foo_6','0ee95716c58cf7aab3ef7301ff907118552c2dda','c0363e33-ce23-4639-b3a0-a2bc5fcc01b7','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(16,'foo_7','0ee95716c58cf7aab3ef7301ff907118552c2dda','5a49b8ad-6ae8-43e1-8f88-1688cf2a34d2','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(17,'foo_8','0ee95716c58cf7aab3ef7301ff907118552c2dda','dfe5e14c-a379-4c4f-b16b-cd99dff02701','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(18,'foo_9','0ee95716c58cf7aab3ef7301ff907118552c2dda','b65bd93f-c8af-4a2c-8638-9c2a580b6ccc','02f1868cf22fb392c343ab9b747c9b6b34ab10e2','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda');
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
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages_release_versions`
--

LOCK TABLES `packages_release_versions` WRITE;
/*!40000 ALTER TABLE `packages_release_versions` DISABLE KEYS */;
INSERT INTO `packages_release_versions` VALUES (1,1,1),(2,2,1),(3,3,1),(4,4,1),(5,5,1),(6,6,1),(7,7,1),(8,8,1),(9,9,1),(10,10,1),(11,11,1),(12,12,1),(13,13,1),(14,14,1),(15,15,1),(16,16,1),(17,17,1),(18,18,1);
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
  `cpi` varchar(255) DEFAULT '',
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
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1523382189,1),(2,'bosh','NS','ns.bosh',14400,NULL,1523382189,1),(3,'ns.bosh','A',NULL,18000,NULL,1523382189,1),(4,'0.foobar.a.simple.bosh','A','192.168.1.2',300,NULL,1523382196,1),(5,'1.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'1.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.1.168.192.in-addr.arpa','PTR','0.foobar.a.simple.bosh',300,NULL,1523382196,2),(8,'96be0e58-afa4-4015-882c-a1fbb615e4f9.foobar.a.simple.bosh','A','192.168.1.2',300,NULL,1523382196,1),(9,'2.1.168.192.in-addr.arpa','PTR','96be0e58-afa4-4015-882c-a1fbb615e4f9.foobar.a.simple.bosh',300,NULL,1523382196,2),(10,'1.foobar.a.simple.bosh','A','192.168.2.2',300,NULL,1523382202,1),(11,'2.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,3),(12,'2.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,3),(13,'2.2.168.192.in-addr.arpa','PTR','1.foobar.a.simple.bosh',300,NULL,1523382202,3),(14,'4f7103f4-e6a7-4fa9-a277-7fec76af1d98.foobar.a.simple.bosh','A','192.168.2.2',300,NULL,1523382202,1),(15,'2.2.168.192.in-addr.arpa','PTR','4f7103f4-e6a7-4fa9-a277-7fec76af1d98.foobar.a.simple.bosh',300,NULL,1523382202,3),(16,'2.foobar.a.simple.bosh','A','192.168.3.2',300,NULL,1523382205,1),(17,'3.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,4),(18,'3.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,4),(19,'2.3.168.192.in-addr.arpa','PTR','2.foobar.a.simple.bosh',300,NULL,1523382205,4),(20,'b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051.foobar.a.simple.bosh','A','192.168.3.2',300,NULL,1523382205,1),(21,'2.3.168.192.in-addr.arpa','PTR','b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051.foobar.a.simple.bosh',300,NULL,1523382205,4);
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
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'e74ab07',0);
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
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions_templates`
--

LOCK TABLES `release_versions_templates` WRITE;
/*!40000 ALTER TABLE `release_versions_templates` DISABLE KEYS */;
INSERT INTO `release_versions_templates` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5),(6,1,6),(7,1,7),(8,1,8),(9,1,9),(10,1,10),(11,1,11),(12,1,12),(13,1,13),(14,1,14),(15,1,15),(16,1,16),(17,1,17),(18,1,18),(19,1,19),(20,1,20),(21,1,21),(22,1,22),(23,1,23),(24,1,24),(25,1,25),(26,1,26);
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
INSERT INTO `rendered_templates_archives` VALUES (1,1,'52dca8b5-950f-4261-ba3c-8ba2e57a6231','e62d8691228726490720459d2917a7f697430a09','16729075ff69d072dfde2d4c9272eaf5bb2082af','2018-04-10 17:43:15'),(2,2,'b91887e3-1e3b-4c9f-b24d-11944083e0e3','5b88258110b41ea988350c8d94ab1ab3836f7dc1','56f75dca9c0460c56d5e20dc99f78533285efbc9','2018-04-10 17:43:21'),(3,3,'afa23157-4544-41de-acca-254e82e865cb','9365968a8fceed2a41762bb04c401e26f856d295','8fd71c8894a22d140ee9875d53730b8a2e60a1c2','2018-04-10 17:43:24');
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
  `name` varchar(255) NOT NULL DEFAULT '',
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
INSERT INTO `schema_migrations` VALUES ('20110209010747_initial.rb'),('20110406055800_add_task_user.rb'),('20110518225809_remove_cid_constrain.rb'),('20110617211923_add_deployments_release_versions.rb'),('20110622212607_add_task_checkpoint_timestamp.rb'),('20110628023039_add_state_to_instances.rb'),('20110709012332_add_disk_size_to_instances.rb'),('20110906183441_add_log_bundles.rb'),('20110907194830_add_logs_json_to_templates.rb'),('20110915205610_add_persistent_disks.rb'),('20111005180929_add_properties.rb'),('20111110024617_add_deployment_problems.rb'),('20111216214145_recreate_support_for_vms.rb'),('20120102084027_add_credentials_to_vms.rb'),('20120427235217_allow_multiple_releases_per_deployment.rb'),('20120524175805_add_task_type.rb'),('20120614001930_delete_redundant_deployment_release_relation.rb'),('20120822004528_add_fingerprint_to_templates_and_packages.rb'),('20120830191244_add_properties_to_templates.rb'),('20121106190739_persist_vm_env.rb'),('20130222232131_add_sha1_to_stemcells.rb'),('20130312211407_add_commit_hash_to_release_versions.rb'),('20130409235338_snapshot.rb'),('20130530164918_add_paused_flag_to_instance.rb'),('20130531172604_add_director_attributes.rb'),('20131121182231_add_rendered_templates_archives.rb'),('20131125232201_rename_rendered_templates_archives_blob_id_and_checksum_columns.rb'),('20140116002324_pivot_director_attributes.rb'),('20140124225348_proper_pk_for_attributes.rb'),('20140731215410_increase_text_limit_for_data_columns.rb'),('20141204234517_add_cloud_properties_to_persistent_disk.rb'),('20150102234124_denormalize_task_user_id_to_task_username.rb'),('20150223222605_increase_manifest_text_limit.rb'),('20150224193313_use_larger_text_types.rb'),('20150331002413_add_cloud_configs.rb'),('20150401184803_add_cloud_config_to_deployments.rb'),('20150513225143_ip_addresses.rb'),('20150611193110_add_trusted_certs_sha1_to_vms.rb'),('20150619135210_add_os_name_and_version_to_stemcells.rb'),('20150702004608_add_links.rb'),('20150708231924_add_link_spec.rb'),('20150716170926_allow_null_on_blobstore_id_and_sha1_on_package.rb'),('20150724183256_add_debugging_to_ip_addresses.rb'),('20150730225029_add_uuid_to_instances.rb'),('20150803215805_add_availabililty_zone_and_cloud_properties_to_instances.rb'),('20150804211419_add_compilation_flag_to_instance.rb'),('20150918003455_add_bootstrap_node_to_instance.rb'),('20151008232214_add_dns_records.rb'),('20151015172551_add_orphan_disks_and_snapshots.rb'),('20151030222853_add_templates_to_instance.rb'),('20151031001039_add_spec_to_instance.rb'),('20151109190602_rename_orphan_columns.rb'),('20151223172000_rename_requires_json.rb'),('20151229184742_add_vm_attributes_to_instance.rb'),('20160106162749_runtime_configs.rb'),('20160106163433_add_runtime_configs_to_deployments.rb'),('20160108191637_drop_vm_env_json_from_instance.rb'),('20160121003800_drop_vms_fkeys.rb'),('20160202162216_add_post_start_completed_to_instance.rb'),('20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb'),('20160211174110_add_events.rb'),('20160211193904_add_scopes_to_deployment.rb'),('20160219175840_add_column_teams_to_deployments.rb'),('20160224222508_add_deployment_name_to_task.rb'),('20160225182206_rename_post_start_completed.rb'),('20160324181932_create_delayed_jobs.rb'),('20160324182211_add_locks.rb'),('20160329201256_set_instances_with_nil_serial_to_false.rb'),('20160331225404_backfill_stemcell_os.rb'),('20160411104407_add_task_started_at.rb'),('20160414183654_set_teams_on_task.rb'),('20160427164345_add_teams.rb'),('20160511191928_ephemeral_blobs.rb'),('20160513102035_add_tracking_to_instance.rb'),('20160531164756_add_local_dns_blobs.rb'),('20160614182106_change_text_to_longtext_for_mysql.rb'),('20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb'),('20160706131605_change_events_id_type.rb'),('20160708234509_add_local_dns_records.rb'),('20160712171230_add_version_to_local_dns_blobs.rb'),('20160725090007_add_cpi_configs.rb'),('20160803151600_add_name_to_persistent_disks.rb'),('20160817135953_add_cpi_to_stemcells.rb'),('20160818112257_change_stemcell_unique_key.rb'),('20161031204534_populate_lifecycle_on_instance_spec.rb'),('20161128181900_add_logs_to_tasks.rb'),('20161209104649_add_context_id_to_tasks.rb'),('20161221151107_allow_null_instance_id_local_dns.rb'),('20170104003158_add_agent_dns_version.rb'),('20170116235940_add_errand_runs.rb'),('20170119202003_update_sha1_column_sizes.rb'),('20170203212124_add_variables.rb'),('20170216194502_remove_blobstore_id_idx_from_local_dns_blobs.rb'),('20170217000000_variables_instance_table_foreign_key_update.rb'),('20170301192646_add_deployed_successfully_to_variable_sets.rb'),('20170303175054_expand_template_json_column_lengths.rb'),('20170306215659_expand_vms_json_column_lengths.rb'),('20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records.rb'),('20170321151400_add_writable_to_variable_set.rb'),('20170328224049_associate_vm_info_with_vms_table.rb'),('20170331171657_remove_active_vm_id_from_instances.rb'),('20170405144414_add_cross_deployment_links_support_for_variables.rb'),('20170405181126_backfill_local_dns_records_and_drop_name.rb'),('20170412205032_add_agent_id_and_domain_name_to_local_dns_records.rb'),('20170427194511_add_runtime_config_name_support.rb'),('20170503205545_change_id_local_dns_to_bigint.rb'),('20170510154449_add_multi_runtime_config_support.rb'),('20170510190908_alter_ephemeral_blobs.rb'),('20170606225018_add_cpi_to_cloud_records.rb'),('20170607182149_add_task_id_to_locks.rb'),('20170612013910_add_created_at_to_vms.rb'),('20170616173221_remove_users_table.rb'),('20170616185237_migrate_spec_json_links.rb'),('20170628221611_add_canonical_az_names_and_ids.rb'),('20170705204352_add_cpi_to_disks.rb'),('20170705211620_add_templates_json_to_templates.rb'),('20170803163303_register_known_az_names.rb'),('20170804191205_add_deployment_and_errand_name_to_errand_runs.rb'),('20170815175515_change_variable_ids_to_bigint.rb'),('20170821141953_remove_unused_credentials_json_columns.rb'),('20170825141953_change_address_to_be_string_for_ipv6.rb'),('20170828174622_add_spec_json_to_templates.rb'),('20170915205722_create_dns_encoded_networks_and_instance_groups.rb'),('20171010144941_add_configs.rb'),('20171010150659_migrate_runtime_configs.rb'),('20171010161532_migrate_cloud_configs.rb'),('20171011122118_migrate_cpi_configs.rb'),('20171018102040_remove_compilation_local_dns_records.rb'),('20171030224934_convert_nil_configs_to_empty.rb'),('20180119183014_add_stemcell_matches.rb'),('20180130182844_rename_stemcell_matches_to_stemcell_uploads.rb'),('20180130182845_add_team_id_to_configs.rb');
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
-- Table structure for table `stemcell_uploads`
--

DROP TABLE IF EXISTS `stemcell_uploads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stemcell_uploads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `cpi` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`version`,`cpi`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stemcell_uploads`
--

LOCK TABLES `stemcell_uploads` WRITE;
/*!40000 ALTER TABLE `stemcell_uploads` DISABLE KEYS */;
INSERT INTO `stemcell_uploads` VALUES (1,'ubuntu-stemcell','1','');
/*!40000 ALTER TABLE `stemcell_uploads` ENABLE KEYS */;
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
  `sha1` varchar(512) DEFAULT NULL,
  `operating_system` varchar(255) DEFAULT NULL,
  `cpi` varchar(255) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `stemcells_name_version_cpi_key` (`name`,`version`,`cpi`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stemcells`
--

LOCK TABLES `stemcells` WRITE;
/*!40000 ALTER TABLE `stemcells` DISABLE KEYS */;
INSERT INTO `stemcells` VALUES (1,'ubuntu-stemcell','1','1cb6a2dc-45dd-412e-ac5b-d596e86643f7','shawone','toronto-os','');
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
  `event_output` longtext,
  `result_output` longtext,
  `context_id` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `tasks_state_index` (`state`),
  KEY `tasks_timestamp_index` (`timestamp`),
  KEY `tasks_description_index` (`description`),
  KEY `tasks_context_id_index` (`context_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2018-04-10 17:43:06','create release','Created release \'bosh-release/0+dev.1\'','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-49040/sandbox/boshdir/tasks/1','2018-04-10 17:43:04','update_release','test',NULL,'2018-04-10 17:43:04','{\"time\":1523382184,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"a/821fcd0a441062473a386e9297e9cb48b5f189f4\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"a/821fcd0a441062473a386e9297e9cb48b5f189f4\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"b/ec25004a81fc656a6c39871564f352d70268c637\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"b/ec25004a81fc656a6c39871564f352d70268c637\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"blocking_package/2ae8315faf952e6f69da493286387803ccfad248\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"blocking_package/2ae8315faf952e6f69da493286387803ccfad248\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"c/5bc40b65cca962dcc486673c6999d3b085b4a9ab\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"c/5bc40b65cca962dcc486673c6999d3b085b4a9ab\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"errand1/7976e3d21a6d6d00885c44b0192f6daa8afc0587\",\"index\":6,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"errand1/7976e3d21a6d6d00885c44b0192f6daa8afc0587\",\"index\":6,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"fails_with_too_much_output/e505f41e8cec5608209392c06950bba5d995bdd8\",\"index\":7,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"fails_with_too_much_output/e505f41e8cec5608209392c06950bba5d995bdd8\",\"index\":7,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":8,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":8,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382184,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_1/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":9,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_1/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":9,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_10/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":10,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_10/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":10,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_2/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":11,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_2/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":11,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_3/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":12,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_3/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":12,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_4/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":13,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_4/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":13,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_5/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":14,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_5/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":14,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_6/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":15,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_6/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":15,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_7/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":16,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_7/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":16,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_8/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":17,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_8/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":17,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_9/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":18,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":18,\"task\":\"foo_9/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":18,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"emoji-errand/d4a4da3c16bd12760b3fcf7c39ef5e503a639c76\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"emoji-errand/d4a4da3c16bd12760b3fcf7c39ef5e503a639c76\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"errand1/e562d0fbe75fedffd321e750eccd1511ad4ff45a\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"errand1/e562d0fbe75fedffd321e750eccd1511ad4ff45a\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"errand_without_package/1bfc81a13748dea90e82166d979efa414ea6f976\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"errand_without_package/1bfc81a13748dea90e82166d979efa414ea6f976\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"fails_with_too_much_output/a005cfa7aef65373afdd46df22c2451362b050e9\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"fails_with_too_much_output/a005cfa7aef65373afdd46df22c2451362b050e9\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar/47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar/47eeeaec61f68baf6fc94108ac32aece496fa50e\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_with_bad_properties/3542741effbd673a38dc6ecba33795298487640e\",\"index\":6,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_with_bad_properties/3542741effbd673a38dc6ecba33795298487640e\",\"index\":6,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_with_bad_properties_2/e275bd0a977ea784dd636545e3184961b3cfab33\",\"index\":7,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_with_bad_properties_2/e275bd0a977ea784dd636545e3184961b3cfab33\",\"index\":7,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_without_packages/2d800134e61f835c6dd1fb15d813122c81ebb69e\",\"index\":8,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"foobar_without_packages/2d800134e61f835c6dd1fb15d813122c81ebb69e\",\"index\":8,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"has_drain_script/e3d67befd3013db7c91628f9a146cc5de264cba9\",\"index\":9,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"has_drain_script/e3d67befd3013db7c91628f9a146cc5de264cba9\",\"index\":9,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"id_job/263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81\",\"index\":10,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"id_job/263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81\",\"index\":10,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_many_properties/2950ecf5d736be6a9f0290350dcf37901d8ea4f1\",\"index\":11,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_many_properties/2950ecf5d736be6a9f0290350dcf37901d8ea4f1\",\"index\":11,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_post_deploy_script/61db957436288c4c5ad3708860709f593a370869\",\"index\":12,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_post_deploy_script/61db957436288c4c5ad3708860709f593a370869\",\"index\":12,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_pre_start_script/119130db1e3716a643ea3e5770ee615907c4f260\",\"index\":13,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_1_with_pre_start_script/119130db1e3716a643ea3e5770ee615907c4f260\",\"index\":13,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_many_properties/e544d24d313484b715c45a7c19cc8a3a1757ba78\",\"index\":14,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_many_properties/e544d24d313484b715c45a7c19cc8a3a1757ba78\",\"index\":14,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_post_deploy_script/74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b\",\"index\":15,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_post_deploy_script/74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b\",\"index\":15,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_pre_start_script/cca21652453a1c034f93956d12f2e8e46be4435b\",\"index\":16,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_2_with_pre_start_script/cca21652453a1c034f93956d12f2e8e46be4435b\",\"index\":16,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382185,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_3_with_broken_post_deploy_script/663fca30979cafb71d7a24bf0b775ffc348363c1\",\"index\":17,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_3_with_broken_post_deploy_script/663fca30979cafb71d7a24bf0b775ffc348363c1\",\"index\":17,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_3_with_many_properties/7a09666d3555ca6be468918ff632a39d91f32684\",\"index\":18,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_3_with_many_properties/7a09666d3555ca6be468918ff632a39d91f32684\",\"index\":18,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_that_modifies_properties/e03cb3183f23fb5f004fde0bd04b518e69bdaafb\",\"index\":19,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_that_modifies_properties/e03cb3183f23fb5f004fde0bd04b518e69bdaafb\",\"index\":19,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_bad_template/c81c0f33892981a8f4bec30dcd90cfda68ab52c6\",\"index\":20,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_bad_template/c81c0f33892981a8f4bec30dcd90cfda68ab52c6\",\"index\":20,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_blocking_compilation/a76a148bd499d6e50b65b634edcdd9539c743b12\",\"index\":21,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_blocking_compilation/a76a148bd499d6e50b65b634edcdd9539c743b12\",\"index\":21,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_many_packages/8dc747d5dc774e822bbe2413e0ae1c5e8a825c74\",\"index\":22,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_many_packages/8dc747d5dc774e822bbe2413e0ae1c5e8a825c74\",\"index\":22,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_post_start_script/cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78\",\"index\":23,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_post_start_script/cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78\",\"index\":23,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_property_types/71bfdbb4bce71b1c1344d1b0b193d9246f6a6387\",\"index\":24,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"job_with_property_types/71bfdbb4bce71b1c1344d1b0b193d9246f6a6387\",\"index\":24,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"local_dns_records_json/cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd\",\"index\":25,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"local_dns_records_json/cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd\",\"index\":25,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"transitive_deps/c0bdff18a9d1859d32276daf36d0716654aea96f\",\"index\":26,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":26,\"task\":\"transitive_deps/c0bdff18a9d1859d32276daf36d0716654aea96f\",\"index\":26,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382186,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382186,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(2,'done','2018-04-10 17:43:08','create stemcell','/stemcells/ubuntu-stemcell/1','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-49040/sandbox/boshdir/tasks/2','2018-04-10 17:43:07','update_stemcell','test',NULL,'2018-04-10 17:43:07','{\"time\":1523382187,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382187,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (1cb6a2dc-45dd-412e-ac5b-d596e86643f7)\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382188,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (1cb6a2dc-45dd-412e-ac5b-d596e86643f7)\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n','',''),(3,'done','2018-04-10 17:43:26','create deployment','/deployments/simple','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-49040/sandbox/boshdir/tasks/3','2018-04-10 17:43:09','update_deployment','test','simple','2018-04-10 17:43:09','{\"time\":1523382189,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382189,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382189,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382189,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382189,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382191,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382191,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382193,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382193,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382193,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98 (1)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382193,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051 (2)\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382194,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051 (2)\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382194,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382195,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":3,\"task\":\"foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98 (1)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382195,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382201,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/96be0e58-afa4-4015-882c-a1fbb615e4f9 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382201,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98 (1)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382203,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/4f7103f4-e6a7-4fa9-a277-7fec76af1d98 (1)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1523382203,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051 (2)\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1523382206,\"stage\":\"Updating instance\",\"tags\":[\"foobar\"],\"total\":3,\"task\":\"foobar/b2ee5e3b-dd0d-4a53-84b2-82f3b83b5051 (2)\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n','','');
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
  `sha1` varchar(512) NOT NULL,
  `package_names_json` longtext NOT NULL,
  `release_id` int(11) NOT NULL,
  `logs_json` longtext,
  `fingerprint` varchar(255) DEFAULT NULL,
  `properties_json` longtext,
  `consumes_json` longtext,
  `provides_json` longtext,
  `templates_json` longtext,
  `spec_json` longtext,
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_id` (`release_id`,`name`,`version`),
  KEY `templates_fingerprint_index` (`fingerprint`),
  KEY `templates_sha1_index` (`sha1`),
  CONSTRAINT `templates_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `templates`
--

LOCK TABLES `templates` WRITE;
/*!40000 ALTER TABLE `templates` DISABLE KEYS */;
INSERT INTO `templates` VALUES (1,'emoji-errand','d4a4da3c16bd12760b3fcf7c39ef5e503a639c76','430dad2b-0898-486c-b220-f1380f8e6807','84baa53dd0e3bad6e3811116cd3643e33521c098','[]',1,NULL,'d4a4da3c16bd12760b3fcf7c39ef5e503a639c76',NULL,NULL,NULL,NULL,'{\"name\":\"emoji-errand\",\"templates\":{\"run\":\"bin/run\"},\"packages\":[],\"properties\":{}}'),(2,'errand1','e562d0fbe75fedffd321e750eccd1511ad4ff45a','75bba686-ff1f-40e9-8934-7b60e02a72b8','56bf3ca78775ecc4e7233f6418cc224ff7b9f411','[\"errand1\"]',1,NULL,'e562d0fbe75fedffd321e750eccd1511ad4ff45a',NULL,NULL,NULL,NULL,'{\"name\":\"errand1\",\"templates\":{\"ctl\":\"bin/ctl\",\"run\":\"bin/run\"},\"packages\":[\"errand1\"],\"properties\":{\"errand1.stdout\":{\"description\":\"Stdout to print from the errand script\",\"default\":\"errand1-stdout\"},\"errand1.stdout_multiplier\":{\"description\":\"Number of times stdout will be repeated in the output\",\"default\":1},\"errand1.stderr\":{\"description\":\"Stderr to print from the errand script\",\"default\":\"errand1-stderr\"},\"errand1.stderr_multiplier\":{\"description\":\"Number of times stderr will be repeated in the output\",\"default\":1},\"errand1.run_package_file\":{\"description\":\"Should bin/run run script from errand1 package to show that package is present on the vm\",\"default\":false},\"errand1.exit_code\":{\"description\":\"Exit code to return from the errand script\",\"default\":0},\"errand1.blocking_errand\":{\"description\":\"Whether to block errand execution\",\"default\":false},\"errand1.logs.stdout\":{\"description\":\"Output to place into sys/log/errand1/stdout.log\",\"default\":\"errand1-stdout-log\"},\"errand1.logs.custom\":{\"description\":\"Output to place into sys/log/custom.log\",\"default\":\"errand1-custom-log\"},\"errand1.gargamel_color\":{\"description\":\"Gargamels color\"}}}'),(3,'errand_without_package','1bfc81a13748dea90e82166d979efa414ea6f976','5dfeaa27-caec-4996-931c-697afbce413e','73602da9daa701197fd7832b0773edaa45549660','[]',1,NULL,'1bfc81a13748dea90e82166d979efa414ea6f976',NULL,NULL,NULL,NULL,'{\"name\":\"errand_without_package\",\"templates\":{\"run\":\"bin/run\"},\"packages\":[],\"properties\":{}}'),(4,'fails_with_too_much_output','a005cfa7aef65373afdd46df22c2451362b050e9','fce68c16-c365-48fe-b906-480a92af111b','df52de23d14b6c989dbf012d154649faaef5e280','[\"fails_with_too_much_output\"]',1,NULL,'a005cfa7aef65373afdd46df22c2451362b050e9',NULL,NULL,NULL,NULL,'{\"name\":\"fails_with_too_much_output\",\"templates\":{},\"packages\":[\"fails_with_too_much_output\"],\"properties\":{}}'),(5,'foobar','47eeeaec61f68baf6fc94108ac32aece496fa50e','8cb34e85-8fb3-423f-9d5f-027bdb6205fb','6bd7fcfc936d567d33dadab3ccda36a7b445903b','[\"foo\",\"bar\"]',1,NULL,'47eeeaec61f68baf6fc94108ac32aece496fa50e',NULL,NULL,NULL,NULL,'{\"name\":\"foobar\",\"templates\":{\"foobar_ctl\":\"bin/foobar_ctl\",\"drain.erb\":\"bin/drain\"},\"packages\":[\"foo\",\"bar\"],\"properties\":{\"test_property\":{\"description\":\"A test property\",\"default\":1},\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"dynamic_drain_wait1\":{\"description\":\"Number of seconds to wait when drain script is first called\",\"default\":-3},\"dynamic_drain_wait2\":{\"description\":\"Number of seconds to wait when drain script is called a second time\",\"default\":-2},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}}'),(6,'foobar_with_bad_properties','3542741effbd673a38dc6ecba33795298487640e','986aa678-4680-4c62-bece-6b177bf38c90','5c070172bb28d28ceda133b3c0d7e15c0f12988f','[\"foo\",\"bar\"]',1,NULL,'3542741effbd673a38dc6ecba33795298487640e',NULL,NULL,NULL,NULL,'{\"name\":\"foobar_with_bad_properties\",\"templates\":{\"foobar_ctl\":\"bin/foobar_ctl\",\"drain.erb\":\"bin/drain\"},\"packages\":[\"foo\",\"bar\"],\"properties\":{\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}}'),(7,'foobar_with_bad_properties_2','e275bd0a977ea784dd636545e3184961b3cfab33','3da64dc9-b42b-49a5-b136-7e8a52d7f7ea','2fd0ff0953ad69910b6bcbe88c359537605effa9','[\"foo\",\"bar\"]',1,NULL,'e275bd0a977ea784dd636545e3184961b3cfab33',NULL,NULL,NULL,NULL,'{\"name\":\"foobar_with_bad_properties_2\",\"templates\":{\"foobar_ctl\":\"bin/foobar_ctl\",\"drain.erb\":\"bin/drain\"},\"packages\":[\"foo\",\"bar\"],\"properties\":{\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}}'),(8,'foobar_without_packages','2d800134e61f835c6dd1fb15d813122c81ebb69e','758dae1b-51f3-4c68-b508-50680a3433f7','bc03a6f116d18dab63191594e04b6ea2dd697c7b','[]',1,NULL,'2d800134e61f835c6dd1fb15d813122c81ebb69e',NULL,NULL,NULL,NULL,'{\"name\":\"foobar_without_packages\",\"templates\":{\"foobar_ctl\":\"bin/foobar_ctl\"},\"packages\":[],\"properties\":{}}'),(9,'has_drain_script','e3d67befd3013db7c91628f9a146cc5de264cba9','7333d95e-414e-4350-9b7d-ed12960e8239','42a067251acf555df5b6888da1e4544bb8ddd2bc','[\"foo\",\"bar\"]',1,NULL,'e3d67befd3013db7c91628f9a146cc5de264cba9',NULL,NULL,NULL,NULL,'{\"name\":\"has_drain_script\",\"templates\":{\"has_drain_script_ctl\":\"bin/has_drain_script_ctl\",\"drain.erb\":\"bin/drain\"},\"packages\":[\"foo\",\"bar\"],\"properties\":{\"test_property\":{\"description\":\"A test property\",\"default\":1},\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"dynamic_drain_wait1\":{\"description\":\"Number of seconds to wait when drain script is first called\",\"default\":-3},\"dynamic_drain_wait2\":{\"description\":\"Number of seconds to wait when drain script is called a second time\",\"default\":-2},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"}}}'),(10,'id_job','263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81','df0c781b-ab80-48e8-8ad1-f792bdda9be4','d9efdca3c5dca51aab81cf895f7c022138ff0108','[]',1,NULL,'263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81',NULL,NULL,NULL,NULL,'{\"name\":\"id_job\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"properties\":{}}'),(11,'job_1_with_many_properties','2950ecf5d736be6a9f0290350dcf37901d8ea4f1','58f31f56-cc16-4b51-b647-1fd107be9434','5eee8528c3e6cd4f58e0f558102198248b755872','[]',1,NULL,'2950ecf5d736be6a9f0290350dcf37901d8ea4f1',NULL,NULL,NULL,NULL,'{\"name\":\"job_1_with_many_properties\",\"templates\":{\"properties_displayer.yml.erb\":\"properties_displayer.yml\"},\"packages\":[],\"properties\":{\"smurfs.color\":{\"description\":\"The color of the smurfs\",\"default\":\"blue\"},\"gargamel.color\":{\"description\":\"The color of gargamel it is required\"},\"gargamel.age\":{\"description\":\"The age of gargamel it is required\"},\"gargamel.dob\":{\"description\":\"The DOB of gargamel it is required\"}}}'),(12,'job_1_with_post_deploy_script','61db957436288c4c5ad3708860709f593a370869','238477f5-3045-4051-b6b4-497500afc29a','d274feffa17c12deb6027f9a7fe3a535ed67dee3','[]',1,NULL,'61db957436288c4c5ad3708860709f593a370869',NULL,NULL,NULL,NULL,'{\"name\":\"job_1_with_post_deploy_script\",\"templates\":{\"post-deploy.erb\":\"bin/post-deploy\",\"job_1_ctl\":\"bin/job_1_ctl\"},\"packages\":[],\"properties\":{\"post_deploy_message_1\":{\"description\":\"A message echoed by the post-deploy script 1\",\"default\":\"this is post_deploy_message_1\"}}}'),(13,'job_1_with_pre_start_script','119130db1e3716a643ea3e5770ee615907c4f260','2c3d882e-fef4-4b08-ba0c-b2e5fc4a491b','b0fc7309c3c603a0084254da7fe5755b270a28e9','[]',1,NULL,'119130db1e3716a643ea3e5770ee615907c4f260',NULL,NULL,NULL,NULL,'{\"name\":\"job_1_with_pre_start_script\",\"templates\":{\"pre-start.erb\":\"bin/pre-start\",\"job_1_ctl\":\"bin/job_1_ctl\"},\"packages\":[],\"properties\":{\"pre_start_message_1\":{\"description\":\"A message echoed by the pre-start script 1\",\"default\":\"this is pre_start_message_1\"}}}'),(14,'job_2_with_many_properties','e544d24d313484b715c45a7c19cc8a3a1757ba78','58489995-569e-4feb-b19d-c0806b50c285','824fd4ef0f6f2388a38dddca67813aacc5e5f620','[]',1,NULL,'e544d24d313484b715c45a7c19cc8a3a1757ba78',NULL,NULL,NULL,NULL,'{\"name\":\"job_2_with_many_properties\",\"templates\":{\"properties_displayer.yml.erb\":\"properties_displayer.yml\"},\"packages\":[],\"properties\":{\"smurfs.color\":{\"description\":\"The color of the smurfs\",\"default\":\"blue\"},\"gargamel.color\":{\"description\":\"The color of gargamel it is required\"}}}'),(15,'job_2_with_post_deploy_script','74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b','6606535a-84c6-43dd-aa87-ea4871241243','eb9bc84e58ed618ac07ec1b10507a587a635fa8e','[]',1,NULL,'74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b',NULL,NULL,NULL,NULL,'{\"name\":\"job_2_with_post_deploy_script\",\"templates\":{\"post-deploy.erb\":\"bin/post-deploy\",\"job_2_ctl\":\"bin/job_2_ctl\"},\"packages\":[],\"properties\":{}}'),(16,'job_2_with_pre_start_script','cca21652453a1c034f93956d12f2e8e46be4435b','4c1da8ff-7f74-4c8f-a556-856e1910a48d','d3c027f935bc875d1ed9b9e24a82a12e6cfa5e50','[]',1,NULL,'cca21652453a1c034f93956d12f2e8e46be4435b',NULL,NULL,NULL,NULL,'{\"name\":\"job_2_with_pre_start_script\",\"templates\":{\"pre-start.erb\":\"bin/pre-start\",\"job_2_ctl\":\"bin/job_2_ctl\"},\"packages\":[],\"properties\":{}}'),(17,'job_3_with_broken_post_deploy_script','663fca30979cafb71d7a24bf0b775ffc348363c1','be4502ac-6919-43d1-abcc-89d9c6860e8b','3900c49623da7eb06fba09047bec276abcc1f174','[]',1,NULL,'663fca30979cafb71d7a24bf0b775ffc348363c1',NULL,NULL,NULL,NULL,'{\"name\":\"job_3_with_broken_post_deploy_script\",\"templates\":{\"broken-post-deploy.erb\":\"bin/post-deploy\",\"job_3_ctl\":\"bin/job_3_ctl\"},\"packages\":[],\"properties\":{}}'),(18,'job_3_with_many_properties','7a09666d3555ca6be468918ff632a39d91f32684','c780ba71-dad7-4873-a4f1-19567ff9fad4','5b7884492018222022f820f5abaad29c7b476247','[]',1,NULL,'7a09666d3555ca6be468918ff632a39d91f32684',NULL,NULL,NULL,NULL,'{\"name\":\"job_3_with_many_properties\",\"templates\":{\"properties_displayer.yml.erb\":\"properties_displayer.yml\"},\"packages\":[],\"properties\":{\"smurfs.color\":{\"description\":\"The color of the smurfs\",\"default\":\"blue\"},\"gargamel.color\":{\"description\":\"The color of gargamel it is required\"}}}'),(19,'job_that_modifies_properties','e03cb3183f23fb5f004fde0bd04b518e69bdaafb','a0c31f8f-af41-4f51-b66d-0d010c01c65e','7c9abe2d829f8e337fa943df4b3a6c4c9e201b76','[\"foo\",\"bar\"]',1,NULL,'e03cb3183f23fb5f004fde0bd04b518e69bdaafb',NULL,NULL,NULL,NULL,'{\"name\":\"job_that_modifies_properties\",\"templates\":{\"job_that_modifies_properties_ctl\":\"bin/job_that_modifies_properties_ctl\",\"another_script.erb\":\"bin/another_script\"},\"packages\":[\"foo\",\"bar\"],\"properties\":{\"some_namespace.test_property\":{\"description\":\"A test property\",\"default\":1}}}'),(20,'job_with_bad_template','c81c0f33892981a8f4bec30dcd90cfda68ab52c6','30d2c20a-b372-4816-b1b5-aff3ec9e636b','a900b5f47c972a15ba51a9373a97548ce68439f1','[]',1,NULL,'c81c0f33892981a8f4bec30dcd90cfda68ab52c6',NULL,NULL,NULL,NULL,'{\"name\":\"job_with_bad_template\",\"templates\":{\"config.yml.erb\":\"config/config.yml\",\"pre-start.erb\":\"bin/pre-start\"},\"packages\":[],\"properties\":{\"fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false},\"gargamel.color\":{\"description\":\"gargamels color\"}}}'),(21,'job_with_blocking_compilation','a76a148bd499d6e50b65b634edcdd9539c743b12','7aabd519-4e22-4042-a58d-cc64f94a31fd','ae0bb5698d9d43dc1f16638ee8f169eae52fc6fa','[\"blocking_package\"]',1,NULL,'a76a148bd499d6e50b65b634edcdd9539c743b12',NULL,NULL,NULL,NULL,'{\"name\":\"job_with_blocking_compilation\",\"templates\":{},\"packages\":[\"blocking_package\"],\"properties\":{}}'),(22,'job_with_many_packages','8dc747d5dc774e822bbe2413e0ae1c5e8a825c74','7a644b12-cf13-43a6-8048-012be06d195a','90e3322ea0f30376d072587e294e15dee9902e55','[\"foo_1\",\"foo_2\",\"foo_3\",\"foo_4\",\"foo_5\",\"foo_6\",\"foo_7\",\"foo_8\",\"foo_9\",\"foo_10\"]',1,NULL,'8dc747d5dc774e822bbe2413e0ae1c5e8a825c74',NULL,NULL,NULL,NULL,'{\"name\":\"job_with_many_packages\",\"templates\":{},\"packages\":[\"foo_1\",\"foo_2\",\"foo_3\",\"foo_4\",\"foo_5\",\"foo_6\",\"foo_7\",\"foo_8\",\"foo_9\",\"foo_10\"],\"properties\":{}}'),(23,'job_with_post_start_script','cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78','3d7b9912-91e8-4561-b75d-32450a12a1e7','38b4e3d9605f3493d7b338436adc400f3b0eaae9','[]',1,NULL,'cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78',NULL,NULL,NULL,NULL,'{\"name\":\"job_with_post_start_script\",\"templates\":{\"post-start.erb\":\"bin/post-start\",\"job_ctl.erb\":\"bin/job_ctl\"},\"packages\":[],\"properties\":{\"post_start_message\":{\"description\":\"A message echoed by the post-start script\",\"default\":\"this is post_start_message\"},\"job_pidfile\":{\"description\":\"Path to jobs pid file\",\"default\":\"/var/vcap/sys/run/job_with_post_start_script.pid\"},\"exit_code\":{\"default\":0}}}'),(24,'job_with_property_types','71bfdbb4bce71b1c1344d1b0b193d9246f6a6387','650e67aa-a10f-48f0-b689-098e75f79ede','51d0a8f433ac0f102ed2a9fd08eca4a92518e9c9','[]',1,NULL,'71bfdbb4bce71b1c1344d1b0b193d9246f6a6387',NULL,NULL,NULL,NULL,'{\"name\":\"job_with_property_types\",\"templates\":{\"properties_displayer.yml.erb\":\"properties_displayer.yml\",\"hardcoded_cert.pem.erb\":\"hardcoded_cert.pem\"},\"packages\":[],\"properties\":{\"smurfs.phone_password\":{\"description\":\"The phone password of the smurfs village\",\"type\":\"password\"},\"smurfs.happiness_level\":{\"description\":\"The level of the Smurfs overall happiness\",\"type\":\"happy\"},\"gargamel.secret_recipe\":{\"description\":\"The secret recipe of gargamel to take down the smurfs\",\"type\":\"password\"},\"gargamel.password\":{\"description\":\"The password I used for everything\",\"default\":\"abc123\",\"type\":\"password\"},\"gargamel.hard_coded_cert\":{\"description\":\"The hardcoded cert of gargamel\",\"default\":\"good luck hardcoding certs and private keys\",\"type\":\"certificate\"}}}'),(25,'local_dns_records_json','cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd','d1361398-a5bb-4703-915a-715eb02c3d09','cfe37e671ac94d3639aea3380893c1ed4fe0c505','[]',1,NULL,'cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd',NULL,NULL,NULL,NULL,'{\"name\":\"local_dns_records_json\",\"templates\":{\"pre-start.erb\":\"bin/pre-start\"},\"packages\":[],\"properties\":{}}'),(26,'transitive_deps','c0bdff18a9d1859d32276daf36d0716654aea96f','4b48d16a-2acb-438a-a2f9-f51c5a16d9ec','d5f77e9bb86010f350aded4d137c924e81b9e995','[\"a\"]',1,NULL,'c0bdff18a9d1859d32276daf36d0716654aea96f',NULL,NULL,NULL,NULL,'{\"name\":\"transitive_deps\",\"templates\":{},\"packages\":[\"a\"],\"properties\":{}}');
/*!40000 ALTER TABLE `templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `variable_sets`
--

DROP TABLE IF EXISTS `variable_sets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `variable_sets` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `deployment_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `deployed_successfully` tinyint(1) DEFAULT '0',
  `writable` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `deployment_id` (`deployment_id`),
  KEY `variable_sets_created_at_index` (`created_at`),
  CONSTRAINT `variable_sets_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `variable_sets`
--

LOCK TABLES `variable_sets` WRITE;
/*!40000 ALTER TABLE `variable_sets` DISABLE KEYS */;
INSERT INTO `variable_sets` VALUES (1,1,'2018-04-10 17:43:09',1,0);
/*!40000 ALTER TABLE `variable_sets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `variables`
--

DROP TABLE IF EXISTS `variables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `variables` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `variable_id` varchar(255) NOT NULL,
  `variable_name` varchar(255) NOT NULL,
  `variable_set_id` bigint(20) NOT NULL,
  `is_local` tinyint(1) DEFAULT '1',
  `provider_deployment` varchar(255) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `variable_set_name_provider_idx` (`variable_set_id`,`variable_name`,`provider_deployment`),
  CONSTRAINT `variable_table_variable_set_fkey` FOREIGN KEY (`variable_set_id`) REFERENCES `variable_sets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `variables`
--

LOCK TABLES `variables` WRITE;
/*!40000 ALTER TABLE `variables` DISABLE KEYS */;
/*!40000 ALTER TABLE `variables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vms`
--

DROP TABLE IF EXISTS `vms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) NOT NULL,
  `agent_id` varchar(255) DEFAULT NULL,
  `cid` varchar(255) DEFAULT NULL,
  `trusted_certs_sha1` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  `active` tinyint(1) DEFAULT '0',
  `cpi` varchar(255) DEFAULT '',
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `agent_id` (`agent_id`),
  UNIQUE KEY `cid` (`cid`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `vms_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vms`
--

LOCK TABLES `vms` WRITE;
/*!40000 ALTER TABLE `vms` DISABLE KEYS */;
INSERT INTO `vms` VALUES (3,2,'7c3f1e58-a69b-4ccd-84e7-d49c76dd5c40','49426','da39a3ee5e6b4b0d3255bfef95601890afd80709',1,'','2018-04-10 17:43:14'),(4,1,'28340494-a6e2-4bdb-b841-d04ac79d005f','49430','da39a3ee5e6b4b0d3255bfef95601890afd80709',1,'','2018-04-10 17:43:14'),(5,3,'45cb1d41-d631-4dd1-9704-cee9da7a113d','49431','da39a3ee5e6b4b0d3255bfef95601890afd80709',1,'','2018-04-10 17:43:14');
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

-- Dump completed on 2018-04-10 10:43:55
