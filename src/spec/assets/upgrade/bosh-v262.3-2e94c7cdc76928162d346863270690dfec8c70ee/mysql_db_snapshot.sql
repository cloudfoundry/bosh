-- MySQL dump 10.13  Distrib 5.7.18, for osx10.12 (x86_64)
--
-- Host: localhost    Database: 4ccb3e81d6ce49e6a3ce7665f245a3ca
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `agent_dns_versions`
--

LOCK TABLES `agent_dns_versions` WRITE;
/*!40000 ALTER TABLE `agent_dns_versions` DISABLE KEYS */;
INSERT INTO `agent_dns_versions` VALUES (1,'0ae81e48-3349-4630-b801-0f8bf4860af1',1);
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blobs`
--

LOCK TABLES `blobs` WRITE;
/*!40000 ALTER TABLE `blobs` DISABLE KEYS */;
INSERT INTO `blobs` VALUES (1,'af074403-484b-4943-8805-d7d409e3b3aa','36cc314b405cff99f39b3d6cb0ae8734817f672a','2017-07-14 15:49:16',NULL),(2,'6bb86dbe-9419-4763-91af-e95b447ba743','e0f6b5d48017095c53e22a0ccf2427c141103e26','2017-07-14 15:49:24',NULL);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cloud_configs`
--

LOCK TABLES `cloud_configs` WRITE;
/*!40000 ALTER TABLE `cloud_configs` DISABLE KEYS */;
INSERT INTO `cloud_configs` VALUES (1,'azs:\n- name: z1\ncompilation:\n  az: z1\n  network: private\n  reuse_compilation_vms: true\n  vm_type: small\n  workers: 1\ndisk_types:\n- disk_size: 3000\n  name: small\nnetworks:\n- name: private\n  subnets:\n  - az: z1\n    dns:\n    - 10.10.0.2\n    gateway: 10.10.0.1\n    range: 10.10.0.0/24\n    static:\n    - 10.10.0.62\n  type: manual\nvm_types:\n- name: small\n','2017-07-14 15:49:14');
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `compiled_packages`
--

LOCK TABLES `compiled_packages` WRITE;
/*!40000 ALTER TABLE `compiled_packages` DISABLE KEYS */;
/*!40000 ALTER TABLE `compiled_packages` ENABLE KEYS */;
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
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
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `cloud_config_id` (`cloud_config_id`),
  CONSTRAINT `deployments_ibfk_1` FOREIGN KEY (`cloud_config_id`) REFERENCES `cloud_configs` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'simple','---\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: provider\n    properties:\n      a: \'1\'\n      b: \'2\'\n      c: \'3\'\n    provides:\n      provider:\n        as: provider_link\n        shared: true\n  name: ig_provider\n  networks:\n  - name: private\n  persistent_disk_type: small\n  stemcell: default\n  vm_type: small\nname: simple\nreleases:\n- name: bosh-release\n  version: 0+dev.1\nstemcells:\n- alias: default\n  os: toronto-os\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n',1,'{\"ig_provider\":{\"provider\":{\"provider_link\":{\"provider\":{\"deployment_name\":\"simple\",\"networks\":[\"private\"],\"properties\":{\"a\":\"1\",\"b\":\"2\",\"c\":\"3\"},\"instances\":[{\"name\":\"ig_provider\",\"index\":0,\"bootstrap\":true,\"id\":\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa\",\"az\":\"z1\",\"address\":\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh\",\"addresses\":{\"private\":\"10.10.0.2\"}}]}}}}}');
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
-- Table structure for table `deployments_runtime_configs`
--

DROP TABLE IF EXISTS `deployments_runtime_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deployments_runtime_configs` (
  `deployment_id` int(11) NOT NULL,
  `runtime_config_id` int(11) NOT NULL,
  UNIQUE KEY `deployment_id_runtime_config_id_unique` (`deployment_id`,`runtime_config_id`),
  KEY `runtime_config_id` (`runtime_config_id`),
  CONSTRAINT `deployments_runtime_configs_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `deployments_runtime_configs_ibfk_2` FOREIGN KEY (`runtime_config_id`) REFERENCES `runtime_configs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_runtime_configs`
--

LOCK TABLES `deployments_runtime_configs` WRITE;
/*!40000 ALTER TABLE `deployments_runtime_configs` DISABLE KEYS */;
/*!40000 ALTER TABLE `deployments_runtime_configs` ENABLE KEYS */;
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `domains`
--

LOCK TABLES `domains` WRITE;
/*!40000 ALTER TABLE `domains` DISABLE KEYS */;
INSERT INTO `domains` VALUES (1,'bosh',NULL,NULL,'NATIVE',NULL,NULL),(2,'0.10.10.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL);
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
  `successful` tinyint(1) DEFAULT '0',
  `successful_configuration_hash` varchar(512) DEFAULT NULL,
  `successful_packages_spec` longtext,
  `instance_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `errands_instance_id_fkey` (`instance_id`),
  CONSTRAINT `errands_instance_id_fkey` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`) ON DELETE CASCADE
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
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,NULL,'_director','2017-07-14 15:49:10','start','director','deadbeef',NULL,NULL,NULL,NULL,'{\"version\":\"0.0.0\"}'),(2,NULL,'_director','2017-07-14 15:49:10','start','worker','worker_0',NULL,NULL,NULL,NULL,'{}'),(3,NULL,'_director','2017-07-14 15:49:10','start','worker','worker_1',NULL,NULL,NULL,NULL,'{}'),(4,NULL,'_director','2017-07-14 15:49:10','start','worker','worker_2',NULL,NULL,NULL,NULL,'{}'),(5,NULL,'test','2017-07-14 15:49:11','acquire','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(6,NULL,'test','2017-07-14 15:49:12','release','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(7,NULL,'test','2017-07-14 15:49:14','update','cloud-config',NULL,NULL,NULL,NULL,NULL,'{}'),(8,NULL,'test','2017-07-14 15:49:14','create','deployment','simple',NULL,'3','simple',NULL,'{}'),(9,NULL,'test','2017-07-14 15:49:14','acquire','lock','lock:deployment:simple',NULL,'3','simple',NULL,'{}'),(10,NULL,'test','2017-07-14 15:49:14','acquire','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(11,NULL,'test','2017-07-14 15:49:14','release','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(12,NULL,'test','2017-07-14 15:49:15','create','vm',NULL,NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(13,12,'test','2017-07-14 15:49:15','create','vm','74511',NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(14,NULL,'test','2017-07-14 15:49:16','create','instance','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa',NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{\"az\":\"z1\"}'),(15,NULL,'test','2017-07-14 15:49:17','create','disk',NULL,NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(16,15,'test','2017-07-14 15:49:17','create','disk','779dfbd39a3309bf99cf10d96ce62f65',NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(17,14,'test','2017-07-14 15:49:23','create','instance','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa',NULL,'3','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(18,8,'test','2017-07-14 15:49:23','create','deployment','simple',NULL,'3','simple',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(19,NULL,'test','2017-07-14 15:49:23','release','lock','lock:deployment:simple',NULL,'3','simple',NULL,'{}'),(20,NULL,'test','2017-07-14 15:49:24','update','deployment','simple',NULL,'4','simple',NULL,'{}'),(21,NULL,'test','2017-07-14 15:49:24','acquire','lock','lock:deployment:simple',NULL,'4','simple',NULL,'{}'),(22,NULL,'test','2017-07-14 15:49:24','acquire','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(23,NULL,'test','2017-07-14 15:49:24','release','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(24,NULL,'test','2017-07-14 15:49:24','stop','instance','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa',NULL,'4','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(25,NULL,'test','2017-07-14 15:49:24','delete','vm','74511',NULL,'4','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(26,25,'test','2017-07-14 15:49:24','delete','vm','74511',NULL,'4','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(27,24,'test','2017-07-14 15:49:24','stop','instance','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa',NULL,'4','simple','ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','{}'),(28,20,'test','2017-07-14 15:49:24','update','deployment','simple',NULL,'4','simple',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(29,NULL,'test','2017-07-14 15:49:24','release','lock','lock:deployment:simple',NULL,'4','simple',NULL,'{}');
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
  `credentials_json_bak` longtext,
  `trusted_certs_sha1_bak` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  `update_completed` tinyint(1) DEFAULT '0',
  `ignore` tinyint(1) DEFAULT '0',
  `variable_set_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  UNIQUE KEY `vm_cid` (`vm_cid_bak`),
  UNIQUE KEY `agent_id` (`agent_id_bak`),
  KEY `deployment_id` (`deployment_id`),
  KEY `instance_table_variable_set_fkey` (`variable_set_id`),
  CONSTRAINT `instance_table_variable_set_fkey` FOREIGN KEY (`variable_set_id`) REFERENCES `variable_sets` (`id`),
  CONSTRAINT `instances_ibfk_1` FOREIGN KEY (`deployment_id`) REFERENCES `deployments` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'ig_provider',0,1,'detached',0,'e3934a8c-68bf-4f80-be7b-aa704cc4e3aa','z1','{}',0,1,'[\"0.ig-provider.private.simple.bosh\",\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"ig_provider\",\"templates\":[{\"name\":\"provider\",\"version\":\"e1ff4ff9a6304e1222484570a400788c55154b1c\",\"sha1\":\"31de06fc89964ce23dd556b1f54ab2212964e2e1\",\"blobstore_id\":\"09d9f54e-a87f-4f50-ab19-dbf89bbb9ad1\"}],\"template\":\"provider\",\"version\":\"e1ff4ff9a6304e1222484570a400788c55154b1c\",\"sha1\":\"31de06fc89964ce23dd556b1f54ab2212964e2e1\",\"blobstore_id\":\"09d9f54e-a87f-4f50-ab19-dbf89bbb9ad1\"},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"ig_provider\",\"id\":\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa\",\"az\":\"z1\",\"networks\":{\"private\":{\"type\":\"manual\",\"ip\":\"10.10.0.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"10.10.0.2\"],\"gateway\":\"10.10.0.1\"}},\"vm_type\":{\"name\":\"small\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"provider\":{\"a\":\"1\",\"b\":\"2\",\"c\":\"3\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":3000,\"persistent_disk_pool\":{\"name\":\"small\",\"disk_size\":3000,\"cloud_properties\":{}},\"persistent_disk_type\":{\"name\":\"small\",\"disk_size\":3000,\"cloud_properties\":{}},\"template_hashes\":{\"provider\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"ebdbb5f5-5a80-43b3-bde9-82db2a537a67\",\"sha1\":\"4bfa5e278fde90ae43f34e74db9c808781ab540c\"},\"configuration_hash\":\"90c5d1358d128117989fc21f2897a25c99205e50\"}',NULL,NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances_templates`
--

LOCK TABLES `instances_templates` WRITE;
/*!40000 ALTER TABLE `instances_templates` DISABLE KEYS */;
INSERT INTO `instances_templates` VALUES (1,1,20);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'private',168427522,0,1,'2017-07-14 15:49:14','3');
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_blobs`
--

LOCK TABLES `local_dns_blobs` WRITE;
/*!40000 ALTER TABLE `local_dns_blobs` DISABLE KEYS */;
INSERT INTO `local_dns_blobs` VALUES (1,1,1,'2017-07-14 15:49:16'),(2,2,2,'2017-07-14 15:49:24');
/*!40000 ALTER TABLE `local_dns_blobs` ENABLE KEYS */;
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_records`
--

LOCK TABLES `local_dns_records` WRITE;
/*!40000 ALTER TABLE `local_dns_records` DISABLE KEYS */;
INSERT INTO `local_dns_records` VALUES (2,'10.10.0.2','z1','ig_provider','private','simple',1,NULL,'bosh');
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages`
--

LOCK TABLES `packages` WRITE;
/*!40000 ALTER TABLE `packages` DISABLE KEYS */;
INSERT INTO `packages` VALUES (1,'pkg_1','7a4094dc99aa72d2d156d99e022d3baa37fb7c4b','aa4f6e26-39b6-4659-a80f-7bc408b7a4ce','446dceafa3789eb971c1e2391be283d223fb9a33','[]',1,'7a4094dc99aa72d2d156d99e022d3baa37fb7c4b'),(2,'pkg_2','fa48497a19f12e925b32fcb8f5ca2b42144e4444','ec7bad8c-b3f7-4a1e-8255-2ff640d09b4f','fa14cec13fdbba501b2819763e37d13fbbc339b7','[]',1,'fa48497a19f12e925b32fcb8f5ca2b42144e4444'),(3,'pkg_3_depends_on_2','2dfa256bc0b0750ae9952118c428b0dcd1010305','e19e7a3b-e05f-47a8-ba94-38d992a30083','0d28675d262c4174efb07e4b1fc72938af558756','[\"pkg_2\"]',1,'2dfa256bc0b0750ae9952118c428b0dcd1010305');
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `persistent_disks`
--

LOCK TABLES `persistent_disks` WRITE;
/*!40000 ALTER TABLE `persistent_disks` DISABLE KEYS */;
INSERT INTO `persistent_disks` VALUES (1,1,'779dfbd39a3309bf99cf10d96ce62f65',3000,1,'{}','');
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
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1500047364,1),(2,'bosh','NS','ns.bosh',14400,NULL,1500047364,1),(3,'ns.bosh','A',NULL,18000,NULL,1500047364,1),(4,'0.ig-provider.private.simple.bosh','A','10.10.0.2',300,NULL,1500047364,1),(5,'0.10.10.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'0.10.10.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.0.10.10.in-addr.arpa','PTR','0.ig-provider.private.simple.bosh',300,NULL,1500047364,2),(8,'e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh','A','10.10.0.2',300,NULL,1500047364,1),(9,'2.0.10.10.in-addr.arpa','PTR','e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh',300,NULL,1500047364,2);
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
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'2e94c7cdc',1);
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
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions_templates`
--

LOCK TABLES `release_versions_templates` WRITE;
/*!40000 ALTER TABLE `release_versions_templates` DISABLE KEYS */;
INSERT INTO `release_versions_templates` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5),(6,1,6),(7,1,7),(8,1,8),(9,1,9),(10,1,10),(11,1,11),(12,1,12),(13,1,13),(14,1,14),(15,1,15),(16,1,16),(17,1,17),(18,1,18),(19,1,19),(20,1,20),(21,1,21),(22,1,22),(23,1,23);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rendered_templates_archives`
--

LOCK TABLES `rendered_templates_archives` WRITE;
/*!40000 ALTER TABLE `rendered_templates_archives` DISABLE KEYS */;
INSERT INTO `rendered_templates_archives` VALUES (1,1,'ebdbb5f5-5a80-43b3-bde9-82db2a537a67','4bfa5e278fde90ae43f34e74db9c808781ab540c','90c5d1358d128117989fc21f2897a25c99205e50','2017-07-14 15:49:16');
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
INSERT INTO `schema_migrations` VALUES ('20110209010747_initial.rb'),('20110406055800_add_task_user.rb'),('20110518225809_remove_cid_constrain.rb'),('20110617211923_add_deployments_release_versions.rb'),('20110622212607_add_task_checkpoint_timestamp.rb'),('20110628023039_add_state_to_instances.rb'),('20110709012332_add_disk_size_to_instances.rb'),('20110906183441_add_log_bundles.rb'),('20110907194830_add_logs_json_to_templates.rb'),('20110915205610_add_persistent_disks.rb'),('20111005180929_add_properties.rb'),('20111110024617_add_deployment_problems.rb'),('20111216214145_recreate_support_for_vms.rb'),('20120102084027_add_credentials_to_vms.rb'),('20120427235217_allow_multiple_releases_per_deployment.rb'),('20120524175805_add_task_type.rb'),('20120614001930_delete_redundant_deployment_release_relation.rb'),('20120822004528_add_fingerprint_to_templates_and_packages.rb'),('20120830191244_add_properties_to_templates.rb'),('20121106190739_persist_vm_env.rb'),('20130222232131_add_sha1_to_stemcells.rb'),('20130312211407_add_commit_hash_to_release_versions.rb'),('20130409235338_snapshot.rb'),('20130530164918_add_paused_flag_to_instance.rb'),('20130531172604_add_director_attributes.rb'),('20131121182231_add_rendered_templates_archives.rb'),('20131125232201_rename_rendered_templates_archives_blob_id_and_checksum_columns.rb'),('20140116002324_pivot_director_attributes.rb'),('20140124225348_proper_pk_for_attributes.rb'),('20140731215410_increase_text_limit_for_data_columns.rb'),('20141204234517_add_cloud_properties_to_persistent_disk.rb'),('20150102234124_denormalize_task_user_id_to_task_username.rb'),('20150223222605_increase_manifest_text_limit.rb'),('20150224193313_use_larger_text_types.rb'),('20150331002413_add_cloud_configs.rb'),('20150401184803_add_cloud_config_to_deployments.rb'),('20150513225143_ip_addresses.rb'),('20150611193110_add_trusted_certs_sha1_to_vms.rb'),('20150619135210_add_os_name_and_version_to_stemcells.rb'),('20150702004608_add_links.rb'),('20150708231924_add_link_spec.rb'),('20150716170926_allow_null_on_blobstore_id_and_sha1_on_package.rb'),('20150724183256_add_debugging_to_ip_addresses.rb'),('20150730225029_add_uuid_to_instances.rb'),('20150803215805_add_availabililty_zone_and_cloud_properties_to_instances.rb'),('20150804211419_add_compilation_flag_to_instance.rb'),('20150918003455_add_bootstrap_node_to_instance.rb'),('20151008232214_add_dns_records.rb'),('20151015172551_add_orphan_disks_and_snapshots.rb'),('20151030222853_add_templates_to_instance.rb'),('20151031001039_add_spec_to_instance.rb'),('20151109190602_rename_orphan_columns.rb'),('20151223172000_rename_requires_json.rb'),('20151229184742_add_vm_attributes_to_instance.rb'),('20160106162749_runtime_configs.rb'),('20160106163433_add_runtime_configs_to_deployments.rb'),('20160108191637_drop_vm_env_json_from_instance.rb'),('20160121003800_drop_vms_fkeys.rb'),('20160202162216_add_post_start_completed_to_instance.rb'),('20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb'),('20160211174110_add_events.rb'),('20160211193904_add_scopes_to_deployment.rb'),('20160219175840_add_column_teams_to_deployments.rb'),('20160224222508_add_deployment_name_to_task.rb'),('20160225182206_rename_post_start_completed.rb'),('20160324181932_create_delayed_jobs.rb'),('20160324182211_add_locks.rb'),('20160329201256_set_instances_with_nil_serial_to_false.rb'),('20160331225404_backfill_stemcell_os.rb'),('20160411104407_add_task_started_at.rb'),('20160414183654_set_teams_on_task.rb'),('20160427164345_add_teams.rb'),('20160511191928_ephemeral_blobs.rb'),('20160513102035_add_tracking_to_instance.rb'),('20160531164756_add_local_dns_blobs.rb'),('20160614182106_change_text_to_longtext_for_mysql.rb'),('20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb'),('20160706131605_change_events_id_type.rb'),('20160708234509_add_local_dns_records.rb'),('20160712171230_add_version_to_local_dns_blobs.rb'),('20160725090007_add_cpi_configs.rb'),('20160803151600_add_name_to_persistent_disks.rb'),('20160817135953_add_cpi_to_stemcells.rb'),('20160818112257_change_stemcell_unique_key.rb'),('20161031204534_populate_lifecycle_on_instance_spec.rb'),('20161128181900_add_logs_to_tasks.rb'),('20161209104649_add_context_id_to_tasks.rb'),('20161221151107_allow_null_instance_id_local_dns.rb'),('20170104003158_add_agent_dns_version.rb'),('20170116235940_add_errand_runs.rb'),('20170119202003_update_sha1_column_sizes.rb'),('20170203212124_add_variables.rb'),('20170216194502_remove_blobstore_id_idx_from_local_dns_blobs.rb'),('20170217000000_variables_instance_table_foreign_key_update.rb'),('20170301192646_add_deployed_successfully_to_variable_sets.rb'),('20170303175054_expand_template_json_column_lengths.rb'),('20170306215659_expand_vms_json_column_lengths.rb'),('20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records.rb'),('20170321151400_add_writable_to_variable_set.rb'),('20170328224049_associate_vm_info_with_vms_table.rb'),('20170331171657_remove_active_vm_id_from_instances.rb'),('20170405144414_add_cross_deployment_links_support_for_variables.rb'),('20170405181126_backfill_local_dns_records_and_drop_name.rb'),('20170412205032_add_agent_id_and_domain_name_to_local_dns_records.rb'),('20170427194511_add_runtime_config_name_support.rb'),('20170503205545_change_id_local_dns_to_bigint.rb'),('20170510154449_add_multi_runtime_config_support.rb'),('20170510190908_alter_ephemeral_blobs.rb'),('20170616185237_migrate_spec_json_links.rb');
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `snapshots`
--

LOCK TABLES `snapshots` WRITE;
/*!40000 ALTER TABLE `snapshots` DISABLE KEYS */;
INSERT INTO `snapshots` VALUES (1,1,1,'2017-07-14 15:49:24','0586089170e1f33c5b7e03b861c17f72');
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
INSERT INTO `stemcells` VALUES (1,'ubuntu-stemcell','1','68aab7c44c857217641784806e2eeac4a3a99d1c','shawone','toronto-os','');
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2017-07-14 15:49:12','create release','Created release \'bosh-release/0+dev.1\'','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-73954/sandbox/boshdir/tasks/1','2017-07-14 15:49:11','update_release','test',NULL,'2017-07-14 15:49:11','{\"time\":1500047351,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047351,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047351,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047351,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047351,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047351,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047351,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047351,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047351,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/142c10d6cd586cd9b092b2618922194b608160f7\",\"index\":10,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/142c10d6cd586cd9b092b2618922194b608160f7\",\"index\":10,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6\",\"index\":13,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6\",\"index\":13,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/c12835da15038bedad6c49d20a2dda00375a0dc0\",\"index\":19,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/c12835da15038bedad6c49d20a2dda00375a0dc0\",\"index\":19,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047352,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047352,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(2,'done','2017-07-14 15:49:14','create stemcell','/stemcells/ubuntu-stemcell/1','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-73954/sandbox/boshdir/tasks/2','2017-07-14 15:49:13','update_stemcell','test',NULL,'2017-07-14 15:49:13','{\"time\":1500047353,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047353,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047353,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047353,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047354,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n','',''),(3,'done','2017-07-14 15:49:23','create deployment','/deployments/simple','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-73954/sandbox/boshdir/tasks/3','2017-07-14 15:49:14','update_deployment','test','simple','2017-07-14 15:49:14','{\"time\":1500047354,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047355,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047355,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047355,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047355,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047356,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047356,\"stage\":\"Updating instance\",\"tags\":[\"ig_provider\"],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047363,\"stage\":\"Updating instance\",\"tags\":[\"ig_provider\"],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(4,'done','2017-07-14 15:49:25','create deployment','/deployments/simple','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-73954/sandbox/boshdir/tasks/4','2017-07-14 15:49:24','update_deployment','test','simple','2017-07-14 15:49:24','{\"time\":1500047364,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047364,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047364,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047364,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1500047364,\"stage\":\"Updating instance\",\"tags\":[\"ig_provider\"],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1500047364,\"stage\":\"Updating instance\",\"tags\":[\"ig_provider\"],\"total\":1,\"task\":\"ig_provider/e3934a8c-68bf-4f80-be7b-aa704cc4e3aa (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(5,'done','2017-07-14 15:49:26','retrieve vm-stats','','/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-73954/sandbox/boshdir/tasks/5','2017-07-14 15:49:26','vms','test','simple','2017-07-14 15:49:26','','{\"vm_cid\":null,\"disk_cid\":\"779dfbd39a3309bf99cf10d96ce62f65\",\"disk_cids\":[\"779dfbd39a3309bf99cf10d96ce62f65\"],\"ips\":[\"10.10.0.2\"],\"dns\":[\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa.ig-provider.private.simple.bosh\",\"0.ig-provider.private.simple.bosh\"],\"agent_id\":null,\"job_name\":\"ig_provider\",\"index\":0,\"job_state\":null,\"state\":\"detached\",\"resource_pool\":\"small\",\"vm_type\":\"small\",\"vitals\":null,\"processes\":[],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"e3934a8c-68bf-4f80-be7b-aa704cc4e3aa\",\"bootstrap\":true,\"ignore\":false}\n','');
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
  PRIMARY KEY (`id`),
  UNIQUE KEY `release_id` (`release_id`,`name`,`version`),
  KEY `templates_fingerprint_index` (`fingerprint`),
  KEY `templates_sha1_index` (`sha1`),
  CONSTRAINT `templates_ibfk_1` FOREIGN KEY (`release_id`) REFERENCES `releases` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `templates`
--

LOCK TABLES `templates` WRITE;
/*!40000 ALTER TABLE `templates` DISABLE KEYS */;
INSERT INTO `templates` VALUES (1,'addon','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','2c2a9015-01b5-4a28-a780-9814a89977ac','cef2715095bf91565755934adbc66f81534922c7','[]',1,'null','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','{}','[{\"name\":\"db\",\"type\":\"db\"}]',NULL),(2,'api_server','db761328436e7557b071dbcf4ddcc4417ef9b1bf','1e0171be-d6c6-49df-82cd-d3f186f9bb8e','13c6cbe2e15384c99c98b3f13a62ce933c1a408b','[\"pkg_3_depends_on_2\"]',1,'null','db761328436e7557b071dbcf4ddcc4417ef9b1bf','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}]',NULL),(3,'api_server_with_bad_link_types','058b26819bd6561a75c2fed45ec49e671c9fbc6a','9763c8ea-0ae8-459c-bf35-c82c62340158','2b0cee2da197c5e1a31233c576dd7278ec7af550','[\"pkg_3_depends_on_2\"]',1,'null','058b26819bd6561a75c2fed45ec49e671c9fbc6a','{}','[{\"name\":\"db\",\"type\":\"bad_link\"},{\"name\":\"backup_db\",\"type\":\"bad_link_2\"},{\"name\":\"some_link_name\",\"type\":\"bad_link_3\"}]',NULL),(4,'api_server_with_bad_optional_links','8a2485f1de3d99657e101fd269202c39cf3b5d73','6534c894-0aad-4286-adf0-24c5cfeb64ed','4c70bf6aea8596cacba046605643b23849687326','[\"pkg_3_depends_on_2\"]',1,'null','8a2485f1de3d99657e101fd269202c39cf3b5d73','{}','[{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}]',NULL),(5,'api_server_with_optional_db_link','00831c288b4a42454543ff69f71360634bd06b7b','338e1468-2806-4e64-bcb5-07c3e1b2c2d8','93930fb84e72aa7880f57d20bf1c664714d0f6e8','[\"pkg_3_depends_on_2\"]',1,'null','00831c288b4a42454543ff69f71360634bd06b7b','{}','[{\"name\":\"db\",\"type\":\"db\",\"optional\":true}]',NULL),(6,'api_server_with_optional_links_1','0efc908dd04d84858e3cf8b75c326f35af5a5a98','aa622227-160b-489a-992a-af75b52ed46c','e6224134e91883559431da1886b949a331ccaf0e','[\"pkg_3_depends_on_2\"]',1,'null','0efc908dd04d84858e3cf8b75c326f35af5a5a98','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"},{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}]',NULL),(7,'api_server_with_optional_links_2','15f815868a057180e21dbac61629f73ad3558fec','f7035372-07e1-40fd-84ad-1be2a68ad9a2','0c470d052adfcbf6cad02599988246f399441171','[\"pkg_3_depends_on_2\"]',1,'null','15f815868a057180e21dbac61629f73ad3558fec','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\",\"optional\":true}]',NULL),(8,'app_server','58e364fb74a01a1358475fc1da2ad905b78b4487','81c0ad61-7a4c-479b-ad2f-76599125e2c8','9bef91753e145985855f4f9e567a08dcd5c92bb4','[]',1,'null','58e364fb74a01a1358475fc1da2ad905b78b4487','{}',NULL,NULL),(9,'backup_database','822933af7d854849051ca16539653158ad233e5e','9b7d27cb-318b-4d8b-a8b2-a779abccd97f','7d67db3101d5a0fadf77ff5cb9053c146878e86d','[]',1,'null','822933af7d854849051ca16539653158ad233e5e','{\"foo\":{\"default\":\"backup_bar\"}}',NULL,'[{\"name\":\"backup_db\",\"type\":\"db\",\"properties\":[\"foo\"]}]'),(10,'consumer','142c10d6cd586cd9b092b2618922194b608160f7','1073f30f-13a8-48ce-bcee-e4ec2cec2e76','5d6505e1e897a7de684ffed78e57cfc8ae12d669','[]',1,'null','142c10d6cd586cd9b092b2618922194b608160f7','{}','[{\"name\":\"provider\",\"type\":\"provider\"}]',NULL),(11,'database','b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65','77399bf0-b591-4aef-9ded-81217e61970f','9629d1062bf87cc5e24e4249fdae2b7503f45c12','[]',1,'null','b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65','{\"foo\":{\"default\":\"normal_bar\"},\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}',NULL,'[{\"name\":\"db\",\"type\":\"db\",\"properties\":[\"foo\"]}]'),(12,'database_with_two_provided_link_of_same_type','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','19e3e3d2-bf58-449d-8bc9-9aa3f4f1db20','9dfdc912be7a542ba0f603baea5b016a6432372a','[]',1,'null','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','{\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}',NULL,'[{\"name\":\"db1\",\"type\":\"db\"},{\"name\":\"db2\",\"type\":\"db\"}]'),(13,'errand_with_links','323401e6d25c0420d6dc85d2a2964c2c6569cfd6','8d89dc89-48b5-4522-b36e-0dcd439c0ae2','0072bf7e1a5b67858858f9554a6a4b7f6fe0fd05','[]',1,'null','323401e6d25c0420d6dc85d2a2964c2c6569cfd6','{}','[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}]',NULL),(14,'http_endpoint_provider_with_property_types','30978e9fd0d29e52fe0369262e11fbcea1283889','e8907b70-2e43-4800-9f4b-996c13287892','8a2647d9826483568c906705dfa3ba5384230061','[]',1,'null','30978e9fd0d29e52fe0369262e11fbcea1283889','{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"Has a type password and no default value\",\"type\":\"password\"}}',NULL,'[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}]'),(15,'http_proxy_with_requires','760680c4a796a2ffca24026c561c06dd5bdef6b3','c3a8e164-6d19-4b0e-98db-d517c664a158','a23af0cecc81aa10c7f257c819a85e54738c94cb','[]',1,'null','760680c4a796a2ffca24026c561c06dd5bdef6b3','{\"http_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"http_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"http_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"http_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"http_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}','[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"},{\"name\":\"logs_http_endpoint\",\"type\":\"http_endpoint2\",\"optional\":true}]',NULL),(16,'http_server_with_provides','64244f12f2db2e7d93ccfbc13be744df87013389','84bd8940-21c5-4901-8abf-8ec738bf428a','490d8e34bedea9de785fab12f4e46bd7b6bbdb58','[]',1,'null','64244f12f2db2e7d93ccfbc13be744df87013389','{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}',NULL,'[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}]'),(17,'kv_http_server','044ec02730e6d068ecf88a0d37fe48937687bdba','729d8f47-8267-47c2-a7ac-6278b65b1124','12091f3247572624d2c4dff7e4c203bde46eb989','[]',1,'null','044ec02730e6d068ecf88a0d37fe48937687bdba','{\"kv_http_server.listen_port\":{\"description\":\"Port to listen on\",\"default\":8080}}','[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}]','[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}]'),(18,'mongo_db','58529a6cd5775fa1f7ef89ab4165e0331cdb0c59','f2c72586-134c-4b33-ba8f-6b9d3f99f2ab','e3ac23ef53768e15f0d1e6279e4778458b760c56','[\"pkg_1\"]',1,'null','58529a6cd5775fa1f7ef89ab4165e0331cdb0c59','{\"foo\":{\"default\":\"mongo_foo_db\"}}',NULL,'[{\"name\":\"read_only_db\",\"type\":\"db\",\"properties\":[\"foo\"]}]'),(19,'node','c12835da15038bedad6c49d20a2dda00375a0dc0','bc5a9578-849e-4edc-b0fe-4f3cb50e05e6','31c7339f0ff36388484a2d2ac55974709ea81b47','[]',1,'null','c12835da15038bedad6c49d20a2dda00375a0dc0','{}','[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}]','[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}]'),(20,'provider','e1ff4ff9a6304e1222484570a400788c55154b1c','09d9f54e-a87f-4f50-ab19-dbf89bbb9ad1','31de06fc89964ce23dd556b1f54ab2212964e2e1','[]',1,'null','e1ff4ff9a6304e1222484570a400788c55154b1c','{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"b\":{\"description\":\"description for b\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}',NULL,'[{\"name\":\"provider\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}]'),(21,'provider_fail','314c385e96711cb5d56dd909a086563dae61bc37','4147d7fb-7055-480c-b86e-6c6093eb72f5','22be18b3d29a73b054afba3a5ee2cd3313ecf9d6','[]',1,'null','314c385e96711cb5d56dd909a086563dae61bc37','{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}',NULL,'[{\"name\":\"provider_fail\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}]'),(22,'tcp_proxy_with_requires','e60ea353cdd24b6997efdedab144431c0180645b','afa6e8dd-8048-486d-93f5-86b18faaba8b','0c7dcb13b3592f461b7210ea2a6b1cdfc1223522','[]',1,'null','e60ea353cdd24b6997efdedab144431c0180645b','{\"tcp_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"tcp_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"tcp_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"tcp_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"tcp_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}','[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"}]',NULL),(23,'tcp_server_with_provides','6c9ab3bde161668d1d1ea60f3611c3b19a3b3267','1f13202a-0a0e-4c5c-a8b8-31203256a4c1','cc49985c4370d490d035614e4780793402d991d5','[]',1,'null','6c9ab3bde161668d1d1ea60f3611c3b19a3b3267','{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}',NULL,'[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}]');
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
-- Table structure for table `variable_sets`
--

DROP TABLE IF EXISTS `variable_sets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `variable_sets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
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
INSERT INTO `variable_sets` VALUES (1,1,'2017-07-14 15:49:14',1,0);
/*!40000 ALTER TABLE `variable_sets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `variables`
--

DROP TABLE IF EXISTS `variables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `variables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `variable_id` varchar(255) NOT NULL,
  `variable_name` varchar(255) NOT NULL,
  `variable_set_id` int(11) NOT NULL,
  `is_local` tinyint(1) DEFAULT '1',
  `provider_deployment` varchar(255) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `variable_set_name_provider_idx` (`variable_set_id`,`variable_name`,`provider_deployment`),
  CONSTRAINT `variables_ibfk_1` FOREIGN KEY (`variable_set_id`) REFERENCES `variable_sets` (`id`) ON DELETE CASCADE
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
  `credentials_json` longtext,
  `trusted_certs_sha1` varchar(255) DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
  `active` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `agent_id` (`agent_id`),
  UNIQUE KEY `cid` (`cid`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `vms_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
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

-- Dump completed on 2017-07-14 11:50:09
