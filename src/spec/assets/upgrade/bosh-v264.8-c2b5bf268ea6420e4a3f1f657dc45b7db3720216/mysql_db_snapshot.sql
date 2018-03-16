-- MySQL dump 10.13  Distrib 5.7.20, for osx10.13 (x86_64)
--
-- Host: localhost    Database: 39e9b28f92e94f81bf1807972ff135c3
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
INSERT INTO `compiled_packages` VALUES (1,'d541cbd9-08f8-453d-59b0-76d3ea6e7936','413a7160b480de255f8de0376976bc90540c88a5','[]',1,2,'97d170e1550eee4afc0af065b78cda302a97674c','toronto-os','1'),(2,'4d513182-d721-44d6-6266-eed77a9b2fda','d06dfad9d7686e516c42ea07b23b40c58f77b8ba','[[\"pkg_2\",\"fa48497a19f12e925b32fcb8f5ca2b42144e4444\"]]',1,3,'b048798b462817f4ae6a5345dd9a0c45d1a1c8ea','toronto-os','1');
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
INSERT INTO `configs` VALUES (1,'default','cloud','azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n- name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nvm_types:\n- cloud_properties: {}\n  name: a\n','2018-03-16 15:52:25',0);
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
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8;
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'errand_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  name: errand_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(2,'shared_provider_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_provider_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{\"shared_provider_ig\":{\"database\":{\"my_shared_db\":{\"db\":{\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"default_network\":\"a\",\"networks\":[\"a\"],\"instance_group\":\"shared_provider_ig\",\"properties\":{\"foo\":\"normal_bar\"},\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\",\"addresses\":{\"a\":\"192.168.1.3\"},\"dns_addresses\":{\"a\":\"192.168.1.3\"}}]}}}}}'),(3,'shared_consumer_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_consumer_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(4,'implicit_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n  name: implicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: api_server\n  name: implicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: implicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(5,'explicit_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: explicit_db\n  name: explicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        from: explicit_db\n      db:\n        from: explicit_db\n    name: api_server\n  name: explicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: explicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(6,'colocated_errand_deployment','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  - name: errand_with_links\n  name: errand_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: colocated_errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{}'),(7,'shared_deployment_with_errand','---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_deployment_with_errand\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: \'1\'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n','{\"shared_provider_ig\":{\"database\":{\"my_shared_db\":{\"db\":{\"deployment_name\":\"shared_deployment_with_errand\",\"domain\":\"bosh\",\"default_network\":\"a\",\"networks\":[\"a\"],\"instance_group\":\"shared_provider_ig\",\"properties\":{\"foo\":\"normal_bar\"},\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"cb37a197-919b-423b-93e7-414338e93b55\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.14\",\"addresses\":{\"a\":\"192.168.1.14\"},\"dns_addresses\":{\"a\":\"192.168.1.14\"}}]}}}}}');
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
INSERT INTO `deployments_configs` VALUES (1,1),(2,1),(3,1),(4,1),(5,1),(6,1),(7,1);
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_release_versions`
--

LOCK TABLES `deployments_release_versions` WRITE;
/*!40000 ALTER TABLE `deployments_release_versions` DISABLE KEYS */;
INSERT INTO `deployments_release_versions` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5),(6,1,6),(7,1,7);
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments_stemcells`
--

LOCK TABLES `deployments_stemcells` WRITE;
/*!40000 ALTER TABLE `deployments_stemcells` DISABLE KEYS */;
INSERT INTO `deployments_stemcells` VALUES (1,1,1),(2,2,1),(3,3,1),(4,4,1),(5,5,1),(6,6,1),(7,7,1);
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
) ENGINE=InnoDB AUTO_INCREMENT=192 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,NULL,'_director','2018-03-16 15:52:22','start','worker','worker_0',NULL,NULL,NULL,NULL,'{}'),(2,NULL,'_director','2018-03-16 15:52:22','start','director','deadbeef',NULL,NULL,NULL,NULL,'{\"version\":\"0.0.0\"}'),(3,NULL,'_director','2018-03-16 15:52:22','start','worker','worker_1',NULL,NULL,NULL,NULL,'{}'),(4,NULL,'_director','2018-03-16 15:52:22','start','worker','worker_2',NULL,NULL,NULL,NULL,'{}'),(5,NULL,'test','2018-03-16 15:52:23','acquire','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(6,NULL,'test','2018-03-16 15:52:24','release','lock','lock:release:bosh-release',NULL,'1',NULL,NULL,'{}'),(7,NULL,'test','2018-03-16 15:52:25','update','cloud-config','default',NULL,NULL,NULL,NULL,'{}'),(8,NULL,'test','2018-03-16 15:52:26','create','deployment','errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(9,NULL,'test','2018-03-16 15:52:26','acquire','lock','lock:deployment:errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(10,NULL,'test','2018-03-16 15:52:26','acquire','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(11,NULL,'test','2018-03-16 15:52:26','release','lock','lock:release:bosh-release',NULL,'3',NULL,NULL,'{}'),(12,NULL,'test','2018-03-16 15:52:26','create','vm',NULL,NULL,'3','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(13,12,'test','2018-03-16 15:52:27','create','vm','43505',NULL,'3','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(14,NULL,'test','2018-03-16 15:52:28','create','instance','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce',NULL,'3','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{\"az\":\"z1\"}'),(15,14,'test','2018-03-16 15:52:34','create','instance','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce',NULL,'3','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(16,8,'test','2018-03-16 15:52:34','create','deployment','errand_deployment',NULL,'3','errand_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(17,NULL,'test','2018-03-16 15:52:34','release','lock','lock:deployment:errand_deployment',NULL,'3','errand_deployment',NULL,'{}'),(18,NULL,'test','2018-03-16 15:52:35','create','deployment','shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(19,NULL,'test','2018-03-16 15:52:35','acquire','lock','lock:deployment:shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(20,NULL,'test','2018-03-16 15:52:35','acquire','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(21,NULL,'test','2018-03-16 15:52:35','release','lock','lock:release:bosh-release',NULL,'4',NULL,NULL,'{}'),(22,NULL,'test','2018-03-16 15:52:35','create','vm',NULL,NULL,'4','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(23,22,'test','2018-03-16 15:52:36','create','vm','43526',NULL,'4','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(24,NULL,'test','2018-03-16 15:52:36','create','instance','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34',NULL,'4','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{\"az\":\"z1\"}'),(25,24,'test','2018-03-16 15:52:42','create','instance','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34',NULL,'4','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(26,18,'test','2018-03-16 15:52:42','create','deployment','shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(27,NULL,'test','2018-03-16 15:52:42','release','lock','lock:deployment:shared_provider_deployment',NULL,'4','shared_provider_deployment',NULL,'{}'),(28,NULL,'test','2018-03-16 15:52:43','create','deployment','shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(29,NULL,'test','2018-03-16 15:52:43','acquire','lock','lock:deployment:shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(30,NULL,'test','2018-03-16 15:52:43','acquire','lock','lock:release:bosh-release',NULL,'5',NULL,NULL,'{}'),(31,NULL,'test','2018-03-16 15:52:43','release','lock','lock:release:bosh-release',NULL,'5',NULL,NULL,'{}'),(32,NULL,'test','2018-03-16 15:52:44','acquire','lock','lock:compile:2:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(33,NULL,'test','2018-03-16 15:52:44','create','instance','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(34,NULL,'test','2018-03-16 15:52:44','create','vm',NULL,NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(35,34,'test','2018-03-16 15:52:44','create','vm','43545',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(36,33,'test','2018-03-16 15:52:45','create','instance','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(37,NULL,'test','2018-03-16 15:52:46','delete','instance','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(38,NULL,'test','2018-03-16 15:52:46','delete','vm','43545',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(39,38,'test','2018-03-16 15:52:47','delete','vm','43545',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(40,37,'test','2018-03-16 15:52:47','delete','instance','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f',NULL,'5','shared_consumer_deployment','compilation-ae2c2418-8a7c-4483-a805-3b443f45dc40/67880454-b564-4bfc-a3e2-f77dfc58566f','{}'),(41,NULL,'test','2018-03-16 15:52:47','release','lock','lock:compile:2:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(42,NULL,'test','2018-03-16 15:52:47','acquire','lock','lock:compile:3:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(43,NULL,'test','2018-03-16 15:52:47','create','instance','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(44,NULL,'test','2018-03-16 15:52:47','create','vm',NULL,NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(45,44,'test','2018-03-16 15:52:47','create','vm','43563',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(46,43,'test','2018-03-16 15:52:49','create','instance','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(47,NULL,'test','2018-03-16 15:52:50','delete','instance','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(48,NULL,'test','2018-03-16 15:52:50','delete','vm','43563',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(49,48,'test','2018-03-16 15:52:50','delete','vm','43563',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(50,47,'test','2018-03-16 15:52:50','delete','instance','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0',NULL,'5','shared_consumer_deployment','compilation-34f25d99-4c3d-49d4-a9a0-92d5f46c028f/25f96a5d-58cc-41e8-b343-bc1366b679e0','{}'),(51,NULL,'test','2018-03-16 15:52:50','release','lock','lock:compile:3:toronto-os/1',NULL,'5','shared_consumer_deployment',NULL,'{}'),(52,NULL,'test','2018-03-16 15:52:50','create','vm',NULL,NULL,'5','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(53,52,'test','2018-03-16 15:52:50','create','vm','43581',NULL,'5','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(54,NULL,'test','2018-03-16 15:52:51','create','instance','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0',NULL,'5','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{\"az\":\"z1\"}'),(55,54,'test','2018-03-16 15:52:58','create','instance','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0',NULL,'5','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(56,28,'test','2018-03-16 15:52:58','create','deployment','shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(57,NULL,'test','2018-03-16 15:52:58','release','lock','lock:deployment:shared_consumer_deployment',NULL,'5','shared_consumer_deployment',NULL,'{}'),(58,NULL,'test','2018-03-16 15:52:59','create','deployment','implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(59,NULL,'test','2018-03-16 15:52:59','acquire','lock','lock:deployment:implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(60,NULL,'test','2018-03-16 15:52:59','acquire','lock','lock:release:bosh-release',NULL,'7',NULL,NULL,'{}'),(61,NULL,'test','2018-03-16 15:52:59','release','lock','lock:release:bosh-release',NULL,'7',NULL,NULL,'{}'),(62,NULL,'test','2018-03-16 15:52:59','create','vm',NULL,NULL,'7','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(63,NULL,'test','2018-03-16 15:52:59','create','vm',NULL,NULL,'7','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(64,62,'test','2018-03-16 15:52:59','create','vm','43611',NULL,'7','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(65,63,'test','2018-03-16 15:53:00','create','vm','43615',NULL,'7','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(66,NULL,'test','2018-03-16 15:53:01','create','instance','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969',NULL,'7','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{\"az\":\"z1\"}'),(67,66,'test','2018-03-16 15:53:07','create','instance','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969',NULL,'7','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(68,NULL,'test','2018-03-16 15:53:07','create','instance','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5',NULL,'7','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{\"az\":\"z1\"}'),(69,68,'test','2018-03-16 15:53:13','create','instance','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5',NULL,'7','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(70,58,'test','2018-03-16 15:53:13','create','deployment','implicit_deployment',NULL,'7','implicit_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(71,NULL,'test','2018-03-16 15:53:13','release','lock','lock:deployment:implicit_deployment',NULL,'7','implicit_deployment',NULL,'{}'),(72,NULL,'test','2018-03-16 15:53:15','create','deployment','explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(73,NULL,'test','2018-03-16 15:53:15','acquire','lock','lock:deployment:explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(74,NULL,'test','2018-03-16 15:53:15','acquire','lock','lock:release:bosh-release',NULL,'9',NULL,NULL,'{}'),(75,NULL,'test','2018-03-16 15:53:15','release','lock','lock:release:bosh-release',NULL,'9',NULL,NULL,'{}'),(76,NULL,'test','2018-03-16 15:53:15','create','vm',NULL,NULL,'9','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(77,NULL,'test','2018-03-16 15:53:15','create','vm',NULL,NULL,'9','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(78,77,'test','2018-03-16 15:53:15','create','vm','43648',NULL,'9','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(79,76,'test','2018-03-16 15:53:16','create','vm','43658',NULL,'9','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(80,NULL,'test','2018-03-16 15:53:17','create','instance','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0',NULL,'9','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{\"az\":\"z1\"}'),(81,80,'test','2018-03-16 15:53:24','create','instance','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0',NULL,'9','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(82,NULL,'test','2018-03-16 15:53:24','create','instance','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09',NULL,'9','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{\"az\":\"z1\"}'),(83,82,'test','2018-03-16 15:53:31','create','instance','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09',NULL,'9','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(84,72,'test','2018-03-16 15:53:31','create','deployment','explicit_deployment',NULL,'9','explicit_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(85,NULL,'test','2018-03-16 15:53:31','release','lock','lock:deployment:explicit_deployment',NULL,'9','explicit_deployment',NULL,'{}'),(86,NULL,'test','2018-03-16 15:53:33','create','deployment','colocated_errand_deployment',NULL,'11','colocated_errand_deployment',NULL,'{}'),(87,NULL,'test','2018-03-16 15:53:33','acquire','lock','lock:deployment:colocated_errand_deployment',NULL,'11','colocated_errand_deployment',NULL,'{}'),(88,NULL,'test','2018-03-16 15:53:34','acquire','lock','lock:release:bosh-release',NULL,'11',NULL,NULL,'{}'),(89,NULL,'test','2018-03-16 15:53:34','release','lock','lock:release:bosh-release',NULL,'11',NULL,NULL,'{}'),(90,NULL,'test','2018-03-16 15:53:34','create','vm',NULL,NULL,'11','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(91,90,'test','2018-03-16 15:53:34','create','vm','43690',NULL,'11','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(92,NULL,'test','2018-03-16 15:53:35','create','instance','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a',NULL,'11','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{\"az\":\"z1\"}'),(93,92,'test','2018-03-16 15:53:42','create','instance','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a',NULL,'11','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(94,86,'test','2018-03-16 15:53:42','create','deployment','colocated_errand_deployment',NULL,'11','colocated_errand_deployment',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(95,NULL,'test','2018-03-16 15:53:42','release','lock','lock:deployment:colocated_errand_deployment',NULL,'11','colocated_errand_deployment',NULL,'{}'),(96,NULL,'test','2018-03-16 15:53:44','create','deployment','shared_deployment_with_errand',NULL,'13','shared_deployment_with_errand',NULL,'{}'),(97,NULL,'test','2018-03-16 15:53:44','acquire','lock','lock:deployment:shared_deployment_with_errand',NULL,'13','shared_deployment_with_errand',NULL,'{}'),(98,NULL,'test','2018-03-16 15:53:44','acquire','lock','lock:release:bosh-release',NULL,'13',NULL,NULL,'{}'),(99,NULL,'test','2018-03-16 15:53:44','release','lock','lock:release:bosh-release',NULL,'13',NULL,NULL,'{}'),(100,NULL,'test','2018-03-16 15:53:44','create','vm',NULL,NULL,'13','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(101,NULL,'test','2018-03-16 15:53:44','create','vm',NULL,NULL,'13','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(102,101,'test','2018-03-16 15:53:44','create','vm','43720',NULL,'13','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(103,100,'test','2018-03-16 15:53:45','create','vm','43727',NULL,'13','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(104,NULL,'test','2018-03-16 15:53:46','create','instance','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55',NULL,'13','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{\"az\":\"z1\"}'),(105,104,'test','2018-03-16 15:53:52','create','instance','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55',NULL,'13','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(106,NULL,'test','2018-03-16 15:53:52','create','instance','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a',NULL,'13','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{\"az\":\"z1\"}'),(107,106,'test','2018-03-16 15:53:58','create','instance','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a',NULL,'13','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(108,96,'test','2018-03-16 15:53:58','create','deployment','shared_deployment_with_errand',NULL,'13','shared_deployment_with_errand',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(109,NULL,'test','2018-03-16 15:53:58','release','lock','lock:deployment:shared_deployment_with_errand',NULL,'13','shared_deployment_with_errand',NULL,'{}'),(110,NULL,'test','2018-03-16 15:53:59','update','deployment','errand_deployment',NULL,'15','errand_deployment',NULL,'{}'),(111,NULL,'test','2018-03-16 15:53:59','acquire','lock','lock:deployment:errand_deployment',NULL,'15','errand_deployment',NULL,'{}'),(112,NULL,'test','2018-03-16 15:53:59','acquire','lock','lock:release:bosh-release',NULL,'15',NULL,NULL,'{}'),(113,NULL,'test','2018-03-16 15:53:59','release','lock','lock:release:bosh-release',NULL,'15',NULL,NULL,'{}'),(114,NULL,'test','2018-03-16 15:53:59','stop','instance','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce',NULL,'15','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(115,NULL,'test','2018-03-16 15:54:00','delete','vm','43505',NULL,'15','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(116,115,'test','2018-03-16 15:54:00','delete','vm','43505',NULL,'15','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(117,114,'test','2018-03-16 15:54:00','stop','instance','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce',NULL,'15','errand_deployment','errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','{}'),(118,110,'test','2018-03-16 15:54:00','update','deployment','errand_deployment',NULL,'15','errand_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(119,NULL,'test','2018-03-16 15:54:00','release','lock','lock:deployment:errand_deployment',NULL,'15','errand_deployment',NULL,'{}'),(120,NULL,'test','2018-03-16 15:54:00','update','deployment','shared_provider_deployment',NULL,'16','shared_provider_deployment',NULL,'{}'),(121,NULL,'test','2018-03-16 15:54:01','acquire','lock','lock:deployment:shared_provider_deployment',NULL,'16','shared_provider_deployment',NULL,'{}'),(122,NULL,'test','2018-03-16 15:54:01','acquire','lock','lock:release:bosh-release',NULL,'16',NULL,NULL,'{}'),(123,NULL,'test','2018-03-16 15:54:01','release','lock','lock:release:bosh-release',NULL,'16',NULL,NULL,'{}'),(124,NULL,'test','2018-03-16 15:54:01','stop','instance','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34',NULL,'16','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(125,NULL,'test','2018-03-16 15:54:01','delete','vm','43526',NULL,'16','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(126,125,'test','2018-03-16 15:54:01','delete','vm','43526',NULL,'16','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(127,124,'test','2018-03-16 15:54:01','stop','instance','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34',NULL,'16','shared_provider_deployment','shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34','{}'),(128,120,'test','2018-03-16 15:54:01','update','deployment','shared_provider_deployment',NULL,'16','shared_provider_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(129,NULL,'test','2018-03-16 15:54:01','release','lock','lock:deployment:shared_provider_deployment',NULL,'16','shared_provider_deployment',NULL,'{}'),(130,NULL,'test','2018-03-16 15:54:02','update','deployment','shared_consumer_deployment',NULL,'17','shared_consumer_deployment',NULL,'{}'),(131,NULL,'test','2018-03-16 15:54:02','acquire','lock','lock:deployment:shared_consumer_deployment',NULL,'17','shared_consumer_deployment',NULL,'{}'),(132,NULL,'test','2018-03-16 15:54:02','acquire','lock','lock:release:bosh-release',NULL,'17',NULL,NULL,'{}'),(133,NULL,'test','2018-03-16 15:54:02','release','lock','lock:release:bosh-release',NULL,'17',NULL,NULL,'{}'),(134,NULL,'test','2018-03-16 15:54:02','stop','instance','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0',NULL,'17','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(135,NULL,'test','2018-03-16 15:54:02','delete','vm','43581',NULL,'17','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(136,135,'test','2018-03-16 15:54:02','delete','vm','43581',NULL,'17','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(137,134,'test','2018-03-16 15:54:03','stop','instance','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0',NULL,'17','shared_consumer_deployment','shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0','{}'),(138,130,'test','2018-03-16 15:54:03','update','deployment','shared_consumer_deployment',NULL,'17','shared_consumer_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(139,NULL,'test','2018-03-16 15:54:03','release','lock','lock:deployment:shared_consumer_deployment',NULL,'17','shared_consumer_deployment',NULL,'{}'),(140,NULL,'test','2018-03-16 15:54:03','update','deployment','implicit_deployment',NULL,'18','implicit_deployment',NULL,'{}'),(141,NULL,'test','2018-03-16 15:54:03','acquire','lock','lock:deployment:implicit_deployment',NULL,'18','implicit_deployment',NULL,'{}'),(142,NULL,'test','2018-03-16 15:54:03','acquire','lock','lock:release:bosh-release',NULL,'18',NULL,NULL,'{}'),(143,NULL,'test','2018-03-16 15:54:03','release','lock','lock:release:bosh-release',NULL,'18',NULL,NULL,'{}'),(144,NULL,'test','2018-03-16 15:54:04','stop','instance','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969',NULL,'18','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(145,NULL,'test','2018-03-16 15:54:04','delete','vm','43611',NULL,'18','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(146,145,'test','2018-03-16 15:54:04','delete','vm','43611',NULL,'18','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(147,144,'test','2018-03-16 15:54:04','stop','instance','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969',NULL,'18','implicit_deployment','implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969','{}'),(148,NULL,'test','2018-03-16 15:54:04','stop','instance','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5',NULL,'18','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(149,NULL,'test','2018-03-16 15:54:04','delete','vm','43615',NULL,'18','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(150,149,'test','2018-03-16 15:54:04','delete','vm','43615',NULL,'18','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(151,148,'test','2018-03-16 15:54:04','stop','instance','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5',NULL,'18','implicit_deployment','implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5','{}'),(152,140,'test','2018-03-16 15:54:04','update','deployment','implicit_deployment',NULL,'18','implicit_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(153,NULL,'test','2018-03-16 15:54:04','release','lock','lock:deployment:implicit_deployment',NULL,'18','implicit_deployment',NULL,'{}'),(154,NULL,'test','2018-03-16 15:54:05','update','deployment','explicit_deployment',NULL,'19','explicit_deployment',NULL,'{}'),(155,NULL,'test','2018-03-16 15:54:05','acquire','lock','lock:deployment:explicit_deployment',NULL,'19','explicit_deployment',NULL,'{}'),(156,NULL,'test','2018-03-16 15:54:05','acquire','lock','lock:release:bosh-release',NULL,'19',NULL,NULL,'{}'),(157,NULL,'test','2018-03-16 15:54:05','release','lock','lock:release:bosh-release',NULL,'19',NULL,NULL,'{}'),(158,NULL,'test','2018-03-16 15:54:05','stop','instance','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0',NULL,'19','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(159,NULL,'test','2018-03-16 15:54:05','delete','vm','43648',NULL,'19','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(160,159,'test','2018-03-16 15:54:05','delete','vm','43648',NULL,'19','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(161,158,'test','2018-03-16 15:54:05','stop','instance','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0',NULL,'19','explicit_deployment','explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0','{}'),(162,NULL,'test','2018-03-16 15:54:05','stop','instance','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09',NULL,'19','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(163,NULL,'test','2018-03-16 15:54:05','delete','vm','43658',NULL,'19','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(164,163,'test','2018-03-16 15:54:06','delete','vm','43658',NULL,'19','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(165,162,'test','2018-03-16 15:54:06','stop','instance','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09',NULL,'19','explicit_deployment','explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09','{}'),(166,154,'test','2018-03-16 15:54:06','update','deployment','explicit_deployment',NULL,'19','explicit_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(167,NULL,'test','2018-03-16 15:54:06','release','lock','lock:deployment:explicit_deployment',NULL,'19','explicit_deployment',NULL,'{}'),(168,NULL,'test','2018-03-16 15:54:06','update','deployment','colocated_errand_deployment',NULL,'20','colocated_errand_deployment',NULL,'{}'),(169,NULL,'test','2018-03-16 15:54:06','acquire','lock','lock:deployment:colocated_errand_deployment',NULL,'20','colocated_errand_deployment',NULL,'{}'),(170,NULL,'test','2018-03-16 15:54:06','acquire','lock','lock:release:bosh-release',NULL,'20',NULL,NULL,'{}'),(171,NULL,'test','2018-03-16 15:54:06','release','lock','lock:release:bosh-release',NULL,'20',NULL,NULL,'{}'),(172,NULL,'test','2018-03-16 15:54:07','stop','instance','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a',NULL,'20','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(173,NULL,'test','2018-03-16 15:54:07','delete','vm','43690',NULL,'20','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(174,173,'test','2018-03-16 15:54:07','delete','vm','43690',NULL,'20','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(175,172,'test','2018-03-16 15:54:07','stop','instance','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a',NULL,'20','colocated_errand_deployment','errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a','{}'),(176,168,'test','2018-03-16 15:54:07','update','deployment','colocated_errand_deployment',NULL,'20','colocated_errand_deployment',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(177,NULL,'test','2018-03-16 15:54:07','release','lock','lock:deployment:colocated_errand_deployment',NULL,'20','colocated_errand_deployment',NULL,'{}'),(178,NULL,'test','2018-03-16 15:54:08','update','deployment','shared_deployment_with_errand',NULL,'21','shared_deployment_with_errand',NULL,'{}'),(179,NULL,'test','2018-03-16 15:54:08','acquire','lock','lock:deployment:shared_deployment_with_errand',NULL,'21','shared_deployment_with_errand',NULL,'{}'),(180,NULL,'test','2018-03-16 15:54:08','acquire','lock','lock:release:bosh-release',NULL,'21',NULL,NULL,'{}'),(181,NULL,'test','2018-03-16 15:54:08','release','lock','lock:release:bosh-release',NULL,'21',NULL,NULL,'{}'),(182,NULL,'test','2018-03-16 15:54:08','stop','instance','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55',NULL,'21','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(183,NULL,'test','2018-03-16 15:54:08','delete','vm','43727',NULL,'21','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(184,183,'test','2018-03-16 15:54:09','delete','vm','43727',NULL,'21','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(185,182,'test','2018-03-16 15:54:09','stop','instance','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55',NULL,'21','shared_deployment_with_errand','shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55','{}'),(186,NULL,'test','2018-03-16 15:54:09','stop','instance','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a',NULL,'21','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(187,NULL,'test','2018-03-16 15:54:09','delete','vm','43720',NULL,'21','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(188,187,'test','2018-03-16 15:54:09','delete','vm','43720',NULL,'21','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(189,186,'test','2018-03-16 15:54:09','stop','instance','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a',NULL,'21','shared_deployment_with_errand','shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a','{}'),(190,178,'test','2018-03-16 15:54:09','update','deployment','shared_deployment_with_errand',NULL,'21','shared_deployment_with_errand',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(191,NULL,'test','2018-03-16 15:54:09','release','lock','lock:deployment:shared_deployment_with_errand',NULL,'21','shared_deployment_with_errand',NULL,'{}');
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'errand_provider_ig',0,1,'detached',0,'7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce','z1','{}',0,1,'[\"0.errand-provider-ig.a.errand-deployment.bosh\",\"7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce.errand-provider-ig.a.errand-deployment.bosh\"]','{\"deployment\":\"errand_deployment\",\"job\":{\"name\":\"errand_provider_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"errand_provider_ig\",\"id\":\"7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"596fb6d6-273a-4d8b-8a3f-9ac711c17e2e\",\"sha1\":\"388390ee77deb76b7543c210a18f15ebe3e0f26f\"},\"configuration_hash\":\"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,1),(2,'errand_consumer_ig',0,1,'started',0,'301b6862-d9a6-4aae-873d-bf16b9852274','z1',NULL,0,1,'[]',NULL,NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',0,0,1),(3,'shared_provider_ig',0,2,'detached',0,'bf93f912-ac25-425b-b5b2-e93525e6fe34','z1','{}',0,1,'[\"0.shared-provider-ig.a.shared-provider-deployment.bosh\",\"bf93f912-ac25-425b-b5b2-e93525e6fe34.shared-provider-ig.a.shared-provider-deployment.bosh\"]','{\"deployment\":\"shared_provider_deployment\",\"job\":{\"name\":\"shared_provider_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.3\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.3\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"6d0e7897-4bdd-43ec-80c8-a75467eed57c\",\"sha1\":\"3b2b6f64012898398cf2ce0530be1a7731e95852\"},\"configuration_hash\":\"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,2),(4,'shared_consumer_ig',0,3,'detached',0,'63452a70-c669-4371-a162-38010d4afae0','z1','{}',0,1,'[\"0.shared-consumer-ig.a.shared-consumer-deployment.bosh\",\"63452a70-c669-4371-a162-38010d4afae0.shared-consumer-ig.a.shared-consumer-deployment.bosh\"]','{\"deployment\":\"shared_consumer_deployment\",\"job\":{\"name\":\"shared_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_consumer_ig\",\"id\":\"63452a70-c669-4371-a162-38010d4afae0\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.4\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"d06dfad9d7686e516c42ea07b23b40c58f77b8ba\",\"blobstore_id\":\"4d513182-d721-44d6-6266-eed77a9b2fda\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}}}},\"address\":\"192.168.1.4\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"cf13605f67e2c568dfa15d330aa577c450a5b321\"},\"rendered_templates_archive\":{\"blobstore_id\":\"0e7a2246-ccad-4a9c-b78a-4738fdab52d6\",\"sha1\":\"70ce257f7b6bc1366d972c7230303337345f0845\"},\"configuration_hash\":\"6795db67786f368aae62ba170dcc8ec22ca6c6aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,3),(7,'implicit_provider_ig',0,4,'detached',0,'d5a5af8e-cf13-456a-b188-21f0966f8969','z1','{}',0,1,'[\"0.implicit-provider-ig.a.implicit-deployment.bosh\",\"d5a5af8e-cf13-456a-b188-21f0966f8969.implicit-provider-ig.a.implicit-deployment.bosh\"]','{\"deployment\":\"implicit_deployment\",\"job\":{\"name\":\"implicit_provider_ig\",\"templates\":[{\"name\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"e5bb9472cf6407b22181196c47e4195fa1a9a8d5\",\"blobstore_id\":\"a008d190-912e-4319-ac18-69ac51a6a51c\",\"logs\":[]}],\"template\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"e5bb9472cf6407b22181196c47e4195fa1a9a8d5\",\"blobstore_id\":\"a008d190-912e-4319-ac18-69ac51a6a51c\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"implicit_provider_ig\",\"id\":\"d5a5af8e-cf13-456a-b188-21f0966f8969\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.5\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"backup_database\":{\"foo\":\"backup_bar\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.5\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"backup_database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"3686e16e-e606-463e-afa4-d47e1e414888\",\"sha1\":\"527db2dcd0445528e63e22e4961f2693f73523b1\"},\"configuration_hash\":\"4e4c9c0b7e76b5bc955b215edbd839e427d581aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,4),(8,'implicit_consumer_ig',0,4,'detached',0,'4fc10508-5f4e-4083-8f88-8dbbb73171d5','z1','{}',0,1,'[\"0.implicit-consumer-ig.a.implicit-deployment.bosh\",\"4fc10508-5f4e-4083-8f88-8dbbb73171d5.implicit-consumer-ig.a.implicit-deployment.bosh\"]','{\"deployment\":\"implicit_deployment\",\"job\":{\"name\":\"implicit_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"implicit_consumer_ig\",\"id\":\"4fc10508-5f4e-4083-8f88-8dbbb73171d5\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.6\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"d06dfad9d7686e516c42ea07b23b40c58f77b8ba\",\"blobstore_id\":\"4d513182-d721-44d6-6266-eed77a9b2fda\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"implicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"implicit_provider_ig\",\"instances\":[{\"name\":\"implicit_provider_ig\",\"id\":\"d5a5af8e-cf13-456a-b188-21f0966f8969\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.5\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"implicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"implicit_provider_ig\",\"instances\":[{\"name\":\"implicit_provider_ig\",\"id\":\"d5a5af8e-cf13-456a-b188-21f0966f8969\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.5\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}}}},\"address\":\"192.168.1.6\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"890a76d266eaea60ad6fd588a1ea3701d17c432f\"},\"rendered_templates_archive\":{\"blobstore_id\":\"0565d217-8a6b-4705-889c-f8f483383e78\",\"sha1\":\"53c4a43d9c642f61c6413ae21c1f484172a38ec5\"},\"configuration_hash\":\"e3416449728d72a9fed98f7d89d801ca8a259242\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,4),(9,'explicit_provider_ig',0,5,'detached',0,'320261ef-3c59-4f3d-95e9-eabac1fc7ae0','z1','{}',0,1,'[\"0.explicit-provider-ig.a.explicit-deployment.bosh\",\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0.explicit-provider-ig.a.explicit-deployment.bosh\"]','{\"deployment\":\"explicit_deployment\",\"job\":{\"name\":\"explicit_provider_ig\",\"templates\":[{\"name\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"e5bb9472cf6407b22181196c47e4195fa1a9a8d5\",\"blobstore_id\":\"a008d190-912e-4319-ac18-69ac51a6a51c\",\"logs\":[]}],\"template\":\"backup_database\",\"version\":\"822933af7d854849051ca16539653158ad233e5e\",\"sha1\":\"e5bb9472cf6407b22181196c47e4195fa1a9a8d5\",\"blobstore_id\":\"a008d190-912e-4319-ac18-69ac51a6a51c\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"explicit_provider_ig\",\"id\":\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.7\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"backup_database\":{\"foo\":\"backup_bar\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.7\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"backup_database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"1f5a8319-0f00-4c3a-bc48-11fc1676309e\",\"sha1\":\"afa0a618c83a28b89a1ca5570710dbf3e56e815c\"},\"configuration_hash\":\"4e4c9c0b7e76b5bc955b215edbd839e427d581aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,5),(10,'explicit_consumer_ig',0,5,'detached',0,'1acbacd8-1ce8-40ec-a062-dbc75aac5d09','z1','{}',0,1,'[\"0.explicit-consumer-ig.a.explicit-deployment.bosh\",\"1acbacd8-1ce8-40ec-a062-dbc75aac5d09.explicit-consumer-ig.a.explicit-deployment.bosh\"]','{\"deployment\":\"explicit_deployment\",\"job\":{\"name\":\"explicit_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"explicit_consumer_ig\",\"id\":\"1acbacd8-1ce8-40ec-a062-dbc75aac5d09\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.8\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"d06dfad9d7686e516c42ea07b23b40c58f77b8ba\",\"blobstore_id\":\"4d513182-d721-44d6-6266-eed77a9b2fda\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"explicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"explicit_provider_ig\",\"instances\":[{\"name\":\"explicit_provider_ig\",\"id\":\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.7\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"explicit_deployment\",\"domain\":\"bosh\",\"instance_group\":\"explicit_provider_ig\",\"instances\":[{\"name\":\"explicit_provider_ig\",\"id\":\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.7\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"backup_bar\"}}}},\"address\":\"192.168.1.8\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"feafecda704ba0fd3d3fe0768b7e825c9f48cf58\"},\"rendered_templates_archive\":{\"blobstore_id\":\"9976d90f-ee2e-4a00-ae5b-5f437dc108df\",\"sha1\":\"e929cba63bf946d41bbcaa7c17f3eb74b689260b\"},\"configuration_hash\":\"57ed863958fdaeb9d5cf40022b3c088bc71c627e\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,5),(11,'errand_ig',0,6,'detached',0,'ac6a4e3d-f86f-44a4-b498-bcecabc4578a','z1','{}',0,1,'[\"0.errand-ig.a.colocated-errand-deployment.bosh\",\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a.errand-ig.a.colocated-errand-deployment.bosh\"]','{\"deployment\":\"colocated_errand_deployment\",\"job\":{\"name\":\"errand_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]},{\"name\":\"errand_with_links\",\"version\":\"9a52f02643a46dda217689182e5fa3b57822ced5\",\"sha1\":\"4bebb80ff95c5a4e985df3cb603113b094eed586\",\"blobstore_id\":\"c4827c65-8a3a-4282-af0b-e4d722653a8a\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"errand_ig\",\"id\":\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.9\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"},\"errand_with_links\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"errand_with_links\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"colocated_errand_deployment\",\"domain\":\"bosh\",\"instance_group\":\"errand_ig\",\"instances\":[{\"name\":\"errand_ig\",\"id\":\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.9\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"colocated_errand_deployment\",\"domain\":\"bosh\",\"instance_group\":\"errand_ig\",\"instances\":[{\"name\":\"errand_ig\",\"id\":\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.9\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}}}},\"address\":\"192.168.1.9\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\",\"errand_with_links\":\"a67c652623d62e63527df3cdb380033cca00628f\"},\"rendered_templates_archive\":{\"blobstore_id\":\"5416fa42-3d3f-4285-86fd-f40094f0f8c3\",\"sha1\":\"7f5fd98abfe0b3c2d9257d9aa22a922baaf64312\"},\"configuration_hash\":\"59192a7a26c0bc1a6bd8015205e0b64a31b66a74\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,6),(12,'shared_provider_ig',0,7,'detached',0,'cb37a197-919b-423b-93e7-414338e93b55','z1','{}',0,1,'[\"0.shared-provider-ig.a.shared-deployment-with-errand.bosh\",\"cb37a197-919b-423b-93e7-414338e93b55.shared-provider-ig.a.shared-deployment-with-errand.bosh\"]','{\"deployment\":\"shared_deployment_with_errand\",\"job\":{\"name\":\"shared_provider_ig\",\"templates\":[{\"name\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]}],\"template\":\"database\",\"version\":\"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"sha1\":\"cdd45e4c8bc95c11a460f65378831c6730e31bdd\",\"blobstore_id\":\"217e108f-6517-4d36-ad5f-1d48046680d7\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_provider_ig\",\"id\":\"cb37a197-919b-423b-93e7-414338e93b55\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.14\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{},\"properties\":{\"database\":{\"foo\":\"normal_bar\",\"test\":\"default test property\"}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.14\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"database\":\"da39a3ee5e6b4b0d3255bfef95601890afd80709\"},\"rendered_templates_archive\":{\"blobstore_id\":\"75bfb2d3-45de-48ad-afa1-ffc154b53213\",\"sha1\":\"7584b8d51e39e30cad749b1d69c8f1b90d5adb71\"},\"configuration_hash\":\"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,7),(13,'shared_consumer_ig',0,7,'detached',0,'b9bd2625-7f57-40da-9d28-e0243d34551a','z1','{}',0,1,'[\"0.shared-consumer-ig.a.shared-deployment-with-errand.bosh\",\"b9bd2625-7f57-40da-9d28-e0243d34551a.shared-consumer-ig.a.shared-deployment-with-errand.bosh\"]','{\"deployment\":\"shared_deployment_with_errand\",\"job\":{\"name\":\"shared_consumer_ig\",\"templates\":[{\"name\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]}],\"template\":\"api_server\",\"version\":\"fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"sha1\":\"c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba\",\"blobstore_id\":\"f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1\",\"logs\":[]},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"shared_consumer_ig\",\"id\":\"b9bd2625-7f57-40da-9d28-e0243d34551a\",\"az\":\"z1\",\"networks\":{\"a\":{\"type\":\"manual\",\"ip\":\"192.168.1.15\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"vm_resources\":null,\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{},\"packages\":{\"pkg_3_depends_on_2\":{\"name\":\"pkg_3_depends_on_2\",\"version\":\"2dfa256bc0b0750ae9952118c428b0dcd1010305.1\",\"sha1\":\"d06dfad9d7686e516c42ea07b23b40c58f77b8ba\",\"blobstore_id\":\"4d513182-d721-44d6-6266-eed77a9b2fda\"}},\"properties\":{\"api_server\":{}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{\"api_server\":{\"db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}},\"backup_db\":{\"default_network\":\"a\",\"deployment_name\":\"shared_provider_deployment\",\"domain\":\"bosh\",\"instance_group\":\"shared_provider_ig\",\"instances\":[{\"name\":\"shared_provider_ig\",\"id\":\"bf93f912-ac25-425b-b5b2-e93525e6fe34\",\"index\":0,\"bootstrap\":true,\"az\":\"z1\",\"address\":\"192.168.1.3\"}],\"networks\":[\"a\"],\"properties\":{\"foo\":\"normal_bar\"}}}},\"address\":\"192.168.1.15\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true,\"strategy\":\"legacy\"},\"persistent_disk\":0,\"template_hashes\":{\"api_server\":\"cf13605f67e2c568dfa15d330aa577c450a5b321\"},\"rendered_templates_archive\":{\"blobstore_id\":\"44c135dd-30e9-4cb4-88f4-afd39151a6c6\",\"sha1\":\"0f46a021dad49c5a9532be7cb35d9d90a38403dc\"},\"configuration_hash\":\"6795db67786f368aae62ba170dcc8ec22ca6c6aa\"}',NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',1,0,7),(14,'errand_consumer_ig',0,7,'started',0,'43b1c6e7-bfb9-4093-b2e6-511eac86f685','z1',NULL,0,1,'[]',NULL,NULL,NULL,'da39a3ee5e6b4b0d3255bfef95601890afd80709',0,0,7);
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
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances_templates`
--

LOCK TABLES `instances_templates` WRITE;
/*!40000 ALTER TABLE `instances_templates` DISABLE KEYS */;
INSERT INTO `instances_templates` VALUES (1,1,11),(2,3,11),(3,4,2),(4,7,9),(5,8,2),(6,9,9),(7,10,2),(8,11,11),(9,11,13),(10,12,11),(11,13,2);
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'a',0,1,'2018-03-16 15:52:26','3','3232235778'),(2,'a',0,3,'2018-03-16 15:52:35','4','3232235779'),(3,'a',0,4,'2018-03-16 15:52:43','5','3232235780'),(6,'a',0,7,'2018-03-16 15:52:59','7','3232235781'),(7,'a',0,8,'2018-03-16 15:52:59','7','3232235782'),(8,'a',0,9,'2018-03-16 15:53:15','9','3232235783'),(9,'a',0,10,'2018-03-16 15:53:15','9','3232235784'),(10,'a',0,11,'2018-03-16 15:53:34','11','3232235785'),(11,'a',0,12,'2018-03-16 15:53:44','13','3232235790'),(12,'a',0,13,'2018-03-16 15:53:44','13','3232235791');
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_encoded_instance_groups`
--

LOCK TABLES `local_dns_encoded_instance_groups` WRITE;
/*!40000 ALTER TABLE `local_dns_encoded_instance_groups` DISABLE KEYS */;
INSERT INTO `local_dns_encoded_instance_groups` VALUES (2,'errand_consumer_ig',1),(12,'errand_consumer_ig',7),(9,'errand_ig',6),(1,'errand_provider_ig',1),(8,'explicit_consumer_ig',5),(7,'explicit_provider_ig',5),(6,'implicit_consumer_ig',4),(5,'implicit_provider_ig',4),(4,'shared_consumer_ig',3),(11,'shared_consumer_ig',7),(3,'shared_provider_ig',2),(10,'shared_provider_ig',7);
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
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `local_dns_records`
--

LOCK TABLES `local_dns_records` WRITE;
/*!40000 ALTER TABLE `local_dns_records` DISABLE KEYS */;
INSERT INTO `local_dns_records` VALUES (11,'192.168.1.2','z1','errand_provider_ig','a','errand_deployment',1,NULL,'bosh'),(12,'192.168.1.3','z1','shared_provider_ig','a','shared_provider_deployment',3,NULL,'bosh'),(13,'192.168.1.4','z1','shared_consumer_ig','a','shared_consumer_deployment',4,NULL,'bosh'),(14,'192.168.1.5','z1','implicit_provider_ig','a','implicit_deployment',7,NULL,'bosh'),(15,'192.168.1.6','z1','implicit_consumer_ig','a','implicit_deployment',8,NULL,'bosh'),(16,'192.168.1.7','z1','explicit_provider_ig','a','explicit_deployment',9,NULL,'bosh'),(17,'192.168.1.8','z1','explicit_consumer_ig','a','explicit_deployment',10,NULL,'bosh'),(18,'192.168.1.9','z1','errand_ig','a','colocated_errand_deployment',11,NULL,'bosh'),(19,'192.168.1.14','z1','shared_provider_ig','a','shared_deployment_with_errand',12,NULL,'bosh'),(20,'192.168.1.15','z1','shared_consumer_ig','a','shared_deployment_with_errand',13,NULL,'bosh');
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
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8;
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
INSERT INTO `packages` VALUES (1,'pkg_1','7a4094dc99aa72d2d156d99e022d3baa37fb7c4b','41d81ed3-d29d-4a5a-a234-dac7b4212c7a','953adf11df27dcc8d7b53362546b862b79b531bd','[]',1,'7a4094dc99aa72d2d156d99e022d3baa37fb7c4b'),(2,'pkg_2','fa48497a19f12e925b32fcb8f5ca2b42144e4444','c16232b9-088d-492d-9a01-0c47f0a19838','9a4c58f1abebcc33c9b4f57ceab1528f15dcc9d8','[]',1,'fa48497a19f12e925b32fcb8f5ca2b42144e4444'),(3,'pkg_3_depends_on_2','2dfa256bc0b0750ae9952118c428b0dcd1010305','7b04ce51-17d9-4c3c-a187-944bae93784a','443b5dc7f3e8a4a264f6a3ebc46bc1c6ebcd3c03','[\"pkg_2\"]',1,'2dfa256bc0b0750ae9952118c428b0dcd1010305');
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
) ENGINE=InnoDB AUTO_INCREMENT=46 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1521215648,1),(2,'bosh','NS','ns.bosh',14400,NULL,1521215648,1),(3,'ns.bosh','A',NULL,18000,NULL,1521215648,1),(4,'0.errand-provider-ig.a.errand-deployment.bosh','A','192.168.1.2',300,NULL,1521215640,1),(5,'1.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'1.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.1.168.192.in-addr.arpa','PTR','0.errand-provider-ig.a.errand-deployment.bosh',300,NULL,1521215640,2),(8,'7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce.errand-provider-ig.a.errand-deployment.bosh','A','192.168.1.2',300,NULL,1521215640,1),(9,'2.1.168.192.in-addr.arpa','PTR','7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce.errand-provider-ig.a.errand-deployment.bosh',300,NULL,1521215640,2),(10,'0.shared-provider-ig.a.shared-provider-deployment.bosh','A','192.168.1.3',300,NULL,1521215641,1),(11,'3.1.168.192.in-addr.arpa','PTR','0.shared-provider-ig.a.shared-provider-deployment.bosh',300,NULL,1521215641,2),(12,'bf93f912-ac25-425b-b5b2-e93525e6fe34.shared-provider-ig.a.shared-provider-deployment.bosh','A','192.168.1.3',300,NULL,1521215641,1),(13,'3.1.168.192.in-addr.arpa','PTR','bf93f912-ac25-425b-b5b2-e93525e6fe34.shared-provider-ig.a.shared-provider-deployment.bosh',300,NULL,1521215641,2),(14,'0.shared-consumer-ig.a.shared-consumer-deployment.bosh','A','192.168.1.4',300,NULL,1521215642,1),(15,'4.1.168.192.in-addr.arpa','PTR','0.shared-consumer-ig.a.shared-consumer-deployment.bosh',300,NULL,1521215642,2),(16,'63452a70-c669-4371-a162-38010d4afae0.shared-consumer-ig.a.shared-consumer-deployment.bosh','A','192.168.1.4',300,NULL,1521215642,1),(17,'4.1.168.192.in-addr.arpa','PTR','63452a70-c669-4371-a162-38010d4afae0.shared-consumer-ig.a.shared-consumer-deployment.bosh',300,NULL,1521215642,2),(18,'0.implicit-provider-ig.a.implicit-deployment.bosh','A','192.168.1.5',300,NULL,1521215644,1),(19,'5.1.168.192.in-addr.arpa','PTR','0.implicit-provider-ig.a.implicit-deployment.bosh',300,NULL,1521215644,2),(20,'d5a5af8e-cf13-456a-b188-21f0966f8969.implicit-provider-ig.a.implicit-deployment.bosh','A','192.168.1.5',300,NULL,1521215644,1),(21,'5.1.168.192.in-addr.arpa','PTR','d5a5af8e-cf13-456a-b188-21f0966f8969.implicit-provider-ig.a.implicit-deployment.bosh',300,NULL,1521215644,2),(22,'0.implicit-consumer-ig.a.implicit-deployment.bosh','A','192.168.1.6',300,NULL,1521215644,1),(23,'6.1.168.192.in-addr.arpa','PTR','0.implicit-consumer-ig.a.implicit-deployment.bosh',300,NULL,1521215644,2),(24,'4fc10508-5f4e-4083-8f88-8dbbb73171d5.implicit-consumer-ig.a.implicit-deployment.bosh','A','192.168.1.6',300,NULL,1521215644,1),(25,'6.1.168.192.in-addr.arpa','PTR','4fc10508-5f4e-4083-8f88-8dbbb73171d5.implicit-consumer-ig.a.implicit-deployment.bosh',300,NULL,1521215644,2),(26,'0.explicit-provider-ig.a.explicit-deployment.bosh','A','192.168.1.7',300,NULL,1521215645,1),(27,'7.1.168.192.in-addr.arpa','PTR','0.explicit-provider-ig.a.explicit-deployment.bosh',300,NULL,1521215645,2),(28,'320261ef-3c59-4f3d-95e9-eabac1fc7ae0.explicit-provider-ig.a.explicit-deployment.bosh','A','192.168.1.7',300,NULL,1521215645,1),(29,'7.1.168.192.in-addr.arpa','PTR','320261ef-3c59-4f3d-95e9-eabac1fc7ae0.explicit-provider-ig.a.explicit-deployment.bosh',300,NULL,1521215645,2),(30,'0.explicit-consumer-ig.a.explicit-deployment.bosh','A','192.168.1.8',300,NULL,1521215646,1),(31,'8.1.168.192.in-addr.arpa','PTR','0.explicit-consumer-ig.a.explicit-deployment.bosh',300,NULL,1521215646,2),(32,'1acbacd8-1ce8-40ec-a062-dbc75aac5d09.explicit-consumer-ig.a.explicit-deployment.bosh','A','192.168.1.8',300,NULL,1521215646,1),(33,'8.1.168.192.in-addr.arpa','PTR','1acbacd8-1ce8-40ec-a062-dbc75aac5d09.explicit-consumer-ig.a.explicit-deployment.bosh',300,NULL,1521215646,2),(34,'0.errand-ig.a.colocated-errand-deployment.bosh','A','192.168.1.9',300,NULL,1521215647,1),(35,'9.1.168.192.in-addr.arpa','PTR','0.errand-ig.a.colocated-errand-deployment.bosh',300,NULL,1521215647,2),(36,'ac6a4e3d-f86f-44a4-b498-bcecabc4578a.errand-ig.a.colocated-errand-deployment.bosh','A','192.168.1.9',300,NULL,1521215647,1),(37,'9.1.168.192.in-addr.arpa','PTR','ac6a4e3d-f86f-44a4-b498-bcecabc4578a.errand-ig.a.colocated-errand-deployment.bosh',300,NULL,1521215647,2),(38,'0.shared-provider-ig.a.shared-deployment-with-errand.bosh','A','192.168.1.14',300,NULL,1521215649,1),(39,'14.1.168.192.in-addr.arpa','PTR','0.shared-provider-ig.a.shared-deployment-with-errand.bosh',300,NULL,1521215649,2),(40,'cb37a197-919b-423b-93e7-414338e93b55.shared-provider-ig.a.shared-deployment-with-errand.bosh','A','192.168.1.14',300,NULL,1521215649,1),(41,'14.1.168.192.in-addr.arpa','PTR','cb37a197-919b-423b-93e7-414338e93b55.shared-provider-ig.a.shared-deployment-with-errand.bosh',300,NULL,1521215649,2),(42,'0.shared-consumer-ig.a.shared-deployment-with-errand.bosh','A','192.168.1.15',300,NULL,1521215649,1),(43,'15.1.168.192.in-addr.arpa','PTR','0.shared-consumer-ig.a.shared-deployment-with-errand.bosh',300,NULL,1521215649,2),(44,'b9bd2625-7f57-40da-9d28-e0243d34551a.shared-consumer-ig.a.shared-deployment-with-errand.bosh','A','192.168.1.15',300,NULL,1521215649,1),(45,'15.1.168.192.in-addr.arpa','PTR','b9bd2625-7f57-40da-9d28-e0243d34551a.shared-consumer-ig.a.shared-deployment-with-errand.bosh',300,NULL,1521215649,2);
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
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'c2b5bf268',1);
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
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rendered_templates_archives`
--

LOCK TABLES `rendered_templates_archives` WRITE;
/*!40000 ALTER TABLE `rendered_templates_archives` DISABLE KEYS */;
INSERT INTO `rendered_templates_archives` VALUES (1,1,'596fb6d6-273a-4d8b-8a3f-9ac711c17e2e','388390ee77deb76b7543c210a18f15ebe3e0f26f','6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf','2018-03-16 15:52:28'),(2,3,'6d0e7897-4bdd-43ec-80c8-a75467eed57c','3b2b6f64012898398cf2ce0530be1a7731e95852','6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf','2018-03-16 15:52:36'),(3,4,'0e7a2246-ccad-4a9c-b78a-4738fdab52d6','70ce257f7b6bc1366d972c7230303337345f0845','6795db67786f368aae62ba170dcc8ec22ca6c6aa','2018-03-16 15:52:51'),(4,7,'3686e16e-e606-463e-afa4-d47e1e414888','527db2dcd0445528e63e22e4961f2693f73523b1','4e4c9c0b7e76b5bc955b215edbd839e427d581aa','2018-03-16 15:53:01'),(5,8,'0565d217-8a6b-4705-889c-f8f483383e78','53c4a43d9c642f61c6413ae21c1f484172a38ec5','e3416449728d72a9fed98f7d89d801ca8a259242','2018-03-16 15:53:07'),(6,9,'1f5a8319-0f00-4c3a-bc48-11fc1676309e','afa0a618c83a28b89a1ca5570710dbf3e56e815c','4e4c9c0b7e76b5bc955b215edbd839e427d581aa','2018-03-16 15:53:17'),(7,10,'9976d90f-ee2e-4a00-ae5b-5f437dc108df','e929cba63bf946d41bbcaa7c17f3eb74b689260b','57ed863958fdaeb9d5cf40022b3c088bc71c627e','2018-03-16 15:53:24'),(8,11,'5416fa42-3d3f-4285-86fd-f40094f0f8c3','7f5fd98abfe0b3c2d9257d9aa22a922baaf64312','59192a7a26c0bc1a6bd8015205e0b64a31b66a74','2018-03-16 15:53:35'),(9,12,'75bfb2d3-45de-48ad-afa1-ffc154b53213','7584b8d51e39e30cad749b1d69c8f1b90d5adb71','6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf','2018-03-16 15:53:46'),(10,13,'44c135dd-30e9-4cb4-88f4-afd39151a6c6','0f46a021dad49c5a9532be7cb35d9d90a38403dc','6795db67786f368aae62ba170dcc8ec22ca6c6aa','2018-03-16 15:53:52');
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
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2018-03-16 15:52:24','create release','Created release \'bosh-release/0+dev.1\'','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/1','2018-03-16 15:52:23','update_release','test',NULL,'2018-03-16 15:52:23','{\"time\":1521215543,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Extracting release\",\"tags\":[],\"total\":1,\"task\":\"Extracting release\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Verifying manifest\",\"tags\":[],\"total\":1,\"task\":\"Verifying manifest\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Resolving package dependencies\",\"tags\":[],\"total\":1,\"task\":\"Resolving package dependencies\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new packages\",\"tags\":[],\"total\":3,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98\",\"index\":6,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec\",\"index\":7,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487\",\"index\":8,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"backup_database/822933af7d854849051ca16539653158ad233e5e\",\"index\":9,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c\",\"index\":10,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c\",\"index\":10,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65\",\"index\":11,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda\",\"index\":12,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5\",\"index\":13,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5\",\"index\":13,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889\",\"index\":14,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3\",\"index\":15,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215543,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389\",\"index\":16,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba\",\"index\":17,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59\",\"index\":18,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/bade0800183844ade5a58a26ecfb4f22e4255d98\",\"index\":19,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"node/bade0800183844ade5a58a26ecfb4f22e4255d98\",\"index\":19,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider/e1ff4ff9a6304e1222484570a400788c55154b1c\",\"index\":20,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37\",\"index\":21,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b\",\"index\":22,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Creating new jobs\",\"tags\":[],\"total\":23,\"task\":\"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267\",\"index\":23,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215544,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215544,\"stage\":\"Release has been created\",\"tags\":[],\"total\":1,\"task\":\"bosh-release/0+dev.1\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(2,'done','2018-03-16 15:52:25','create stemcell','/stemcells/ubuntu-stemcell/1','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/2','2018-03-16 15:52:25','update_stemcell','test',NULL,'2018-03-16 15:52:25','{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Extracting stemcell archive\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Verifying stemcell manifest\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Checking if this stemcell already exists\",\"index\":3,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Uploading stemcell ubuntu-stemcell/1 to the cloud\",\"index\":4,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215545,\"stage\":\"Update stemcell\",\"tags\":[],\"total\":5,\"task\":\"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)\",\"index\":5,\"state\":\"finished\",\"progress\":100}\n','',''),(3,'done','2018-03-16 15:52:34','create deployment','/deployments/errand_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/3','2018-03-16 15:52:26','update_deployment','test','errand_deployment','2018-03-16 15:52:26','{\"time\":1521215546,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215546,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215546,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215546,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215546,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215548,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215548,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215554,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(4,'done','2018-03-16 15:52:42','create deployment','/deployments/shared_provider_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/4','2018-03-16 15:52:35','update_deployment','test','shared_provider_deployment','2018-03-16 15:52:35','{\"time\":1521215555,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215555,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215555,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215555,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215555,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215556,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215556,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215562,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(5,'done','2018-03-16 15:52:58','create deployment','/deployments/shared_consumer_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/5','2018-03-16 15:52:43','update_deployment','test','shared_consumer_deployment','2018-03-16 15:52:43','{\"time\":1521215563,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215564,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215564,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215564,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215564,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215567,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215567,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215570,\"stage\":\"Compiling packages\",\"tags\":[],\"total\":2,\"task\":\"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215570,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215571,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215571,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215578,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(6,'done','2018-03-16 15:52:59','retrieve vm-stats','','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/6','2018-03-16 15:52:59','vms','test','shared_consumer_deployment','2018-03-16 15:52:59','','{\"vm_cid\":\"43581\",\"vm_created_at\":\"2018-03-16T15:52:50Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.4\"],\"dns\":[\"63452a70-c669-4371-a162-38010d4afae0.shared-consumer-ig.a.shared-consumer-deployment.bosh\",\"0.shared-consumer-ig.a.shared-consumer-deployment.bosh\"],\"agent_id\":\"acdb9c2e-196e-43ef-bbf2-1c199b25bd47\",\"job_name\":\"shared_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"1.3\",\"user\":\"2.4\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.36\",\"2.42\",\"2.43\"],\"mem\":{\"kb\":\"20262340\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174573}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"63452a70-c669-4371-a162-38010d4afae0\",\"bootstrap\":true,\"ignore\":false}\n',''),(7,'done','2018-03-16 15:53:13','create deployment','/deployments/implicit_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/7','2018-03-16 15:52:59','update_deployment','test','implicit_deployment','2018-03-16 15:52:59','{\"time\":1521215579,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215579,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215579,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215579,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215579,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215579,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215580,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215581,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215581,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215587,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215587,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215593,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(8,'done','2018-03-16 15:53:14','retrieve vm-stats','','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/8','2018-03-16 15:53:14','vms','test','implicit_deployment','2018-03-16 15:53:14','','{\"vm_cid\":\"43615\",\"vm_created_at\":\"2018-03-16T15:52:59Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.6\"],\"dns\":[\"4fc10508-5f4e-4083-8f88-8dbbb73171d5.implicit-consumer-ig.a.implicit-deployment.bosh\",\"0.implicit-consumer-ig.a.implicit-deployment.bosh\"],\"agent_id\":\"efb06713-4688-4f54-8419-e3c1bd72bb1c\",\"job_name\":\"implicit_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.0\",\"user\":\"3.4\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.36\",\"2.42\",\"2.42\"],\"mem\":{\"kb\":\"20269056\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174588}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"4fc10508-5f4e-4083-8f88-8dbbb73171d5\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"43611\",\"vm_created_at\":\"2018-03-16T15:52:59Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.5\"],\"dns\":[\"d5a5af8e-cf13-456a-b188-21f0966f8969.implicit-provider-ig.a.implicit-deployment.bosh\",\"0.implicit-provider-ig.a.implicit-deployment.bosh\"],\"agent_id\":\"ff20925c-d5be-47d4-9cd9-f5dc95e398d2\",\"job_name\":\"implicit_provider_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.1\",\"user\":\"3.7\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.36\",\"2.42\",\"2.42\"],\"mem\":{\"kb\":\"20269056\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174588}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"d5a5af8e-cf13-456a-b188-21f0966f8969\",\"bootstrap\":true,\"ignore\":false}\n',''),(9,'done','2018-03-16 15:53:31','create deployment','/deployments/explicit_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/9','2018-03-16 15:53:15','update_deployment','test','explicit_deployment','2018-03-16 15:53:15','{\"time\":1521215595,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215595,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215595,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215595,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215595,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215595,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215596,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215597,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215597,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215604,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215604,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215611,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(10,'done','2018-03-16 15:53:32','retrieve vm-stats','','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/10','2018-03-16 15:53:32','vms','test','explicit_deployment','2018-03-16 15:53:32','','{\"vm_cid\":\"43658\",\"vm_created_at\":\"2018-03-16T15:53:16Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.8\"],\"dns\":[\"1acbacd8-1ce8-40ec-a062-dbc75aac5d09.explicit-consumer-ig.a.explicit-deployment.bosh\",\"0.explicit-consumer-ig.a.explicit-deployment.bosh\"],\"agent_id\":\"c7258f93-0194-489e-ad3a-88f20ea99faa\",\"job_name\":\"explicit_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.0\",\"user\":\"3.2\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.32\",\"2.41\",\"2.42\"],\"mem\":{\"kb\":\"20289032\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174606}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"1acbacd8-1ce8-40ec-a062-dbc75aac5d09\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"43648\",\"vm_created_at\":\"2018-03-16T15:53:15Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.7\"],\"dns\":[\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0.explicit-provider-ig.a.explicit-deployment.bosh\",\"0.explicit-provider-ig.a.explicit-deployment.bosh\"],\"agent_id\":\"67460908-518c-4519-b3e4-5edf60e26be1\",\"job_name\":\"explicit_provider_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.2\",\"user\":\"3.8\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.32\",\"2.41\",\"2.42\"],\"mem\":{\"kb\":\"20289032\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174606}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"320261ef-3c59-4f3d-95e9-eabac1fc7ae0\",\"bootstrap\":true,\"ignore\":false}\n',''),(11,'done','2018-03-16 15:53:42','create deployment','/deployments/colocated_errand_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/11','2018-03-16 15:53:33','update_deployment','test','colocated_errand_deployment','2018-03-16 15:53:33','{\"time\":1521215613,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215614,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215614,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215614,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215614,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215615,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215615,\"stage\":\"Updating instance\",\"tags\":[\"errand_ig\"],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215622,\"stage\":\"Updating instance\",\"tags\":[\"errand_ig\"],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(12,'done','2018-03-16 15:53:43','retrieve vm-stats','','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/12','2018-03-16 15:53:43','vms','test','colocated_errand_deployment','2018-03-16 15:53:43','','{\"vm_cid\":\"43690\",\"vm_created_at\":\"2018-03-16T15:53:34Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.9\"],\"dns\":[\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a.errand-ig.a.colocated-errand-deployment.bosh\",\"0.errand-ig.a.colocated-errand-deployment.bosh\"],\"agent_id\":\"f403c17b-bee2-4d78-a4ba-009d4dd1c79b\",\"job_name\":\"errand_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"1.3\",\"user\":\"2.4\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.43\",\"2.43\",\"2.42\"],\"mem\":{\"kb\":\"20297344\",\"percent\":\"60\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174617}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"ac6a4e3d-f86f-44a4-b498-bcecabc4578a\",\"bootstrap\":true,\"ignore\":false}\n',''),(13,'done','2018-03-16 15:53:58','create deployment','/deployments/shared_deployment_with_errand','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/13','2018-03-16 15:53:44','update_deployment','test','shared_deployment_with_errand','2018-03-16 15:53:44','{\"time\":1521215624,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215624,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215624,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215624,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215624,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215624,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0)\",\"index\":2,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215626,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0)\",\"index\":2,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215626,\"stage\":\"Creating missing vms\",\"tags\":[],\"total\":2,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215626,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215632,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215632,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215638,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(14,'done','2018-03-16 15:53:59','retrieve vm-stats','','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/14','2018-03-16 15:53:59','vms','test','shared_deployment_with_errand','2018-03-16 15:53:59','','{\"vm_cid\":null,\"vm_created_at\":null,\"disk_cid\":null,\"disk_cids\":[],\"ips\":[],\"dns\":[],\"agent_id\":null,\"job_name\":\"errand_consumer_ig\",\"index\":0,\"job_state\":null,\"state\":\"started\",\"resource_pool\":null,\"vm_type\":null,\"vitals\":null,\"processes\":[],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"43b1c6e7-bfb9-4093-b2e6-511eac86f685\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"43727\",\"vm_created_at\":\"2018-03-16T15:53:45Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.14\"],\"dns\":[\"cb37a197-919b-423b-93e7-414338e93b55.shared-provider-ig.a.shared-deployment-with-errand.bosh\",\"0.shared-provider-ig.a.shared-deployment-with-errand.bosh\"],\"agent_id\":\"153ca322-9988-4f24-aad0-b139bf2324ea\",\"job_name\":\"shared_provider_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.0\",\"user\":\"3.4\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.25\",\"2.39\",\"2.41\"],\"mem\":{\"kb\":\"20311348\",\"percent\":\"61\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174633}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"cb37a197-919b-423b-93e7-414338e93b55\",\"bootstrap\":true,\"ignore\":false}\n{\"vm_cid\":\"43720\",\"vm_created_at\":\"2018-03-16T15:53:44Z\",\"disk_cid\":null,\"disk_cids\":[],\"ips\":[\"192.168.1.15\"],\"dns\":[\"b9bd2625-7f57-40da-9d28-e0243d34551a.shared-consumer-ig.a.shared-deployment-with-errand.bosh\",\"0.shared-consumer-ig.a.shared-deployment-with-errand.bosh\"],\"agent_id\":\"c7741e7b-bc59-4650-897d-d68c17a5ea63\",\"job_name\":\"shared_consumer_ig\",\"index\":0,\"job_state\":\"running\",\"state\":\"started\",\"resource_pool\":\"a\",\"vm_type\":\"a\",\"vitals\":{\"cpu\":{\"sys\":\"2.3\",\"user\":\"4.0\",\"wait\":\"0.0\"},\"disk\":{\"ephemeral\":{\"inode_percent\":\"0\",\"percent\":\"82\"},\"system\":{\"inode_percent\":\"0\",\"percent\":\"82\"}},\"load\":[\"2.25\",\"2.39\",\"2.41\"],\"mem\":{\"kb\":\"20311348\",\"percent\":\"61\"},\"swap\":{\"kb\":\"0\",\"percent\":\"0\"},\"uptime\":{\"secs\":174633}},\"processes\":[{\"name\":\"process-1\",\"state\":\"running\",\"uptime\":{\"secs\":144987},\"mem\":{\"kb\":100,\"percent\":0.1},\"cpu\":{\"total\":0.1}},{\"name\":\"process-2\",\"state\":\"running\",\"uptime\":{\"secs\":144988},\"mem\":{\"kb\":200,\"percent\":0.2},\"cpu\":{\"total\":0.2}},{\"name\":\"process-3\",\"state\":\"failing\",\"uptime\":{\"secs\":144989},\"mem\":{\"kb\":300,\"percent\":0.3},\"cpu\":{\"total\":0.3}}],\"resurrection_paused\":false,\"az\":\"z1\",\"id\":\"b9bd2625-7f57-40da-9d28-e0243d34551a\",\"bootstrap\":true,\"ignore\":false}\n',''),(15,'done','2018-03-16 15:54:00','create deployment','/deployments/errand_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/15','2018-03-16 15:53:59','update_deployment','test','errand_deployment','2018-03-16 15:53:59','{\"time\":1521215639,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215639,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215639,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215639,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215639,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215640,\"stage\":\"Updating instance\",\"tags\":[\"errand_provider_ig\"],\"total\":1,\"task\":\"errand_provider_ig/7f1f6ab5-4103-4e2c-80aa-abd4c7b6d4ce (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(16,'done','2018-03-16 15:54:01','create deployment','/deployments/shared_provider_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/16','2018-03-16 15:54:00','update_deployment','test','shared_provider_deployment','2018-03-16 15:54:00','{\"time\":1521215641,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215641,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215641,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215641,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215641,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215641,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/bf93f912-ac25-425b-b5b2-e93525e6fe34 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(17,'done','2018-03-16 15:54:03','create deployment','/deployments/shared_consumer_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/17','2018-03-16 15:54:02','update_deployment','test','shared_consumer_deployment','2018-03-16 15:54:02','{\"time\":1521215642,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215642,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215642,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215642,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215642,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215643,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/63452a70-c669-4371-a162-38010d4afae0 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(18,'done','2018-03-16 15:54:04','create deployment','/deployments/implicit_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/18','2018-03-16 15:54:03','update_deployment','test','implicit_deployment','2018-03-16 15:54:03','{\"time\":1521215643,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215643,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215644,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215644,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215644,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215644,\"stage\":\"Updating instance\",\"tags\":[\"implicit_provider_ig\"],\"total\":1,\"task\":\"implicit_provider_ig/d5a5af8e-cf13-456a-b188-21f0966f8969 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215644,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215644,\"stage\":\"Updating instance\",\"tags\":[\"implicit_consumer_ig\"],\"total\":1,\"task\":\"implicit_consumer_ig/4fc10508-5f4e-4083-8f88-8dbbb73171d5 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(19,'done','2018-03-16 15:54:06','create deployment','/deployments/explicit_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/19','2018-03-16 15:54:05','update_deployment','test','explicit_deployment','2018-03-16 15:54:05','{\"time\":1521215645,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215645,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215645,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215645,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215645,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215645,\"stage\":\"Updating instance\",\"tags\":[\"explicit_provider_ig\"],\"total\":1,\"task\":\"explicit_provider_ig/320261ef-3c59-4f3d-95e9-eabac1fc7ae0 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215645,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215646,\"stage\":\"Updating instance\",\"tags\":[\"explicit_consumer_ig\"],\"total\":1,\"task\":\"explicit_consumer_ig/1acbacd8-1ce8-40ec-a062-dbc75aac5d09 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(20,'done','2018-03-16 15:54:07','create deployment','/deployments/colocated_errand_deployment','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/20','2018-03-16 15:54:06','update_deployment','test','colocated_errand_deployment','2018-03-16 15:54:06','{\"time\":1521215646,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215647,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215647,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215647,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215647,\"stage\":\"Updating instance\",\"tags\":[\"errand_ig\"],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215647,\"stage\":\"Updating instance\",\"tags\":[\"errand_ig\"],\"total\":1,\"task\":\"errand_ig/ac6a4e3d-f86f-44a4-b498-bcecabc4578a (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','',''),(21,'done','2018-03-16 15:54:09','create deployment','/deployments/shared_deployment_with_errand','/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-43288/sandbox/boshdir/tasks/21','2018-03-16 15:54:08','update_deployment','test','shared_deployment_with_errand','2018-03-16 15:54:08','{\"time\":1521215648,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215648,\"stage\":\"Preparing deployment\",\"tags\":[],\"total\":1,\"task\":\"Preparing deployment\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215648,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215648,\"stage\":\"Preparing package compilation\",\"tags\":[],\"total\":1,\"task\":\"Finding packages to compile\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215648,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215649,\"stage\":\"Updating instance\",\"tags\":[\"shared_provider_ig\"],\"total\":1,\"task\":\"shared_provider_ig/cb37a197-919b-423b-93e7-414338e93b55 (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n{\"time\":1521215649,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0) (canary)\",\"index\":1,\"state\":\"started\",\"progress\":0}\n{\"time\":1521215649,\"stage\":\"Updating instance\",\"tags\":[\"shared_consumer_ig\"],\"total\":1,\"task\":\"shared_consumer_ig/b9bd2625-7f57-40da-9d28-e0243d34551a (0) (canary)\",\"index\":1,\"state\":\"finished\",\"progress\":100}\n','','');
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
INSERT INTO `templates` VALUES (1,'addon','1c5442ca2a20c46a3404e89d16b47c4757b1f0ca','8a0b792d-0719-4dc9-b962-ba58d86e6004','01ef035c7605c30df2c91aba6c46de5e055e89a2','[]',1,NULL,'1c5442ca2a20c46a3404e89d16b47c4757b1f0ca',NULL,NULL,NULL,NULL,'{\"name\":\"addon\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"}],\"properties\":{}}'),(2,'api_server','fd80d6fe55e4dfec8edfe258e1ba03c24146954e','f7ce6f4e-0fe4-40ee-b6ba-ec61ea2c68f1','c60840ee49f47d42cdb6ae85b6b405bfbf3d28ba','[\"pkg_3_depends_on_2\"]',1,NULL,'fd80d6fe55e4dfec8edfe258e1ba03c24146954e',NULL,NULL,NULL,NULL,'{\"name\":\"api_server\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}],\"properties\":{}}'),(3,'api_server_with_bad_link_types','058b26819bd6561a75c2fed45ec49e671c9fbc6a','9229f23c-8716-4230-b2b9-06cfc54b0482','25480f3ed5a7866dff9db66d125ff3f00397e37c','[\"pkg_3_depends_on_2\"]',1,NULL,'058b26819bd6561a75c2fed45ec49e671c9fbc6a',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_bad_link_types\",\"templates\":{\"config.yml.erb\":\"config.yml\",\"somethingelse.yml.erb\":\"somethingelse.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"bad_link\"},{\"name\":\"backup_db\",\"type\":\"bad_link_2\"},{\"name\":\"some_link_name\",\"type\":\"bad_link_3\"}],\"properties\":{}}'),(4,'api_server_with_bad_optional_links','8a2485f1de3d99657e101fd269202c39cf3b5d73','30057217-f0ac-42c5-a418-dfa29f86eb78','6babd24457e6ce6aec128bf76b58ce53e748b2f8','[\"pkg_3_depends_on_2\"]',1,NULL,'8a2485f1de3d99657e101fd269202c39cf3b5d73',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_bad_optional_links\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}],\"properties\":{}}'),(5,'api_server_with_optional_db_link','00831c288b4a42454543ff69f71360634bd06b7b','9475b8e7-d21f-43b7-9f68-06a1cc3ac79e','a2eda847a50854e3194bd4d313cdcd0d4752a942','[\"pkg_3_depends_on_2\"]',1,NULL,'00831c288b4a42454543ff69f71360634bd06b7b',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_db_link\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\",\"optional\":true}],\"properties\":{}}'),(6,'api_server_with_optional_links_1','0efc908dd04d84858e3cf8b75c326f35af5a5a98','16314c4d-5e33-4b45-94ca-e6cf1721220a','31b19c7499b6465e6eb146d4fc066fb064ee97cf','[\"pkg_3_depends_on_2\"]',1,NULL,'0efc908dd04d84858e3cf8b75c326f35af5a5a98',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_links_1\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"},{\"name\":\"optional_link_name\",\"type\":\"optional_link_type\",\"optional\":true}],\"properties\":{}}'),(7,'api_server_with_optional_links_2','15f815868a057180e21dbac61629f73ad3558fec','5cbc0c02-1124-4eac-a8d7-8cf224d83cc8','1c605472e86a3b972467484857b7d2b4abca3fcb','[\"pkg_3_depends_on_2\"]',1,NULL,'15f815868a057180e21dbac61629f73ad3558fec',NULL,NULL,NULL,NULL,'{\"name\":\"api_server_with_optional_links_2\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[\"pkg_3_depends_on_2\"],\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\",\"optional\":true}],\"properties\":{}}'),(8,'app_server','58e364fb74a01a1358475fc1da2ad905b78b4487','4f14b8f4-5d6b-47e5-b2d2-a211df563d32','de0bf2fb1a1bf59ea0ede6c2ca00aea224761bd1','[]',1,NULL,'58e364fb74a01a1358475fc1da2ad905b78b4487',NULL,NULL,NULL,NULL,'{\"name\":\"app_server\",\"description\":null,\"templates\":{\"config.yml.erb\":\"config.yml\"},\"properties\":{}}'),(9,'backup_database','822933af7d854849051ca16539653158ad233e5e','a008d190-912e-4319-ac18-69ac51a6a51c','e5bb9472cf6407b22181196c47e4195fa1a9a8d5','[]',1,NULL,'822933af7d854849051ca16539653158ad233e5e',NULL,NULL,NULL,NULL,'{\"name\":\"backup_database\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"backup_db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"backup_bar\"}}}'),(10,'consumer','9bed4913876cf51ae1a0ee4b561083711c19bf5c','488d7d62-5546-41a1-80a8-5254abcb9223','67b15e59144eefa10d81ab193773adb7b53df525','[]',1,NULL,'9bed4913876cf51ae1a0ee4b561083711c19bf5c',NULL,NULL,NULL,NULL,'{\"name\":\"consumer\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"consumes\":[{\"name\":\"provider\",\"type\":\"provider\"}],\"properties\":{}}'),(11,'database','b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65','217e108f-6517-4d36-ad5f-1d48046680d7','cdd45e4c8bc95c11a460f65378831c6730e31bdd','[]',1,NULL,'b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65',NULL,NULL,NULL,NULL,'{\"name\":\"database\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"normal_bar\"},\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}}'),(12,'database_with_two_provided_link_of_same_type','7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda','311bd646-ae48-439d-bbdd-824c27460bb1','fd2c6cd82c0c3dbfc0e884601eaee736b51c333e','[]',1,NULL,'7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda',NULL,NULL,NULL,NULL,'{\"name\":\"database_with_two_provided_link_of_same_type\",\"templates\":{},\"packages\":[],\"provides\":[{\"name\":\"db1\",\"type\":\"db\"},{\"name\":\"db2\",\"type\":\"db\"}],\"properties\":{\"test\":{\"description\":\"test property\",\"default\":\"default test property\"}}}'),(13,'errand_with_links','9a52f02643a46dda217689182e5fa3b57822ced5','c4827c65-8a3a-4282-af0b-e4d722653a8a','4bebb80ff95c5a4e985df3cb603113b094eed586','[]',1,NULL,'9a52f02643a46dda217689182e5fa3b57822ced5',NULL,NULL,NULL,NULL,'{\"name\":\"errand_with_links\",\"templates\":{\"config.yml.erb\":\"config.yml\",\"run.erb\":\"bin/run\"},\"consumes\":[{\"name\":\"db\",\"type\":\"db\"},{\"name\":\"backup_db\",\"type\":\"db\"}],\"properties\":{}}'),(14,'http_endpoint_provider_with_property_types','30978e9fd0d29e52fe0369262e11fbcea1283889','00eb282b-1185-45a8-912f-a16df2ef10b4','58e65f1c92b15ea135c778f1e9beec1c08b6510a','[]',1,NULL,'30978e9fd0d29e52fe0369262e11fbcea1283889',NULL,NULL,NULL,NULL,'{\"name\":\"http_endpoint_provider_with_property_types\",\"description\":\"This job runs an HTTP server and with a provides link directive. It has properties with types.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"Has a type password and no default value\",\"type\":\"password\"}}}'),(15,'http_proxy_with_requires','760680c4a796a2ffca24026c561c06dd5bdef6b3','447fdca9-1df2-4c80-8e4b-7d14150eb14e','b4f77d3622ee3d443712690d2c5f8c765379520e','[]',1,NULL,'760680c4a796a2ffca24026c561c06dd5bdef6b3',NULL,NULL,NULL,NULL,'{\"name\":\"http_proxy_with_requires\",\"description\":\"This job runs an HTTP proxy and uses a link to find its backend.\",\"templates\":{\"ctl.sh\":\"bin/ctl\",\"config.yml.erb\":\"config/config.yml\",\"props.json\":\"config/props.json\",\"pre-start.erb\":\"bin/pre-start\"},\"consumes\":[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"},{\"name\":\"logs_http_endpoint\",\"type\":\"http_endpoint2\",\"optional\":true}],\"properties\":{\"http_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"http_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"http_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"http_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"http_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}}'),(16,'http_server_with_provides','64244f12f2db2e7d93ccfbc13be744df87013389','5acb1418-a43e-4258-894d-b3c3b278e75b','0d55f279e5b0709cc7f67b34631ace2c7b6711dc','[]',1,NULL,'64244f12f2db2e7d93ccfbc13be744df87013389',NULL,NULL,NULL,NULL,'{\"name\":\"http_server_with_provides\",\"description\":\"This job runs an HTTP server and with a provides link directive.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}}'),(17,'kv_http_server','044ec02730e6d068ecf88a0d37fe48937687bdba','93237e32-c97e-4b67-80de-cfa3d171f605','2001f18617405d74d08b00a615231e49c6b5af50','[]',1,NULL,'044ec02730e6d068ecf88a0d37fe48937687bdba',NULL,NULL,NULL,NULL,'{\"name\":\"kv_http_server\",\"description\":\"This job can run as a cluster.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"consumes\":[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}],\"provides\":[{\"name\":\"kv_http_server\",\"type\":\"kv_http_server\"}],\"properties\":{\"kv_http_server.listen_port\":{\"description\":\"Port to listen on\",\"default\":8080}}}'),(18,'mongo_db','58529a6cd5775fa1f7ef89ab4165e0331cdb0c59','e48893ca-6438-409c-b5b1-4295fd7a8d65','077f30f79c3298673a0c85e7c4a58d29dd62f9c2','[\"pkg_1\"]',1,NULL,'58529a6cd5775fa1f7ef89ab4165e0331cdb0c59',NULL,NULL,NULL,NULL,'{\"name\":\"mongo_db\",\"templates\":{},\"packages\":[\"pkg_1\"],\"provides\":[{\"name\":\"read_only_db\",\"type\":\"db\",\"properties\":[\"foo\"]}],\"properties\":{\"foo\":{\"default\":\"mongo_foo_db\"}}}'),(19,'node','bade0800183844ade5a58a26ecfb4f22e4255d98','58cbd635-bfa5-490f-a1c3-1dbeb3b78164','28c21667810743d58056d33a80e5d35f2da8f13d','[]',1,NULL,'bade0800183844ade5a58a26ecfb4f22e4255d98',NULL,NULL,NULL,NULL,'{\"name\":\"node\",\"templates\":{\"config.yml.erb\":\"config.yml\"},\"packages\":[],\"provides\":[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}],\"consumes\":[{\"name\":\"node1\",\"type\":\"node1\"},{\"name\":\"node2\",\"type\":\"node2\"}],\"properties\":{}}'),(20,'provider','e1ff4ff9a6304e1222484570a400788c55154b1c','da93767e-b23d-4f86-93be-9ac8bf6e4451','06822c15235710a65af26d6c26ac9ca1a2543508','[]',1,NULL,'e1ff4ff9a6304e1222484570a400788c55154b1c',NULL,NULL,NULL,NULL,'{\"name\":\"provider\",\"templates\":{},\"provides\":[{\"name\":\"provider\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}],\"properties\":{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"b\":{\"description\":\"description for b\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}}'),(21,'provider_fail','314c385e96711cb5d56dd909a086563dae61bc37','0c0643e8-c599-44b2-839c-ee946a5c4d34','354f48efccc1df74a81053444b24d7aca9ddc5f5','[]',1,NULL,'314c385e96711cb5d56dd909a086563dae61bc37',NULL,NULL,NULL,NULL,'{\"name\":\"provider_fail\",\"templates\":{},\"provides\":[{\"name\":\"provider_fail\",\"type\":\"provider\",\"properties\":[\"a\",\"b\",\"c\"]}],\"properties\":{\"a\":{\"description\":\"description for a\",\"default\":\"default_a\"},\"c\":{\"description\":\"description for c\",\"default\":\"default_c\"}}}'),(22,'tcp_proxy_with_requires','e60ea353cdd24b6997efdedab144431c0180645b','02dc2f7b-e3ac-4a08-beaa-1ea10b735389','43f5d3cc4e9bfc7d9bbb2afed60a7dd8779a4240','[]',1,NULL,'e60ea353cdd24b6997efdedab144431c0180645b',NULL,NULL,NULL,NULL,'{\"name\":\"tcp_proxy_with_requires\",\"description\":\"This job runs an HTTP proxy and uses a link to find its backend.\",\"templates\":{\"ctl.sh\":\"bin/ctl\",\"config.yml.erb\":\"config/config.yml\",\"props.json\":\"config/props.json\",\"pre-start.erb\":\"bin/pre-start\"},\"consumes\":[{\"name\":\"proxied_http_endpoint\",\"type\":\"http_endpoint\"}],\"properties\":{\"tcp_proxy_with_requires.listen_port\":{\"description\":\"Listen port\",\"default\":8080},\"tcp_proxy_with_requires.require_logs_in_template\":{\"description\":\"Require logs in template\",\"default\":false},\"someProp\":{\"default\":null},\"tcp_proxy_with_requires.fail_instance_index\":{\"description\":\"Fail for instance #. Failure type must be set for failure\",\"default\":-1},\"tcp_proxy_with_requires.fail_on_template_rendering\":{\"description\":\"Fail for instance <fail_instance_index> during template rendering\",\"default\":false},\"tcp_proxy_with_requires.fail_on_job_start\":{\"description\":\"Fail for instance <fail_instance_index> on job start\",\"default\":false}}}'),(23,'tcp_server_with_provides','6c9ab3bde161668d1d1ea60f3611c3b19a3b3267','af57240b-da60-4897-9b3b-0c7d482ec963','55ae49f2937b335be235f7a8e9375b638aad296f','[]',1,NULL,'6c9ab3bde161668d1d1ea60f3611c3b19a3b3267',NULL,NULL,NULL,NULL,'{\"name\":\"tcp_server_with_provides\",\"description\":\"This job runs an HTTP server and with a provides link directive.\",\"templates\":{\"ctl.sh\":\"bin/ctl\"},\"provides\":[{\"name\":\"http_endpoint\",\"type\":\"http_endpoint\",\"properties\":[\"listen_port\",\"name_space.prop_a\",\"name_space.fibonacci\"]}],\"properties\":{\"listen_port\":{\"description\":\"Port to listen on\",\"default\":8080},\"name_space.prop_a\":{\"description\":\"a name spaced property\",\"default\":\"default\"},\"name_space.fibonacci\":{\"description\":\"has no default value\"}}}');
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `variable_sets`
--

LOCK TABLES `variable_sets` WRITE;
/*!40000 ALTER TABLE `variable_sets` DISABLE KEYS */;
INSERT INTO `variable_sets` VALUES (1,1,'2018-03-16 15:52:26',1,0),(2,2,'2018-03-16 15:52:35',1,0),(3,3,'2018-03-16 15:52:43',1,0),(4,4,'2018-03-16 15:52:59',1,0),(5,5,'2018-03-16 15:53:15',1,0),(6,6,'2018-03-16 15:53:33',1,0),(7,7,'2018-03-16 15:53:44',1,0);
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8;
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

-- Dump completed on 2018-03-16 11:55:56
