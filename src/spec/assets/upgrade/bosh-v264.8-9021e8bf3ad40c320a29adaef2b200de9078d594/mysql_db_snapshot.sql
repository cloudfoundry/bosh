-- MySQL dump 10.13  Distrib 5.7.20, for osx10.12 (x86_64)
--
-- Host: 127.0.0.1    Database: f5d256fe3b6b4e25a0c01e14d6fdc9c0
-- ------------------------------------------------------
-- Server version	5.7.20

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
INSERT INTO `compiled_packages` VALUES (1,'46864eae-3658-49ea-52a6-edbbc84f5cca','e451c51b8f16abb07466c0feca2619f5dd459e48','[]',1,2,'97d170e1550eee4afc0af065b78cda302a97674c','toronto-os','1'),(2,'8115ca2b-5d97-438d-5479-582e2c74a4d7','ffcdc4275f545f12a696bab28b547d89ebf12327','[[\"pkg_2\",\"fa48497a19f12e925b32fcb8f5ca2b42144e4444\"]]',1,3,'b048798b462817f4ae6a5345dd9a0c45d1a1c8ea','toronto-os','1');
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
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `configs`
--

LOCK TABLES `configs` WRITE;
/*!40000 ALTER TABLE `configs` DISABLE KEYS */;
INSERT INTO `configs` VALUES (1,'default','cloud','azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n- name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nvm_types:\n- cloud_properties: {}\n  name: a\n','2018-03-01 22:56:46',0);
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
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8;
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'errand_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  name: errand_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(2,'shared_provider_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_provider_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{\"shared_provider_ig\":{\"database\":{\"my_shared_db\":{\"db\":{\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"default_network\":\"a\",\"networks\":[\"a\"],\"instance_group\":\"shared_provider_ig\",\"properties\":{\"foo\":\"normal_bar\"},\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"a8c7075c-e072-4500-a927-a5873851bca8\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\",\"addresses\":{\"a\":\"192.168.1.3\"},\"dns_addresses\":{\"a\":\"192.168.1.3\"}}]}}}}}'),(3,'shared_consumer_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_consumer_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(4,'implicit_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n  name: implicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: api_server\n  name: implicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: implicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(5,'explicit_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: explicit_db\n  name: explicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        from: explicit_db\n      db:\n        from: explicit_db\n    name: api_server\n  name: explicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: explicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}');
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
INSERT INTO `deployments_configs` VALUES (1,1),(2,1),(3,1),(4,1),(5,1);
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_release_versions`
--

LOCK TABLES `deployments_release_versions` WRITE;
/*!40000 ALTER TABLE `deployments_release_versions` DISABLE KEYS */;
INSERT INTO `deployments_release_versions` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5);
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_stemcells`
--

LOCK TABLES `deployments_stemcells` WRITE;
/*!40000 ALTER TABLE `deployments_stemcells` DISABLE KEYS */;
INSERT INTO `deployments_stemcells` VALUES (1,1,1),(2,2,1),(3,3,1),(4,4,1),(5,5,1);
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
INSERT INTO `domains` VALUES (1,'bosh',NULL,NULL,'NATIVE',NULL,NULL),(2,'1.168.192.in-addr.arpa',NULL,NULL,'NATIVE',NULL,NULL);
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
) ENGINE=InnoDB AUTO_INCREMENT=144 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,NULL,'_director','2018-03-01 22:56:42','start','worker','worker_2',NULL,NULL,NULL,NULL,'{}'),(2,NULL,'_director','2018-03-01 22:56:42','start','worker','worker_1',NULL,NULL,NULL,NULL,'{}'),(3,NULL,'_director','2018-03-01 22:56:42','start','director','deadbeef',NULL,NULL,NULL,NULL,'{\"version\":\"0.0.0\"}'),(4,NULL,'_director','2018-03-01 22:56:42','start','worker','worker_0',NULL,NULL,NULL,NULL,'{}'),(5,NULL,'test','2018-03-01 22:56:43','acquire','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(6,NULL,'test','2018-03-01 22:56:44','release','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(7,NULL,'test','2018-03-01 22:56:46','update','cloud-config','default',NULL,NULL,NULL,NULL,'{}'),(8,NULL,'test','2018-03-01 22:56:46','create','deployment','errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(9,NULL,'test','2018-03-01 22:56:46','acquire','lock','lock:deployment:errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(10,NULL,'test','2018-03-01 22:56:46','acquire','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(11,NULL,'test','2018-03-01 22:56:46','release','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(12,NULL,'test','2018-03-01 22:56:47','create','vm',NULL,NULL,'3','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(13,12,'test','2018-03-01 22:56:47','create','vm','56557',NULL,'3','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(14,NULL,'test','2018-03-01 22:56:47','create','instance','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b',NULL,'3','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{\"az\":\"z1\"}'),(15,14,'test','2018-03-01 22:56:53','create','instance','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b',NULL,'3','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(16,8,'test','2018-03-01 22:56:53','create','deployment','errand_deployment',NULL,'3','errand_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(17,NULL,'test','2018-03-01 22:56:53','release','lock','lock:deployment:errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(18,NULL,'test','2018-03-01 22:56:54','create','deployment','shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(19,NULL,'test','2018-03-01 22:56:54','acquire','lock','lock:deployment:shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(20,NULL,'test','2018-03-01 22:56:54','acquire','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(21,NULL,'test','2018-03-01 22:56:54','release','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(22,NULL,'test','2018-03-01 22:56:54','create','vm',NULL,NULL,'4','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(23,22,'test','2018-03-01 22:56:54','create','vm','56576',NULL,'4','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(24,NULL,'test','2018-03-01 22:56:55','create','instance','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8',NULL,'4','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{\"az\":\"z1\"}'),(25,24,'test','2018-03-01 22:57:01','create','instance','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8',NULL,'4','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(26,18,'test','2018-03-01 22:57:01','create','deployment','shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(27,NULL,'test','2018-03-01 22:57:01','release','lock','lock:deployment:shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(28,NULL,'test','2018-03-01 22:57:02','create','deployment','shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(29,NULL,'test','2018-03-01 22:57:02','acquire','lock','lock:deployment:shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(30,NULL,'test','2018-03-01 22:57:02','acquire','lock','lock:release:bosh-release',NULL,'5',NULL,NULL,'{}'),(31,NULL,'test','2018-03-01 22:57:02','release','lock','lock:release:bosh-release',NULL,'5',NULL,NULL,'{}'),(32,NULL,'test','2018-03-01 22:57:02','acquire','lock','lock:compile:2:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(33,NULL,'test','2018-03-01 22:57:02','create','instance','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(34,NULL,'test','2018-03-01 22:57:02','create','vm',NULL,NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(35,34,'test','2018-03-01 22:57:03','create','vm','56594',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(36,33,'test','2018-03-01 22:57:03','create','instance','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(37,NULL,'test','2018-03-01 22:57:04','delete','instance','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(38,NULL,'test','2018-03-01 22:57:04','delete','vm','56594',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(39,38,'test','2018-03-01 22:57:04','delete','vm','56594',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(40,37,'test','2018-03-01 22:57:04','delete','instance','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f',NULL,'5','shared_consumer_deployment','compilation-45078f18-ad66-4fc2-9c6e-adba5ec0f21c/f3bdf56c-e76a-4682-b1fb-f58f9fec860f','{}'),(41,NULL,'test','2018-03-01 22:57:04','release','lock','lock:compile:2:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(42,NULL,'test','2018-03-01 22:57:04','acquire','lock','lock:compile:3:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(43,NULL,'test','2018-03-01 22:57:04','create','instance','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(44,NULL,'test','2018-03-01 22:57:05','create','vm',NULL,NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(45,44,'test','2018-03-01 22:57:05','create','vm','56610',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(46,43,'test','2018-03-01 22:57:05','create','instance','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(47,NULL,'test','2018-03-01 22:57:06','delete','instance','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(48,NULL,'test','2018-03-01 22:57:06','delete','vm','56610',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(49,48,'test','2018-03-01 22:57:07','delete','vm','56610',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(50,47,'test','2018-03-01 22:57:07','delete','instance','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259',NULL,'5','shared_consumer_deployment','compilation-f9902ea4-4023-4f67-97e4-e0bd34cbb548/e7fc115b-be8e-412b-a95d-d37db6e0d259','{}'),(51,NULL,'test','2018-03-01 22:57:07','release','lock','lock:compile:3:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(52,NULL,'test','2018-03-01 22:57:07','create','vm',NULL,NULL,'5','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(53,52,'test','2018-03-01 22:57:07','create','vm','56627',NULL,'5','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(54,NULL,'test','2018-03-01 22:57:08','create','instance','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb',NULL,'5','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{\"az\":\"z1\"}'),(55,54,'test','2018-03-01 22:57:14','create','instance','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb',NULL,'5','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(56,28,'test','2018-03-01 22:57:14','create','deployment','shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(57,NULL,'test','2018-03-01 22:57:14','release','lock','lock:deployment:shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(58,NULL,'test','2018-03-01 22:57:16','create','deployment','implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(59,NULL,'test','2018-03-01 22:57:16','acquire','lock','lock:deployment:implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(60,NULL,'test','2018-03-01 22:57:16','acquire','lock','lock:release:bosh-release',NULL,'7',NULL,NULL,'{}'),(61,NULL,'test','2018-03-01 22:57:16','release','lock','lock:release:bosh-release',NULL,'7',NULL,NULL,'{}'),(62,NULL,'test','2018-03-01 22:57:17','create','vm',NULL,NULL,'7','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(63,NULL,'test','2018-03-01 22:57:17','create','vm',NULL,NULL,'7','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(64,63,'test','2018-03-01 22:57:17','create','vm','56651',NULL,'7','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(65,62,'test','2018-03-01 22:57:17','create','vm','56660',NULL,'7','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(66,NULL,'test','2018-03-01 22:57:18','create','instance','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052',NULL,'7','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{\"az\":\"z1\"}'),(67,66,'test','2018-03-01 22:57:23','create','instance','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052',NULL,'7','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(68,NULL,'test','2018-03-01 22:57:23','create','instance','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499',NULL,'7','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{\"az\":\"z1\"}'),(69,68,'test','2018-03-01 22:57:29','create','instance','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499',NULL,'7','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(70,58,'test','2018-03-01 22:57:29','create','deployment','implicit_deployment',NULL,'7','implicit_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(71,NULL,'test','2018-03-01 22:57:29','release','lock','lock:deployment:implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(72,NULL,'test','2018-03-01 22:57:31','create','deployment','explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(73,NULL,'test','2018-03-01 22:57:31','acquire','lock','lock:deployment:explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(74,NULL,'test','2018-03-01 22:57:31','acquire','lock','lock:release:bosh-release',NULL,'9',NULL,NULL,'{}'),(75,NULL,'test','2018-03-01 22:57:31','release','lock','lock:release:bosh-release',NULL,'9',NULL,NULL,'{}'),(76,NULL,'test','2018-03-01 22:57:32','create','vm',NULL,NULL,'9','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(77,NULL,'test','2018-03-01 22:57:32','create','vm',NULL,NULL,'9','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(78,76,'test','2018-03-01 22:57:32','create','vm','56687',NULL,'9','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(79,77,'test','2018-03-01 22:57:32','create','vm','56694',NULL,'9','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(80,NULL,'test','2018-03-01 22:57:33','create','instance','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096',NULL,'9','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{\"az\":\"z1\"}'),(81,80,'test','2018-03-01 22:57:38','create','instance','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096',NULL,'9','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(82,NULL,'test','2018-03-01 22:57:38','create','instance','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301',NULL,'9','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{\"az\":\"z1\"}'),(83,82,'test','2018-03-01 22:57:44','create','instance','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301',NULL,'9','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(84,72,'test','2018-03-01 22:57:44','create','deployment','explicit_deployment',NULL,'9','explicit_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(85,NULL,'test','2018-03-01 22:57:44','release','lock','lock:deployment:explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(86,NULL,'test','2018-03-01 22:57:47','update','deployment','errand_deployment',NULL,'11','errand_deployment',NULL,'{}'),(87,NULL,'test','2018-03-01 22:57:47','acquire','lock','lock:deployment:errand_deployment',NULL,'11','errand_deployment',NULL,'{}'),(88,NULL,'test','2018-03-01 22:57:47','acquire','lock','lock:release:bosh-release',NULL,'11',NULL,NULL,'{}'),(89,NULL,'test','2018-03-01 22:57:47','release','lock','lock:release:bosh-release',NULL,'11',NULL,NULL,'{}'),(90,NULL,'test','2018-03-01 22:57:47','stop','instance','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b',NULL,'11','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(91,NULL,'test','2018-03-01 22:57:47','delete','vm','56557',NULL,'11','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(92,91,'test','2018-03-01 22:57:47','delete','vm','56557',NULL,'11','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(93,90,'test','2018-03-01 22:57:47','stop','instance','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b',NULL,'11','errand_deployment','errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','{}'),(94,86,'test','2018-03-01 22:57:47','update','deployment','errand_deployment',NULL,'11','errand_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(95,NULL,'test','2018-03-01 22:57:47','release','lock','lock:deployment:errand_deployment',NULL,'11','errand_deployment',NULL,'{}'),(96,NULL,'test','2018-03-01 22:57:48','update','deployment','shared_provider_deployment',NULL,'12','shared_provider_deployment',NULL,'{}'),(97,NULL,'test','2018-03-01 22:57:48','acquire','lock','lock:deployment:shared_provider_deployment',NULL,'12','shared_provider_deployment',NULL,'{}'),(98,NULL,'test','2018-03-01 22:57:48','acquire','lock','lock:release:bosh-release',NULL,'12',NULL,NULL,'{}'),(99,NULL,'test','2018-03-01 22:57:48','release','lock','lock:release:bosh-release',NULL,'12',NULL,NULL,'{}'),(100,NULL,'test','2018-03-01 22:57:48','stop','instance','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8',NULL,'12','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(101,NULL,'test','2018-03-01 22:57:48','delete','vm','56576',NULL,'12','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(102,101,'test','2018-03-01 22:57:48','delete','vm','56576',NULL,'12','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(103,100,'test','2018-03-01 22:57:49','stop','instance','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8',NULL,'12','shared_provider_deployment','shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8','{}'),(104,96,'test','2018-03-01 22:57:49','update','deployment','shared_provider_deployment',NULL,'12','shared_provider_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(105,NULL,'test','2018-03-01 22:57:49','release','lock','lock:deployment:shared_provider_deployment',NULL,'12','shared_provider_deployment',NULL,'{}'),(106,NULL,'test','2018-03-01 22:57:50','update','deployment','shared_consumer_deployment',NULL,'13','shared_consumer_deployment',NULL,'{}'),(107,NULL,'test','2018-03-01 22:57:50','acquire','lock','lock:deployment:shared_consumer_deployment',NULL,'13','shared_consumer_deployment',NULL,'{}'),(108,NULL,'test','2018-03-01 22:57:50','acquire','lock','lock:release:bosh-release',NULL,'13',NULL,NULL,'{}'),(109,NULL,'test','2018-03-01 22:57:50','release','lock','lock:release:bosh-release',NULL,'13',NULL,NULL,'{}'),(110,NULL,'test','2018-03-01 22:57:50','stop','instance','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb',NULL,'13','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(111,NULL,'test','2018-03-01 22:57:50','delete','vm','56627',NULL,'13','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(112,111,'test','2018-03-01 22:57:50','delete','vm','56627',NULL,'13','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(113,110,'test','2018-03-01 22:57:50','stop','instance','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb',NULL,'13','shared_consumer_deployment','shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb','{}'),(114,106,'test','2018-03-01 22:57:50','update','deployment','shared_consumer_deployment',NULL,'13','shared_consumer_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(115,NULL,'test','2018-03-01 22:57:50','release','lock','lock:deployment:shared_consumer_deployment',NULL,'13','shared_consumer_deployment',NULL,'{}'),(116,NULL,'test','2018-03-01 22:57:52','update','deployment','implicit_deployment',NULL,'14','implicit_deployment',NULL,'{}'),(117,NULL,'test','2018-03-01 22:57:52','acquire','lock','lock:deployment:implicit_deployment',NULL,'14','implicit_deployment',NULL,'{}'),(118,NULL,'test','2018-03-01 22:57:52','acquire','lock','lock:release:bosh-release',NULL,'14',NULL,NULL,'{}'),(119,NULL,'test','2018-03-01 22:57:52','release','lock','lock:release:bosh-release',NULL,'14',NULL,NULL,'{}'),(120,NULL,'test','2018-03-01 22:57:52','stop','instance','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052',NULL,'14','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(121,NULL,'test','2018-03-01 22:57:52','delete','vm','56660',NULL,'14','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(122,121,'test','2018-03-01 22:57:52','delete','vm','56660',NULL,'14','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(123,120,'test','2018-03-01 22:57:53','stop','instance','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052',NULL,'14','implicit_deployment','implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052','{}'),(124,NULL,'test','2018-03-01 22:57:53','stop','instance','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499',NULL,'14','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(125,NULL,'test','2018-03-01 22:57:53','delete','vm','56651',NULL,'14','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(126,125,'test','2018-03-01 22:57:53','delete','vm','56651',NULL,'14','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(127,124,'test','2018-03-01 22:57:53','stop','instance','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499',NULL,'14','implicit_deployment','implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499','{}'),(128,116,'test','2018-03-01 22:57:53','update','deployment','implicit_deployment',NULL,'14','implicit_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(129,NULL,'test','2018-03-01 22:57:53','release','lock','lock:deployment:implicit_deployment',NULL,'14','implicit_deployment',NULL,'{}'),(130,NULL,'test','2018-03-01 22:57:54','update','deployment','explicit_deployment',NULL,'15','explicit_deployment',NULL,'{}'),(131,NULL,'test','2018-03-01 22:57:54','acquire','lock','lock:deployment:explicit_deployment',NULL,'15','explicit_deployment',NULL,'{}'),(132,NULL,'test','2018-03-01 22:57:54','acquire','lock','lock:release:bosh-release',NULL,'15',NULL,NULL,'{}'),(133,NULL,'test','2018-03-01 22:57:54','release','lock','lock:release:bosh-release',NULL,'15',NULL,NULL,'{}'),(134,NULL,'test','2018-03-01 22:57:54','stop','instance','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096',NULL,'15','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(135,NULL,'test','2018-03-01 22:57:54','delete','vm','56694',NULL,'15','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(136,135,'test','2018-03-01 22:57:55','delete','vm','56694',NULL,'15','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(137,134,'test','2018-03-01 22:57:55','stop','instance','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096',NULL,'15','explicit_deployment','explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096','{}'),(138,NULL,'test','2018-03-01 22:57:55','stop','instance','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301',NULL,'15','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(139,NULL,'test','2018-03-01 22:57:55','delete','vm','56687',NULL,'15','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(140,139,'test','2018-03-01 22:57:55','delete','vm','56687',NULL,'15','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(141,138,'test','2018-03-01 22:57:55','stop','instance','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301',NULL,'15','explicit_deployment','explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301','{}'),(142,130,'test','2018-03-01 22:57:55','update','deployment','explicit_deployment',NULL,'15','explicit_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(143,NULL,'test','2018-03-01 22:57:55','release','lock','lock:deployment:explicit_deployment',NULL,'15','explicit_deployment',NULL,'{}');
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
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'errand_provider_ig',0,1,'detached',0,'8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b','z1','{}',0,1,'[\"0.errand-provider-ig.a.errand-deployment.bosh\",\"8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b.errand-provider-ig.a.errand-deployment.bosh\"]','{\"deployment\":\"errand_deployment\",\"job\":{\"name\":\"errand_provider_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"1b36f3c3425d406bd891ca743dcad504b51c13a0\",\"blobstore_id\":\"fc551cab-1138-4c5a-9c58-745aa4ec5640\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"1b36f3c3425d406bd891ca743dcad504b51c13a0\",\"blobstore_id\":\"fc551cab-1138-4c5a-9c58-745aa4ec5640\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"errand_provider_ig\",\"id\":\"8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"6f669ade-1c02-4a70-8b7d-970f2800ed20\",\"sha1\":\"0871109ba7d0014b5aec56d6e017f54b616101e3\"},\"configuration_hash\":\"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1),(2,'errand_consumer_ig',0,1,'started',0,'ebd70e0e-bb80-43c1-9407-817368de4fa0','z1',NULL,0,1,'[]',NULL,NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',0,0,1),(3,'shared_provider_ig',0,2,'detached',0,'a8c7075c-e072-4500-a927-a5873851bca8','z1','{}',0,1,'[\"0.shared-provider-ig.a.shared-provider-deployment.bosh\",\"a8c7075c-e072-4500-a927-a5873851bca8.shared-provider-ig.a.shared-provider-deployment.bosh\"]','{\"deployment\":\"shared_provider_deployment\",\"job\":{\"name\":\"shared_provider_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"1b36f3c3425d406bd891ca743dcad504b51c13a0\",\"blobstore_id\":\"fc551cab-1138-4c5a-9c58-745aa4ec5640\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"1b36f3c3425d406bd891ca743dcad504b51c13a0\",\"blobstore_id\":\"fc551cab-1138-4c5a-9c58-745aa4ec5640\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_provider_ig\",\"id\":\"a8c7075c-e072-4500-a927-a5873851bca8\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.3\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.3\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"45e32cb2-bf38-456c-b0dd-6b165fdc7e37\",\"sha1\":\"bc0e0c92f0df21f1ece54e3f567719f2369747db\"},\"configuration_hash\":\"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,2),(4,'shared_consumer_ig',0,3,'detached',0,'d0e2d58a-db06-4401-865e-0b296c356bcb','z1','{}',0,1,'[\"0.shared-consumer-ig.a.shared-consumer-deployment.bosh\",\"d0e2d58a-db06-4401-865e-0b296c356bcb.shared-consumer-ig.a.shared-consumer-deployment.bosh\"]','{\"deployment\":\"shared_consumer_deployment\",\"job\":{\"name\":\"shared_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_consumer_ig\",\"id\":\"d0e2d58a-db06-4401-865e-0b296c356bcb\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.4\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"ffcdc4275f545f12a696bab28b547d89ebf12327\",\"blobstore_id\":\"8115ca2b-5d97-438d-5479-582e2c74a4d7\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"a8c7075c-e072-4500-a927-a5873851bca8\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"a8c7075c-e072-4500-a927-a5873851bca8\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}}}},\"address\":\"192.168.1.4\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"91108c3667a4fbc69bf37c13ea3365d241c34440\"},\"rendered_templates_archive\":{\"blobstore_id\":\"d16cf68f-f2e5-404b-a10d-7879ee873357\",\"sha1\":\"04aa9eaba00e1a981d816f77557cbc105d54f433\"},\"configuration_hash\":\"722091d016d9263bc90f75b4c97c93a52e423580\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,3),(7,'implicit_provider_ig',0,4,'detached',0,'b1603934-fab7-4dd2-9ba1-518e5dd8a052','z1','{}',0,1,'[\"0.implicit-provider-ig.a.implicit-deployment.bosh\",\"b1603934-fab7-4dd2-9ba1-518e5dd8a052.implicit-provider-ig.a.implicit-deployment.bosh\"]','{\"deployment\":\"implicit_deployment\",\"job\":{\"name\":\"implicit_provider_ig\",\"templates\":[{\"name\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"5fd5263ea7b7b6477f6efc531d4bf7d3e3387638\",\"blobstore_id\":\"2bebb31c-be44-4ac8-bad1-14f87b5b7db8\",\"logs\":[]}],\"template\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"5fd5263ea7b7b6477f6efc531d4bf7d3e3387638\",\"blobstore_id\":\"2bebb31c-be44-4ac8-bad1-14f87b5b7db8\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"implicit_provider_ig\",\"id\":\"b1603934-fab7-4dd2-9ba1-518e5dd8a052\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.5\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"backup_database\":{\"foo\":\"backup_bar\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.5\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"backup_database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"ddd4b08c-48af-453c-b596-170db48d4bed\",\"sha1\":\"a726ba2a30c4af6e5357ac2ec22980ce14edd670\"},\"configuration_hash\":\"4e4c9c0b7e76b5bc955b215edbd839e427d581aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,4),(8,'implicit_consumer_ig',0,4,'detached',0,'b32620f3-ba53-49d0-855c-94dec1b0a499','z1','{}',0,1,'[\"0.implicit-consumer-ig.a.implicit-deployment.bosh\",\"b32620f3-ba53-49d0-855c-94dec1b0a499.implicit-consumer-ig.a.implicit-deployment.bosh\"]','{\"deployment\":\"implicit_deployment\",\"job\":{\"name\":\"implicit_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"implicit_consumer_ig\",\"id\":\"b32620f3-ba53-49d0-855c-94dec1b0a499\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.6\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"ffcdc4275f545f12a696bab28b547d89ebf12327\",\"blobstore_id\":\"8115ca2b-5d97-438d-5479-582e2c74a4d7\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"implicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"implicit_provider_ig\",\"instances\":[{\"name\":\"implicit_provider_ig\",\"id\":\"b1603934-fab7-4dd2-9ba1-518e5dd8a052\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.5\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"implicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"implicit_provider_ig\",\"instances\":[{\"name\":\"implicit_provider_ig\",\"id\":\"b1603934-fab7-4dd2-9ba1-518e5dd8a052\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.5\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}}}},\"address\":\"192.168.1.6\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"c19c3371f4b0866af37d15520afb3a2fa03f85ad\"},\"rendered_templates_archive\":{\"blobstore_id\":\"12897626-ebce-49f2-ab72-571a8e1cca5b\",\"sha1\":\"15dac90598358a629da80cfb5eebeb8dbb0f243c\"},\"configuration_hash\":\"6654b3aff2b13491c191562a2140f39d4b60f5b7\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,4),(9,'explicit_provider_ig',0,5,'detached',0,'dc572fe0-2f43-431c-8cda-964d6ca6a096','z1','{}',0,1,'[\"0.explicit-provider-ig.a.explicit-deployment.bosh\",\"dc572fe0-2f43-431c-8cda-964d6ca6a096.explicit-provider-ig.a.explicit-deployment.bosh\"]','{\"deployment\":\"explicit_deployment\",\"job\":{\"name\":\"explicit_provider_ig\",\"templates\":[{\"name\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"5fd5263ea7b7b6477f6efc531d4bf7d3e3387638\",\"blobstore_id\":\"2bebb31c-be44-4ac8-bad1-14f87b5b7db8\",\"logs\":[]}],\"template\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"5fd5263ea7b7b6477f6efc531d4bf7d3e3387638\",\"blobstore_id\":\"2bebb31c-be44-4ac8-bad1-14f87b5b7db8\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"explicit_provider_ig\",\"id\":\"dc572fe0-2f43-431c-8cda-964d6ca6a096\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.7\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"backup_database\":{\"foo\":\"backup_bar\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.7\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"backup_database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"fa3a5599-a807-4813-8066-ab7ee6fd9eec\",\"sha1\":\"bb05f7ea2f9ea5f515c1ea2ebda60787a3d72126\"},\"configuration_hash\":\"4e4c9c0b7e76b5bc955b215edbd839e427d581aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,5),(10,'explicit_consumer_ig',0,5,'detached',0,'cb178871-1663-417a-bf39-c89669893301','z1','{}',0,1,'[\"0.explicit-consumer-ig.a.explicit-deployment.bosh\",\"cb178871-1663-417a-bf39-c89669893301.explicit-consumer-ig.a.explicit-deployment.bosh\"]','{\"deployment\":\"explicit_deployment\",\"job\":{\"name\":\"explicit_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"e35d48cca6c797656536badd5825df0c73012345\",\"blobstore_id\":\"8acd9f35-34ec-484e-8532-795b30c9b298\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"explicit_consumer_ig\",\"id\":\"cb178871-1663-417a-bf39-c89669893301\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.8\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"ffcdc4275f545f12a696bab28b547d89ebf12327\",\"blobstore_id\":\"8115ca2b-5d97-438d-5479-582e2c74a4d7\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"explicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"explicit_provider_ig\",\"instances\":[{\"name\":\"explicit_provider_ig\",\"id\":\"dc572fe0-2f43-431c-8cda-964d6ca6a096\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.7\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"explicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"explicit_provider_ig\",\"instances\":[{\"name\":\"explicit_provider_ig\",\"id\":\"dc572fe0-2f43-431c-8cda-964d6ca6a096\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.7\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}}}},\"address\":\"192.168.1.8\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"a39f234703833fbd34364bd72ce1559fdb200323\"},\"rendered_templates_archive\":{\"blobstore_id\":\"ddead45f-355e-4d34-90b3-917a0ca9a811\",\"sha1\":\"0704d317743b85fbc145fb3a2494aeb2385d45a4\"},\"configuration_hash\":\"fcac02052540e3a724c27f6bedc751394cadddff\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,5);
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances_templates`
--

LOCK TABLES `instances_templates` WRITE;
/*!40000 ALTER TABLE `instances_templates` DISABLE KEYS */;
INSERT INTO `instances_templates` VALUES (1,1,11),(2,3,11),(3,4,2),(4,7,9),(5,8,2),(6,9,9),(7,10,2);
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
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'a',0,1,'2018-03-01 22:56:46','3','3232235778'),(2,'a',0,3,'2018-03-01 22:56:54','4','3232235779'),(3,'a',0,4,'2018-03-01 22:57:02','5','3232235780'),(6,'a',0,7,'2018-03-01 22:57:16','7','3232235781'),(7,'a',0,8,'2018-03-01 22:57:16','7','3232235782'),(8,'a',0,9,'2018-03-01 22:57:32','9','3232235783'),(9,'a',0,10,'2018-03-01 22:57:32','9','3232235784');
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_azs`
--

LOCK TABLES `local_dns_encoded_azs` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_azs` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_azs` VALUES (1,'z1');
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
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_instance_groups`
--

LOCK TABLES `local_dns_encoded_instance_groups` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_instance_groups` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_instance_groups` VALUES (2,'errand_consumer_ig',1),(1,'errand_provider_ig',1),(8,'explicit_consumer_ig',5),(7,'explicit_provider_ig',5),(6,'implicit_consumer_ig',4),(5,'implicit_provider_ig',4),(4,'shared_consumer_ig',3),(3,'shared_provider_ig',2);
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_networks`
--

LOCK TABLES `local_dns_encoded_networks` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_networks` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_networks` VALUES (1,'a'),(2,'dynamic-network');
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_records`
--

LOCK TABLES `local_dns_records` WRITE;
/*!40000 ALTER TABLE `local_dns_records` DISABLE KEYS */;
INSERT INTO `local_dns_records` VALUES (8,'192.168.1.2','z1','errand_provider_ig','a','errand_deployment',1,NULL,'bosh'),(9,'192.168.1.3','z1','shared_provider_ig','a','shared_provider_deployment',3,NULL,'bosh'),(10,'192.168.1.4','z1','shared_consumer_ig','a','shared_consumer_deployment',4,NULL,'bosh'),(11,'192.168.1.5','z1','implicit_provider_ig','a','implicit_deployment',7,NULL,'bosh'),(12,'192.168.1.6','z1','implicit_consumer_ig','a','implicit_deployment',8,NULL,'bosh'),(13,'192.168.1.7','z1','explicit_provider_ig','a','explicit_deployment',9,NULL,'bosh'),(14,'192.168.1.8','z1','explicit_consumer_ig','a','explicit_deployment',10,NULL,'bosh');
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
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8;
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages`
--

LOCK TABLES `packages` WRITE;
/*!40000 ALTER TABLE `packages` DISABLE KEYS */;
INSERT INTO `packages` VALUES (1,'pkg_1','7a4094dc99aa72d2d156d99e022d3baa37fb7c4b','c1d1b9ae-c4e5-472a-be9f-afb7efc8f16b','ccb4b35377581b19179ef4debe7798a76b29375d','[]',1,'7a4094dc99aa72d2d156d99e022d3baa37fb7c4b'),(2,'pkg_2','fa48497a19f12e925b32fcb8f5ca2b42144e4444','6fd6b242-8173-4c55-95b2-825958f5ac75','2006719c7ffd8e53bd9471b3f31e714cda5f9093','[]',1,'fa48497a19f12e925b32fcb8f5ca2b42144e4444'),(3,'pkg_3_depends_on_2','2dfa256bc0b0750ae9952118c428b0dcd1010305','4b2b1967-6f33-439c-9e2f-e128daf1e28f','ee8e08b611304509541b6cee91896d1972446e3f','[\"pkg_2\"]',1,'2dfa256bc0b0750ae9952118c428b0dcd1010305');
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
) ENGINE=InnoDB AUTO_INCREMENT=34 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1519945074,1),(2,'bosh','NS','ns.bosh',14400,NULL,1519945074,1),(3,'ns.bosh','A',NULL,18000,NULL,1519945074,1),(4,'0.errand-provider-ig.a.errand-deployment.bosh','A','192.168.1.2',300,NULL,1519945067,1),(5,'1.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'1.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.1.168.192.in-addr.arpa','PTR','0.errand-provider-ig.a.errand-deployment.bosh',300,NULL,1519945067,2),(8,'8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b.errand-provider-ig.a.errand-deployment.bosh','A','192.168.1.2',300,NULL,1519945067,1),(9,'2.1.168.192.in-addr.arpa','PTR','8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b.errand-provider-ig.a.errand-deployment.bosh',300,NULL,1519945067,2),(10,'0.shared-provider-ig.a.shared-provider-deployment.bosh','A','192.168.1.3',300,NULL,1519945068,1),(11,'3.1.168.192.in-addr.arpa','PTR','0.shared-provider-ig.a.shared-provider-deployment.bosh',300,NULL,1519945068,2),(12,'a8c7075c-e072-4500-a927-a5873851bca8.shared-provider-ig.a.shared-provider-deployment.bosh','A','192.168.1.3',300,NULL,1519945069,1),(13,'3.1.168.192.in-addr.arpa','PTR','a8c7075c-e072-4500-a927-a5873851bca8.shared-provider-ig.a.shared-provider-deployment.bosh',300,NULL,1519945069,2),(14,'0.shared-consumer-ig.a.shared-consumer-deployment.bosh','A','192.168.1.4',300,NULL,1519945070,1),(15,'4.1.168.192.in-addr.arpa','PTR','0.shared-consumer-ig.a.shared-consumer-deployment.bosh',300,NULL,1519945070,2),(16,'d0e2d58a-db06-4401-865e-0b296c356bcb.shared-consumer-ig.a.shared-consumer-deployment.bosh','A','192.168.1.4',300,NULL,1519945070,1),(17,'4.1.168.192.in-addr.arpa','PTR','d0e2d58a-db06-4401-865e-0b296c356bcb.shared-consumer-ig.a.shared-consumer-deployment.bosh',300,NULL,1519945070,2),(18,'0.implicit-provider-ig.a.implicit-deployment.bosh','A','192.168.1.5',300,NULL,1519945072,1),(19,'5.1.168.192.in-addr.arpa','PTR','0.implicit-provider-ig.a.implicit-deployment.bosh',300,NULL,1519945073,2),(20,'b1603934-fab7-4dd2-9ba1-518e5dd8a052.implicit-provider-ig.a.implicit-deployment.bosh','A','192.168.1.5',300,NULL,1519945073,1),(21,'5.1.168.192.in-addr.arpa','PTR','b1603934-fab7-4dd2-9ba1-518e5dd8a052.implicit-provider-ig.a.implicit-deployment.bosh',300,NULL,1519945073,2),(22,'0.implicit-consumer-ig.a.implicit-deployment.bosh','A','192.168.1.6',300,NULL,1519945073,1),(23,'6.1.168.192.in-addr.arpa','PTR','0.implicit-consumer-ig.a.implicit-deployment.bosh',300,NULL,1519945073,2),(24,'b32620f3-ba53-49d0-855c-94dec1b0a499.implicit-consumer-ig.a.implicit-deployment.bosh','A','192.168.1.6',300,NULL,1519945073,1),(25,'6.1.168.192.in-addr.arpa','PTR','b32620f3-ba53-49d0-855c-94dec1b0a499.implicit-consumer-ig.a.implicit-deployment.bosh',300,NULL,1519945073,2),(26,'0.explicit-provider-ig.a.explicit-deployment.bosh','A','192.168.1.7',300,NULL,1519945075,1),(27,'7.1.168.192.in-addr.arpa','PTR','0.explicit-provider-ig.a.explicit-deployment.bosh',300,NULL,1519945075,2),(28,'dc572fe0-2f43-431c-8cda-964d6ca6a096.explicit-provider-ig.a.explicit-deployment.bosh','A','192.168.1.7',300,NULL,1519945075,1),(29,'7.1.168.192.in-addr.arpa','PTR','dc572fe0-2f43-431c-8cda-964d6ca6a096.explicit-provider-ig.a.explicit-deployment.bosh',300,NULL,1519945075,2),(30,'0.explicit-consumer-ig.a.explicit-deployment.bosh','A','192.168.1.8',300,NULL,1519945075,1),(31,'8.1.168.192.in-addr.arpa','PTR','0.explicit-consumer-ig.a.explicit-deployment.bosh',300,NULL,1519945075,2),(32,'cb178871-1663-417a-bf39-c89669893301.explicit-consumer-ig.a.explicit-deployment.bosh','A','192.168.1.8',300,NULL,1519945075,1),(33,'8.1.168.192.in-addr.arpa','PTR','cb178871-1663-417a-bf39-c89669893301.explicit-consumer-ig.a.explicit-deployment.bosh',300,NULL,1519945075,2);
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
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'9021e8bf3',1);
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rendered_templates_archives`
--

LOCK TABLES `rendered_templates_archives` WRITE;
/*!40000 ALTER TABLE `rendered_templates_archives` DISABLE KEYS */;
INSERT INTO `rendered_templates_archives` VALUES (1,1,'6f669ade-1c02-4a70-8b7d-970f2800ed20','0871109ba7d0014b5aec56d6e017f54b616101e3','6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf','2018-03-01 22:56:47'),(2,3,'45e32cb2-bf38-456c-b0dd-6b165fdc7e37','bc0e0c92f0df21f1ece54e3f567719f2369747db','6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf','2018-03-01 22:56:55'),(3,4,'d16cf68f-f2e5-404b-a10d-7879ee873357','04aa9eaba00e1a981d816f77557cbc105d54f433','722091d016d9263bc90f75b4c97c93a52e423580','2018-03-01 22:57:08'),(4,7,'ddd4b08c-48af-453c-b596-170db48d4bed','a726ba2a30c4af6e5357ac2ec22980ce14edd670','4e4c9c0b7e76b5bc955b215edbd839e427d581aa','2018-03-01 22:57:18'),(5,8,'12897626-ebce-49f2-ab72-571a8e1cca5b','15dac90598358a629da80cfb5eebeb8dbb0f243c','6654b3aff2b13491c191562a2140f39d4b60f5b7','2018-03-01 22:57:23'),(6,9,'fa3a5599-a807-4813-8066-ab7ee6fd9eec','bb05f7ea2f9ea5f515c1ea2ebda60787a3d72126','4e4c9c0b7e76b5bc955b215edbd839e427d581aa','2018-03-01 22:57:33'),(7,10,'ddead45f-355e-4d34-90b3-917a0ca9a811','0704d317743b85fbc145fb3a2494aeb2385d45a4','fcac02052540e3a724c27f6bedc751394cadddff','2018-03-01 22:57:38');
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
INSERT INTO `schema_migrations` VALUES ('20110209010747_initial.rb'),('20110406055800_add_task_user.rb'),('20110518225809_remove_cid_constrain.rb'),('20110617211923_add_deployments_release_versions.rb'),('20110622212607_add_task_checkpoint_timestamp.rb'),('20110628023039_add_state_to_instances.rb'),('20110709012332_add_disk_size_to_instances.rb'),('20110906183441_add_log_bundles.rb'),('20110907194830_add_logs_json_to_templates.rb'),('20110915205610_add_persistent_disks.rb'),('20111005180929_add_properties.rb'),('20111110024617_add_deployment_problems.rb'),('20111216214145_recreate_support_for_vms.rb'),('20120102084027_add_credentials_to_vms.rb'),('20120427235217_allow_multiple_releases_per_deployment.rb'),('20120524175805_add_task_type.rb'),('20120614001930_delete_redundant_deployment_release_relation.rb'),('20120822004528_add_fingerprint_to_templates_and_packages.rb'),('20120830191244_add_properties_to_templates.rb'),('20121106190739_persist_vm_env.rb'),('20130222232131_add_sha1_to_stemcells.rb'),('20130312211407_add_commit_hash_to_release_versions.rb'),('20130409235338_snapshot.rb'),('20130530164918_add_paused_flag_to_instance.rb'),('20130531172604_add_director_attributes.rb'),('20131121182231_add_rendered_templates_archives.rb'),('20131125232201_rename_rendered_templates_archives_blob_id_and_checksum_columns.rb'),('20140116002324_pivot_director_attributes.rb'),('20140124225348_proper_pk_for_attributes.rb'),('20140731215410_increase_text_limit_for_data_columns.rb'),('20141204234517_add_cloud_properties_to_persistent_disk.rb'),('20150102234124_denormalize_task_user_id_to_task_username.rb'),('20150223222605_increase_manifest_text_limit.rb'),('20150224193313_use_larger_text_types.rb'),('20150331002413_add_cloud_configs.rb'),('20150401184803_add_cloud_config_to_deployments.rb'),('20150513225143_ip_addresses.rb'),('20150611193110_add_trusted_certs_sha1_to_vms.rb'),('20150619135210_add_os_name_and_version_to_stemcells.rb'),('20150702004608_add_links.rb'),('20150708231924_add_link_spec.rb'),('20150716170926_allow_null_on_blobstore_id_and_sha1_on_package.rb'),('20150724183256_add_debugging_to_ip_addresses.rb'),('20150730225029_add_uuid_to_instances.rb'),('20150803215805_add_availabililty_zone_and_cloud_properties_to_instances.rb'),('20150804211419_add_compilation_flag_to_instance.rb'),('20150918003455_add_bootstrap_node_to_instance.rb'),('20151008232214_add_dns_records.rb'),('20151015172551_add_orphan_disks_and_snapshots.rb'),('20151030222853_add_templates_to_instance.rb'),('20151031001039_add_spec_to_instance.rb'),('20151109190602_rename_orphan_columns.rb'),('20151223172000_rename_requires_json.rb'),('20151229184742_add_vm_attributes_to_instance.rb'),('20160106162749_runtime_configs.rb'),('20160106163433_add_runtime_configs_to_deployments.rb'),('20160108191637_drop_vm_env_json_from_instance.rb'),('20160121003800_drop_vms_fkeys.rb'),('20160202162216_add_post_start_completed_to_instance.rb'),('20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb'),('20160211174110_add_events.rb'),('20160211193904_add_scopes_to_deployment.rb'),('20160219175840_add_column_teams_to_deployments.rb'),('20160224222508_add_deployment_name_to_task.rb'),('20160225182206_rename_post_start_completed.rb'),('20160324181932_create_delayed_jobs.rb'),('20160324182211_add_locks.rb'),('20160329201256_set_instances_with_nil_serial_to_false.rb'),('20160331225404_backfill_stemcell_os.rb'),('20160411104407_add_task_started_at.rb'),('20160414183654_set_teams_on_task.rb'),('20160427164345_add_teams.rb'),('20160511191928_ephemeral_blobs.rb'),('20160513102035_add_tracking_to_instance.rb'),('20160531164756_add_local_dns_blobs.rb'),('20160614182106_change_text_to_longtext_for_mysql.rb'),('20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb'),('20160706131605_change_events_id_type.rb'),('20160708234509_add_local_dns_records.rb'),('20160712171230_add_version_to_local_dns_blobs.rb'),('20160725090007_add_cpi_configs.rb'),('20160803151600_add_name_to_persistent_disks.rb'),('20160817135953_add_cpi_to_stemcells.rb'),('20160818112257_change_stemcell_unique_key.rb'),('20161031204534_populate_lifecycle_on_instance_spec.rb'),('20161128181900_add_logs_to_tasks.rb'),('20161209104649_add_context_id_to_tasks.rb'),('20161221151107_allow_null_instance_id_local_dns.rb'),('20170104003158_add_agent_dns_version.rb'),('20170116235940_add_errand_runs.rb'),('20170119202003_update_sha1_column_sizes.rb'),('20170203212124_add_variables.rb'),('20170216194502_remove_blobstore_id_idx_from_local_dns_blobs.rb'),('20170217000000_variables_instance_table_foreign_key_update.rb'),('20170301192646_add_deployed_successfully_to_variable_sets.rb'),('20170303175054_expand_template_json_column_lengths.rb'),('20170306215659_expand_vms_json_column_lengths.rb'),('20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records.rb'),('20170321151400_add_writable_to_variable_set.rb'),('20170328224049_associate_vm_info_with_vms_table.rb'),('20170331171657_remove_active_vm_id_from_instances.rb'),('20170405144414_add_cross_deployment_links_support_for_variables.rb'),('20170405181126_backfill_local_dns_records_and_drop_name.rb'),('20170412205032_add_agent_id_and_domain_name_to_local_dns_records.rb'),('20170427194511_add_runtime_config_name_support.rb'),('20170503205545_change_id_local_dns_to_bigint.rb'),('20170510154449_add_multi_runtime_config_support.rb'),('20170510190908_alter_ephemeral_blobs.rb'),('20170606225018_add_cpi_to_cloud_records.rb'),('20170607182149_add_task_id_to_locks.rb'),('20170612013910_add_created_at_to_vms.rb'),('20170616173221_remove_users_table.rb'),('20170616185237_migrate_spec_json_links.rb'),('20170628221611_add_canonical_az_names_and_ids.rb'),('20170705204352_add_cpi_to_disks.rb'),('20170705211620_add_templates_json_to_templates.rb'),('20170803163303_register_known_az_names.rb'),('20170804191205_add_deployment_and_errand_name_to_errand_runs.rb'),('20170815175515_change_variable_ids_to_bigint.rb'),('20170821141953_remove_unused_credentials_json_columns.rb'),('20170825141953_change_address_to_be_string_for_ipv6.rb'),('20170828174622_add_spec_json_to_templates.rb'),('20170915205722_create_dns_encoded_networks_and_instance_groups.rb'),('20171010144941_add_configs.rb'),('20171010150659_migrate_runtime_configs.rb'),('20171010161532_migrate_cloud_configs.rb'),('20171011122118_migrate_cpi_configs.rb'),('20171018102040_remove_compilation_local_dns_records.rb'),('20171030224934_convert_nil_configs_to_empty.rb');
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
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2018-03-01 22:56:44','create release','Created release \'bosh-release/0+dev.1\'','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/1','2018-03-01 22:56:43','update_release','test',NULL,'2018-03-01 22:56:43','{\"time\":1519945003,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945003,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c\",\"index\":10,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c\",\"index\":10,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5\",\"index\":13,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5\",\"index\":13,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/bade0800183844ade5a58a26ecfb4f22e4255d98\",\"index\":19,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/bade0800183844ade5a58a26ecfb4f22e4255d98\",\"index\":19,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945004,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945004,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(2,'done','2018-03-01 22:56:45','create stemcell','/stemcells/ubuntu-stemcell/1','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/2','2018-03-01 22:56:45','update_stemcell','test',NULL,'2018-03-01 22:56:45','{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945005,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n','',''),(3,'done','2018-03-01 22:56:53','create deployment','/deployments/errand_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/3','2018-03-01 22:56:46','update_deployment','test','errand_deployment','2018-03-01 22:56:46','{\"time\":1519945006,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945006,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945006,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945006,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945007,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945007,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945007,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945013,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(4,'done','2018-03-01 22:57:01','create deployment','/deployments/shared_provider_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/4','2018-03-01 22:56:54','update_deployment','test','shared_provider_deployment','2018-03-01 22:56:54','{\"time\":1519945014,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945014,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945014,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945014,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945014,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945014,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945015,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945021,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(5,'done','2018-03-01 22:57:14','create deployment','/deployments/shared_consumer_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/5','2018-03-01 22:57:02','update_deployment','test','shared_consumer_deployment','2018-03-01 22:57:02','{\"time\":1519945022,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945022,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945022,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945022,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945022,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945024,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945024,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945027,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945027,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945028,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945028,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945034,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(6,'done','2018-03-01 22:57:15','retrieve vm-stats','','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/6','2018-03-01 22:57:15','vms','test','shared_consumer_deployment','2018-03-01 22:57:15','','{\"vm_cid\":\"56627\",\"vm_created_at\":\"2018-03-01T22:57:07Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.4\"],\"dns\":[\"d0e2d58a-db06-4401-865e-0b296c356bcb.shared-consumer-ig.a.shared-consumer-deployment.bosh\",\"0.shared-consumer-ig.a.shared-consumer-deployment.bosh\"],\"agent_id\":\"49f06d46-b2c3-4b47-b220-ee42da0966ca\",\"job_name\":\"shared_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.5\",\"user\":\"6.1\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"7\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"7\"}},\"load\":[\"2.53\",\"2.22\",\"2.05\"],\"mem\":{\"kb\":\"9650544\",\"percent\":\"58\"},\"swap\":{\"kb\":\"133120\",\"percent\":\"13\"},\"uptime\":{\"secs\":289283}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"d0e2d58a-db06-4401-865e-0b296c356bcb\",\"bootstrap\":true,\"ignore\":false}\n',''),(7,'done','2018-03-01 22:57:29','create deployment','/deployments/implicit_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/7','2018-03-01 22:57:16','update_deployment','test','implicit_deployment','2018-03-01 22:57:16','{\"time\":1519945036,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945036,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945037,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945037,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945037,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945037,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945037,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945038,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945038,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945043,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945043,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945049,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(8,'done','2018-03-01 22:57:30','retrieve vm-stats','','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/8','2018-03-01 22:57:30','vms','test','implicit_deployment','2018-03-01 22:57:30','','{\"vm_cid\":\"56651\",\"vm_created_at\":\"2018-03-01T22:57:17Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.6\"],\"dns\":[\"b32620f3-ba53-49d0-855c-94dec1b0a499.implicit-consumer-ig.a.implicit-deployment.bosh\",\"0.implicit-consumer-ig.a.implicit-deployment.bosh\"],\"agent_id\":\"b310a10e-ac6b-45b2-89e5-ee20d05da312\",\"job_name\":\"implicit_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.4\",\"user\":\"3.8\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"7\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"7\"}},\"load\":[\"2.27\",\"2.17\",\"2.04\"],\"mem\":{\"kb\":\"9635508\",\"percent\":\"57\"},\"swap\":{\"kb\":\"133120\",\"percent\":\"13\"},\"uptime\":{\"secs\":289298}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"b32620f3-ba53-49d0-855c-94dec1b0a499\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"56660\",\"vm_created_at\":\"2018-03-01T22:57:17Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.5\"],\"dns\":[\"b1603934-fab7-4dd2-9ba1-518e5dd8a052.implicit-provider-ig.a.implicit-deployment.bosh\",\"0.implicit-provider-ig.a.implicit-deployment.bosh\"],\"agent_id\":\"65363fef-ef4b-45e8-a873-620c2e463eb0\",\"job_name\":\"implicit_provider_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.2\",\"user\":\"3.1\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"7\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"7\"}},\"load\":[\"2.27\",\"2.17\",\"2.04\"],\"mem\":{\"kb\":\"9635508\",\"percent\":\"57\"},\"swap\":{\"kb\":\"133120\",\"percent\":\"13\"},\"uptime\":{\"secs\":289298}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"b1603934-fab7-4dd2-9ba1-518e5dd8a052\",\"bootstrap\":true,\"ignore\":false}\n',''),(9,'done','2018-03-01 22:57:44','create deployment','/deployments/explicit_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/9','2018-03-01 22:57:31','update_deployment','test','explicit_deployment','2018-03-01 22:57:31','{\"time\":1519945051,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945052,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945052,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945052,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945052,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945052,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945052,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945053,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945053,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945058,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945058,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945064,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(10,'done','2018-03-01 22:57:46','retrieve vm-stats','','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/10','2018-03-01 22:57:46','vms','test','explicit_deployment','2018-03-01 22:57:46','','{\"vm_cid\":\"56694\",\"vm_created_at\":\"2018-03-01T22:57:32Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.7\"],\"dns\":[\"dc572fe0-2f43-431c-8cda-964d6ca6a096.explicit-provider-ig.a.explicit-deployment.bosh\",\"0.explicit-provider-ig.a.explicit-deployment.bosh\"],\"agent_id\":\"7bdd55ba-08e2-4281-afae-d120d7ce304f\",\"job_name\":\"explicit_provider_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"3.5\",\"user\":\"5.4\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"7\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"7\"}},\"load\":[\"2.27\",\"2.18\",\"2.04\"],\"mem\":{\"kb\":\"9664316\",\"percent\":\"58\"},\"swap\":{\"kb\":\"133120\",\"percent\":\"13\"},\"uptime\":{\"secs\":289314}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"dc572fe0-2f43-431c-8cda-964d6ca6a096\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"56687\",\"vm_created_at\":\"2018-03-01T22:57:32Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.8\"],\"dns\":[\"cb178871-1663-417a-bf39-c89669893301.explicit-consumer-ig.a.explicit-deployment.bosh\",\"0.explicit-consumer-ig.a.explicit-deployment.bosh\"],\"agent_id\":\"ffd382c0-98cd-46e7-ae35-0768ec1862a2\",\"job_name\":\"explicit_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"3.6\",\"user\":\"5.8\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"7\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"7\"}},\"load\":[\"2.27\",\"2.18\",\"2.04\"],\"mem\":{\"kb\":\"9664316\",\"percent\":\"58\"},\"swap\":{\"kb\":\"133120\",\"percent\":\"13\"},\"uptime\":{\"secs\":289314}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"cb178871-1663-417a-bf39-c89669893301\",\"bootstrap\":true,\"ignore\":false}\n',''),(11,'done','2018-03-01 22:57:47','create deployment','/deployments/errand_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/11','2018-03-01 22:57:47','update_deployment','test','errand_deployment','2018-03-01 22:57:47','{\"time\":1519945067,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945067,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945067,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945067,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945067,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945067,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/8ff46c92-1d1f-42a5-b9ac-fdf8d3c0985b (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(12,'done','2018-03-01 22:57:49','create deployment','/deployments/shared_provider_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/12','2018-03-01 22:57:48','update_deployment','test','shared_provider_deployment','2018-03-01 22:57:48','{\"time\":1519945068,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945068,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945068,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945068,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945068,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945069,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/a8c7075c-e072-4500-a927-a5873851bca8 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(13,'done','2018-03-01 22:57:50','create deployment','/deployments/shared_consumer_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/13','2018-03-01 22:57:50','update_deployment','test','shared_consumer_deployment','2018-03-01 22:57:50','{\"time\":1519945070,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945070,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945070,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945070,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945070,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945070,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/d0e2d58a-db06-4401-865e-0b296c356bcb (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(14,'done','2018-03-01 22:57:53','create deployment','/deployments/implicit_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/14','2018-03-01 22:57:52','update_deployment','test','implicit_deployment','2018-03-01 22:57:52','{\"time\":1519945072,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945072,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945072,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945072,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945072,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945073,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/b1603934-fab7-4dd2-9ba1-518e5dd8a052 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945073,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945073,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/b32620f3-ba53-49d0-855c-94dec1b0a499 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(15,'done','2018-03-01 22:57:55','create deployment','/deployments/explicit_deployment','/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-56342/sandbox/boshdir/tasks/15','2018-03-01 22:57:54','update_deployment','test','explicit_deployment','2018-03-01 22:57:54','{\"time\":1519945074,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945074,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945074,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945074,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945074,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945075,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/dc572fe0-2f43-431c-8cda-964d6ca6a096 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1519945075,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1519945075,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/cb178871-1663-417a-bf39-c89669893301 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','','');
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
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `templates`
--

LOCK TABLES `templates` WRITE;
/*!40000 ALTER TABLE `templates` DISABLE KEYS */;
INSERT INTO `templates` VALUES (1,'addon','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','2a7ae794-869f-441b-9788-a97deea2e6b3','af2ff6150dd898fad7980dce43b8f6bb1d4c6a1e','[]',1,NULL,'1c5442ca2a20c46a3404e89d16b47c4757b1f0ca',NULL,NULL,NULL,NULL,'{\"name\":\"addon\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"}],\"properties\":{}}'),(2,'api_server','fd80d6fe55e4dfec8edfe258e1ba03c24146954e','8acd9f35-34ec-484e-8532-795b30c9b298','e35d48cca6c797656536badd5825df0c73012345','[\"pkg_3_depends_on_2\"]',1,NULL,'fd80d6fe55e4dfec8edfe258e1ba03c24146954e',NULL,NULL,NULL,NULL,'{\"name\":\"api_server\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}],\"properties\":{}}'),(3,'api_server_with_bad_link_types','058b26819bd6561a75c2fed45ec49e671c9fbc6a','d3a68f38-2134-4546-90c5-850c71647033','65ab371432a94cf65f546fcb96aba0c80c78bc0f','[\"pkg_3_depends_on_2\"]',1,NULL,'058b26819bd6561a75c2fed45ec49e671c9fbc6a',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_bad_link_types\",\"templates\":{\"config.yml.erb\":\"config.yml\",\"somethingelse.yml.erb\":\"somethingelse.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"bad_link\"},{\"name\":\"backup_db\",\"type\":\"bad_link_2\"},{\"name\":\"some_link_name\",\"type\":\"bad_link_3\"}],\"properties\":{}}'),(4,'api_server_with_bad_optional_links','8a2485f1de3d99657e101fd269202c39cf3b5d73','9a50678a-fdfa-4bcf-bb18-444a9ce9ea06','6b023772bdcf42756f56538e6d0a8321bc2addac','[\"pkg_3_depends_on_2\"]',1,NULL,'8a2485f1de3d99657e101fd269202c39cf3b5d73',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_bad_optional_links\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}],\"properties\":{}}'),(5,'api_server_with_optional_db_link','00831c288b4a42454543ff69f71360634bd06b7b','e526610e-d4c5-4e62-9612-d0f4a616c76c','75031e64a7b3e2fe0ff4a141de37cc1a0f474fae','[\"pkg_3_depends_on_2\"]',1,NULL,'00831c288b4a42454543ff69f71360634bd06b7b',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_db_link\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\",\"optional\":true}],\"properties\":{}}'),(6,'api_server_with_optional_links_1','0efc908dd04d84858e3cf8b75c326f35af5a5a98','7cfa331b-6a6f-470b-8a3d-66d1251548e2','fd82f9e5996a8cbfd88c87e8a2396dadf2adf4b0','[\"pkg_3_depends_on_2\"]',1,NULL,'0efc908dd04d84858e3cf8b75c326f35af5a5a98',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_links_1\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"},{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}],\"properties\":{}}'),(7,'api_server_with_optional_links_2','15f815868a057180e21dbac61629f73ad3558fec','657863e1-532f-4f14-b2a1-bcf30417a2ef','d61bc80bbebefd733c8f70c92557034719529ee7','[\"pkg_3_depends_on_2\"]',1,NULL,'15f815868a057180e21dbac61629f73ad3558fec',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_links_2\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\",\"optional\":true}],\"properties\":{}}'),(8,'app_server','58e364fb74a01a1358475fc1da2ad905b78b4487','f7fdfd40-bf6b-49db-b319-c78149a7c0a0','21402338ec0e582a0ffeeaf6b53e3f4a6e3b4428','[]',1,NULL,'58e364fb74a01a1358475fc1da2ad905b78b4487',NULL,NULL,NULL,NULL,'{\"name\":\"app_server\",\"description\":null,\"templates\":{\"config.yml.erb\":\"config.yml\"},\"properties\":{}}'),(9,'backup_database','822933af7d854849051ca16539653158ad233e5e','2bebb31c-be44-4ac8-bad1-14f87b5b7db8','5fd5263ea7b7b6477f6efc531d4bf7d3e3387638','[]',1,NULL,'822933af7d854849051ca16539653158ad233e5e',NULL,NULL,NULL,NULL,'{\"name\":\"backup_database\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"backup_db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"backup_bar\"}}}'),(10,'consumer','9bed4913876cf51ae1a0ee4b561083711c19bf5c','b9526364-7998-4f4d-9923-76a87f696c81','1e04c4d781e6be211fa1d434e4de0483a3eba98c','[]',1,NULL,'9bed4913876cf51ae1a0ee4b561083711c19bf5c',NULL,NULL,NULL,NULL,'{\"name\":\"consumer\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"consumes\":[{\"name\":\"provider\",\"type\":\"provider\"}],\"properties\":{}}'),(11,'database','b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65','fc551cab-1138-4c5a-9c58-745aa4ec5640','1b36f3c3425d406bd891ca743dcad504b51c13a0','[]',1,NULL,'b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65',NULL,NULL,NULL,NULL,'{\"name\":\"database\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"normal_bar\"},\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}}'),(12,'database_with_two_provided_link_of_same_type','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','950b7246-aa21-428e-b12a-d8e8d3b95dd2','59997f8c9af89e7018e4529906339bba4bf54b90','[]',1,NULL,'7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda',NULL,NULL,NULL,NULL,'{\"name\":\"database_with_two_provided_link_of_same_type\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"db1\",\"type\":\"db\"},{\"name\":\"db2\",\"type\":\"db\"}],\"properties\":{\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}}'),(13,'errand_with_links','9a52f02643a46dda217689182e5fa3b57822ced5','572e509a-0980-4e16-b3f4-a28d7a5c4b82','9f312610e0a8468e10c1e1de55fb8c640df411fc','[]',1,NULL,'9a52f02643a46dda217689182e5fa3b57822ced5',NULL,NULL,NULL,NULL,'{\"name\":\"errand_with_links\",\"templates\":{\"config.yml.erb\":\"config.yml\",\"run.erb\":\"bin/run\"},\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}],\"properties\":{}}'),(14,'http_endpoint_provider_with_property_types','30978e9fd0d29e52fe0369262e11fbcea1283889','73c684e4-8ae8-494e-aedf-92be03bc2f80','7f68810ce6a27b61b6b1e6bc39ac2960043d2770','[]',1,NULL,'30978e9fd0d29e52fe0369262e11fbcea1283889',NULL,NULL,NULL,NULL,'{\"name\":\"http_endpoint_provider_with_property_types\",\"description\":\"This job runs an HTTP server and with a provides link directive. It has properties with types.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"Has a type password and no default value\",\"type\":\"password\"}}}'),(15,'http_proxy_with_requires','760680c4a796a2ffca24026c561c06dd5bdef6b3','360262b5-573b-4bad-b21d-56a22e35980e','7298382af2c300f06cb6fd94e941a16308cc1612','[]',1,NULL,'760680c4a796a2ffca24026c561c06dd5bdef6b3',NULL,NULL,NULL,NULL,'{\"name\":\"http_proxy_with_requires\",\"description\":\"This job runs an HTTP proxy and uses a link to find its backend.\",\"templates\":{\"ctl.sh\":\"bin/ctl\",\"config.yml.erb\":\"config/config.yml\",\"props.json\":\"config/props.json\",\"pre-start.erb\":\"bin/pre-start\"},\"consumes\":[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"},{\"name\":\"logs_http_endpoint\",\"type\":\"http_endpoint2\",\"optional\":true}],\"properties\":{\"http_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"http_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"http_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"http_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"http_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}}'),(16,'http_server_with_provides','64244f12f2db2e7d93ccfbc13be744df87013389','b498b4b2-23fa-427a-85db-be4045ceafe0','2df0460262e82610c3552bfb11d243bdca8f6d76','[]',1,NULL,'64244f12f2db2e7d93ccfbc13be744df87013389',NULL,NULL,NULL,NULL,'{\"name\":\"http_server_with_provides\",\"description\":\"This job runs an HTTP server and with a provides link directive.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}}'),(17,'kv_http_server','044ec02730e6d068ecf88a0d37fe48937687bdba','6cd38b6a-d9a3-4865-a497-766dadbff143','4eb4b289b094bc429defe34cdf949d40d139130d','[]',1,NULL,'044ec02730e6d068ecf88a0d37fe48937687bdba',NULL,NULL,NULL,NULL,'{\"name\":\"kv_http_server\",\"description\":\"This job can run as a cluster.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"consumes\":[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}],\"provides\":[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}],\"properties\":{\"kv_http_server.listen_port\":{\"description\":\"Port to listen on\",\"default\":8080}}}'),(18,'mongo_db','58529a6cd5775fa1f7ef89ab4165e0331cdb0c59','8de43ecc-605e-4b6e-a6e2-d6faf2a58544','9cfcb9218254f08c30d4c86a76f4c95309b31a86','[\"pkg_1\"]',1,NULL,'58529a6cd5775fa1f7ef89ab4165e0331cdb0c59',NULL,NULL,NULL,NULL,'{\"name\":\"mongo_db\",\"templates\":{},\"packages\":[\"pkg_1\"],\"provides\":[{\"name\":\"read_only_db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"mongo_foo_db\"}}}'),(19,'node','bade0800183844ade5a58a26ecfb4f22e4255d98','7de37033-b3cb-490f-8719-314a43cc3393','c5e616499d955ddfcba99b7f86df72d2d3501e87','[]',1,NULL,'bade0800183844ade5a58a26ecfb4f22e4255d98',NULL,NULL,NULL,NULL,'{\"name\":\"node\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[],\"provides\":[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}],\"consumes\":[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}],\"properties\":{}}'),(20,'provider','e1ff4ff9a6304e1222484570a400788c55154b1c','0b38c121-fb99-415c-b42a-e8f56bb83857','c28a176f4fc86872f9888e13873799cbfe2b7e33','[]',1,NULL,'e1ff4ff9a6304e1222484570a400788c55154b1c',NULL,NULL,NULL,NULL,'{\"name\":\"provider\",\"templates\":{},\"provides\":[{\"name\":\"provider\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}],\"properties\":{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"b\":{\"description\":\"description for b\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}}'),(21,'provider_fail','314c385e96711cb5d56dd909a086563dae61bc37','22635446-ba59-4062-9784-a22e0c5d18d3','f34d5958ab28391dfd8ce894cd2b14c8ec4d0555','[]',1,NULL,'314c385e96711cb5d56dd909a086563dae61bc37',NULL,NULL,NULL,NULL,'{\"name\":\"provider_fail\",\"templates\":{},\"provides\":[{\"name\":\"provider_fail\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}],\"properties\":{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}}'),(22,'tcp_proxy_with_requires','e60ea353cdd24b6997efdedab144431c0180645b','5c88b48b-733f-4b25-90de-faaf93206cbc','c1faf8210bdfcd08cf443fdcbb67ec4ef13a5788','[]',1,NULL,'e60ea353cdd24b6997efdedab144431c0180645b',NULL,NULL,NULL,NULL,'{\"name\":\"tcp_proxy_with_requires\",\"description\":\"This job runs an HTTP proxy and uses a link to find its backend.\",\"templates\":{\"ctl.sh\":\"bin/ctl\",\"config.yml.erb\":\"config/config.yml\",\"props.json\":\"config/props.json\",\"pre-start.erb\":\"bin/pre-start\"},\"consumes\":[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"}],\"properties\":{\"tcp_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"tcp_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"tcp_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"tcp_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"tcp_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}}'),(23,'tcp_server_with_provides','6c9ab3bde161668d1d1ea60f3611c3b19a3b3267','53e6ceb5-e105-4a59-aa82-54edd69e1cab','9634faf0ed04048658ba74293e9994362faddfde','[]',1,NULL,'6c9ab3bde161668d1d1ea60f3611c3b19a3b3267',NULL,NULL,NULL,NULL,'{\"name\":\"tcp_server_with_provides\",\"description\":\"This job runs an HTTP server and with a provides link directive.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}}');
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `variable_sets`
--

LOCK TABLES `variable_sets` WRITE;
/*!40000 ALTER TABLE `variable_sets` DISABLE KEYS */;
INSERT INTO `variable_sets` VALUES (1,1,'2018-03-01 22:56:46',1,0),(2,2,'2018-03-01 22:56:54',1,0),(3,3,'2018-03-01 22:57:02',1,0),(4,4,'2018-03-01 22:57:16',1,0),(5,5,'2018-03-01 22:57:31',1,0);
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
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8;
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

-- Dump completed on 2018-03-01 17:58:08
