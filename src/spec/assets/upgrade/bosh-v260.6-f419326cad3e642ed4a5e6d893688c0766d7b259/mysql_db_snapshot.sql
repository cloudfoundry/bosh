-- MySQL dump 10.13  Distrib 5.5.54, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: 88b7cfae99334544a480c5608d37662d
-- ------------------------------------------------------
-- Server version	5.5.54-0ubuntu0.14.04.1

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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cloud_configs`
--

LOCK TABLES `cloud_configs` WRITE;
/*!40000 ALTER TABLE `cloud_configs` DISABLE KEYS */;
INSERT INTO `cloud_configs` VALUES (1,'---\nnetworks:\n- name: a\n  subnets:\n  - range: 192.168.1.0/24\n    gateway: 192.168.1.1\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    static:\n    - 192.168.1.10\n    reserved: []\n    cloud_properties: {}\ncompilation:\n  workers: 1\n  network: a\n  cloud_properties: {}\nresource_pools:\n- name: a\n  cloud_properties: {}\n  stemcell:\n    name: ubuntu-stemcell\n    version: \'1\'\n  env:\n    bosh:\n      password: foobar\n','2017-02-15 15:55:27');
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `compiled_packages`
--

LOCK TABLES `compiled_packages` WRITE;
/*!40000 ALTER TABLE `compiled_packages` DISABLE KEYS */;
INSERT INTO `compiled_packages` VALUES (1,'950e3ed2-bf7e-41d2-655b-632f66df87ee','be24476f4099bf5beac0295853ce29fd785c15d7','[]',1,8,'97d170e1550eee4afc0af065b78cda302a97674c','toronto-os','1'),(2,'ea0081b0-845f-42e9-6d18-481e85632435','41b9544c04e4f63ba15abdbab5466853be4077c6','[[\"foo\",\"0ee95716c58cf7aab3ef7301ff907118552c2dda\"]]',1,3,'2ab05f5881c448e1fdf9f2438f31a41d654c27e6','toronto-os','1');
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deployments`
--

LOCK TABLES `deployments` WRITE;
/*!40000 ALTER TABLE `deployments` DISABLE KEYS */;
INSERT INTO `deployments` VALUES (1,'simple','---\nname: simple\ndirector_uuid: deadbeef\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\njobs:\n- name: foobar1\n  templates:\n  - name: foobar\n  resource_pool: a\n  instances: 2\n  networks:\n  - name: a\n  properties: {}\n',1,'{}',NULL);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,NULL,'test','2017-02-15 15:55:27','update','cloud-config',NULL,NULL,NULL,NULL,NULL,'{}'),(2,NULL,'test','2017-02-15 15:55:29','create','deployment','simple',NULL,'3','simple',NULL,'{}'),(3,NULL,'test','2017-02-15 15:55:30','create','instance','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(4,NULL,'test','2017-02-15 15:55:30','create','vm',NULL,NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(5,4,'test','2017-02-15 15:55:30','create','vm','17841',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(6,3,'test','2017-02-15 15:55:33','create','instance','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(7,NULL,'test','2017-02-15 15:55:34','delete','instance','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(8,NULL,'test','2017-02-15 15:55:34','delete','vm','17841',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(9,8,'test','2017-02-15 15:55:34','delete','vm','17841',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(10,7,'test','2017-02-15 15:55:34','delete','instance','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401',NULL,'3','simple','compilation-393ba9e7-7a22-4c16-a945-46fee250db53/c861d80b-4274-4f9b-9d1b-770e9646b401','{}'),(11,NULL,'test','2017-02-15 15:55:34','create','instance','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(12,NULL,'test','2017-02-15 15:55:34','create','vm',NULL,NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(13,12,'test','2017-02-15 15:55:34','create','vm','17847',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(14,11,'test','2017-02-15 15:55:35','create','instance','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(15,NULL,'test','2017-02-15 15:55:36','delete','instance','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(16,NULL,'test','2017-02-15 15:55:36','delete','vm','17847',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(17,16,'test','2017-02-15 15:55:36','delete','vm','17847',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(18,15,'test','2017-02-15 15:55:36','delete','instance','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea',NULL,'3','simple','compilation-4c532993-e6e7-4f07-9d61-a07fd4c78362/fc8e4f01-fb52-4f56-90be-da71b5d52eea','{}'),(19,NULL,'test','2017-02-15 15:55:36','create','vm',NULL,NULL,'3','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(20,NULL,'test','2017-02-15 15:55:36','create','vm',NULL,NULL,'3','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(21,19,'test','2017-02-15 15:55:36','create','vm','17853',NULL,'3','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(22,20,'test','2017-02-15 15:55:36','create','vm','17854',NULL,'3','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(23,NULL,'test','2017-02-15 15:55:36','create','instance','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc',NULL,'3','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(24,23,'test','2017-02-15 15:55:43','create','instance','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc',NULL,'3','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(25,NULL,'test','2017-02-15 15:55:43','create','instance','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043',NULL,'3','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(26,25,'test','2017-02-15 15:55:50','create','instance','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043',NULL,'3','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(27,2,'test','2017-02-15 15:55:50','create','deployment','simple',NULL,'3','simple',NULL,'{\"before\":{},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}'),(28,NULL,'test','2017-02-15 15:55:52','update','deployment','simple',NULL,'4','simple',NULL,'{}'),(29,NULL,'test','2017-02-15 15:55:52','stop','instance','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc',NULL,'4','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(30,NULL,'test','2017-02-15 15:55:53','delete','vm','17854',NULL,'4','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(31,30,'test','2017-02-15 15:55:53','delete','vm','17854',NULL,'4','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(32,29,'test','2017-02-15 15:55:53','stop','instance','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc',NULL,'4','simple','foobar1/153fc256-a6cb-4586-a6c2-5c988ac1abdc','{}'),(33,NULL,'test','2017-02-15 15:55:53','stop','instance','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043',NULL,'4','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(34,NULL,'test','2017-02-15 15:55:54','delete','vm','17853',NULL,'4','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(35,34,'test','2017-02-15 15:55:54','delete','vm','17853',NULL,'4','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(36,33,'test','2017-02-15 15:55:54','stop','instance','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043',NULL,'4','simple','foobar1/2aa748ab-0a6f-4ded-8c64-37e5831ae043','{}'),(37,28,'test','2017-02-15 15:55:54','update','deployment','simple',NULL,'4','simple',NULL,'{\"before\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]},\"after\":{\"releases\":[\"bosh-release/0+dev.1\"],\"stemcells\":[\"ubuntu-stemcell/1\"]}}');
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances`
--

LOCK TABLES `instances` WRITE;
/*!40000 ALTER TABLE `instances` DISABLE KEYS */;
INSERT INTO `instances` VALUES (1,'foobar1',0,1,NULL,'detached',0,'153fc256-a6cb-4586-a6c2-5c988ac1abdc',NULL,'{}',0,1,'[\"0.foobar1.a.simple.bosh\",\"153fc256-a6cb-4586-a6c2-5c988ac1abdc.foobar1.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"foobar1\",\"templates\":[{\"name\":\"foobar\",\"version\":\"025e461e609c1596443e845f64af1d1239a1a32b\",\"sha1\":\"be95c4a20c73b85086af7229951898f7a9532167\",\"blobstore_id\":\"0d930e6c-5948-48e3-ad64-b152d6ca1475\"}],\"template\":\"foobar\",\"version\":\"025e461e609c1596443e845f64af1d1239a1a32b\",\"sha1\":\"be95c4a20c73b85086af7229951898f7a9532167\",\"blobstore_id\":\"0d930e6c-5948-48e3-ad64-b152d6ca1475\"},\"index\":0,\"bootstrap\":true,\"lifecycle\":\"service\",\"name\":\"foobar1\",\"id\":\"153fc256-a6cb-4586-a6c2-5c988ac1abdc\",\"az\":null,\"networks\":{\"a\":{\"ip\":\"192.168.1.2\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{\"bosh\":{\"password\":\"foobar\"}},\"packages\":{\"foo\":{\"name\":\"foo\",\"version\":\"0ee95716c58cf7aab3ef7301ff907118552c2dda.1\",\"sha1\":\"be24476f4099bf5beac0295853ce29fd785c15d7\",\"blobstore_id\":\"950e3ed2-bf7e-41d2-655b-632f66df87ee\"},\"bar\":{\"name\":\"bar\",\"version\":\"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1\",\"sha1\":\"41b9544c04e4f63ba15abdbab5466853be4077c6\",\"blobstore_id\":\"ea0081b0-845f-42e9-6d18-481e85632435\"}},\"properties\":{\"foobar\":{\"test_property\":1,\"drain_type\":\"static\",\"dynamic_drain_wait1\":-3,\"dynamic_drain_wait2\":-2,\"network_name\":null,\"networks\":null}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.2\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true},\"persistent_disk\":0,\"template_hashes\":{\"foobar\":\"231887a00f6b9956db540067db1dcaa64b47c73a\"},\"rendered_templates_archive\":{\"blobstore_id\":\"8abf62a1-d034-46ad-9c18-80be04f867cb\",\"sha1\":\"6ac7065964b994dbd683563a8600bcbaf14e0c00\"},\"configuration_hash\":\"5aa846467fd96bab2055eea142993604be221ac0\"}',NULL,NULL,'null',NULL,1,0),(2,'foobar1',1,1,NULL,'detached',0,'2aa748ab-0a6f-4ded-8c64-37e5831ae043',NULL,'{}',0,0,'[\"1.foobar1.a.simple.bosh\",\"2aa748ab-0a6f-4ded-8c64-37e5831ae043.foobar1.a.simple.bosh\"]','{\"deployment\":\"simple\",\"job\":{\"name\":\"foobar1\",\"templates\":[{\"name\":\"foobar\",\"version\":\"025e461e609c1596443e845f64af1d1239a1a32b\",\"sha1\":\"be95c4a20c73b85086af7229951898f7a9532167\",\"blobstore_id\":\"0d930e6c-5948-48e3-ad64-b152d6ca1475\"}],\"template\":\"foobar\",\"version\":\"025e461e609c1596443e845f64af1d1239a1a32b\",\"sha1\":\"be95c4a20c73b85086af7229951898f7a9532167\",\"blobstore_id\":\"0d930e6c-5948-48e3-ad64-b152d6ca1475\"},\"index\":1,\"bootstrap\":false,\"lifecycle\":\"service\",\"name\":\"foobar1\",\"id\":\"2aa748ab-0a6f-4ded-8c64-37e5831ae043\",\"az\":null,\"networks\":{\"a\":{\"ip\":\"192.168.1.3\",\"netmask\":\"255.255.255.0\",\"cloud_properties\":{},\"default\":[\"dns\",\"gateway\"],\"dns\":[\"192.168.1.1\",\"192.168.1.2\"],\"gateway\":\"192.168.1.1\"}},\"vm_type\":{\"name\":\"a\",\"cloud_properties\":{}},\"stemcell\":{\"name\":\"ubuntu-stemcell\",\"version\":\"1\"},\"env\":{\"bosh\":{\"password\":\"foobar\"}},\"packages\":{\"foo\":{\"name\":\"foo\",\"version\":\"0ee95716c58cf7aab3ef7301ff907118552c2dda.1\",\"sha1\":\"be24476f4099bf5beac0295853ce29fd785c15d7\",\"blobstore_id\":\"950e3ed2-bf7e-41d2-655b-632f66df87ee\"},\"bar\":{\"name\":\"bar\",\"version\":\"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1\",\"sha1\":\"41b9544c04e4f63ba15abdbab5466853be4077c6\",\"blobstore_id\":\"ea0081b0-845f-42e9-6d18-481e85632435\"}},\"properties\":{\"foobar\":{\"test_property\":1,\"drain_type\":\"static\",\"dynamic_drain_wait1\":-3,\"dynamic_drain_wait2\":-2,\"network_name\":null,\"networks\":null}},\"properties_need_filtering\":true,\"dns_domain_name\":\"bosh\",\"links\":{},\"address\":\"192.168.1.3\",\"update\":{\"canaries\":\"2\",\"max_in_flight\":\"1\",\"canary_watch_time\":\"4000-4000\",\"update_watch_time\":\"20-20\",\"serial\":true},\"persistent_disk\":0,\"template_hashes\":{\"foobar\":\"15f38cf1e13ff2ce8b2f2591f06af172d94c167c\"},\"rendered_templates_archive\":{\"blobstore_id\":\"9bfdd38b-9f7d-456c-9638-97bb60548705\",\"sha1\":\"9b159716759c2b726ddd5602dff6beb3609d79c1\"},\"configuration_hash\":\"d5b2ae227496dc0a522e347af08b369d8eac3dcf\"}',NULL,NULL,'null',NULL,1,0);
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instances_templates`
--

LOCK TABLES `instances_templates` WRITE;
/*!40000 ALTER TABLE `instances_templates` DISABLE KEYS */;
INSERT INTO `instances_templates` VALUES (1,1,4),(2,2,4);
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ip_addresses`
--

LOCK TABLES `ip_addresses` WRITE;
/*!40000 ALTER TABLE `ip_addresses` DISABLE KEYS */;
INSERT INTO `ip_addresses` VALUES (1,'a',3232235778,0,1,'2017-02-15 15:55:30','3'),(2,'a',3232235779,0,2,'2017-02-15 15:55:30','3');
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `packages`
--

LOCK TABLES `packages` WRITE;
/*!40000 ALTER TABLE `packages` DISABLE KEYS */;
INSERT INTO `packages` VALUES (1,'a','821fcd0a441062473a386e9297e9cb48b5f189f4','a6fc7b5e-b538-4254-8c59-d0fc7010ff08','50fccef5aa98f554d498b91d4eb077a0d7471d95','[\"b\"]',1,'821fcd0a441062473a386e9297e9cb48b5f189f4'),(2,'b','ec25004a81fc656a6c39871564f352d70268c637','0acc9411-665e-4228-a433-33228f3d91fa','db9a92f4fae5d0397827b0ad3f9b8c5573e1e110','[\"c\"]',1,'ec25004a81fc656a6c39871564f352d70268c637'),(3,'bar','f1267e1d4e06b60c91ef648fb9242e33ddcffa73','bd3c2003-f46a-461e-b91a-55b0f41394f5','de4ffb0afe3f3f18ab5d1a42181730faf10fd9ca','[\"foo\"]',1,'f1267e1d4e06b60c91ef648fb9242e33ddcffa73'),(4,'blocking_package','2ae8315faf952e6f69da493286387803ccfad248','27d978ab-dcb3-40ee-ad11-194e00aae4e9','30b310511517f53e5d650b683de6de4c51e29422','[]',1,'2ae8315faf952e6f69da493286387803ccfad248'),(5,'c','5bc40b65cca962dcc486673c6999d3b085b4a9ab','acf07ae5-13e8-4483-8804-7954279822ed','4db98653e2d43059c373d9ea6ef8b6c04445bddb','[]',1,'5bc40b65cca962dcc486673c6999d3b085b4a9ab'),(6,'errand1','b77c2906dd44672e9d766358ee772213f35555f2','b30bb675-b7c4-4092-a1ef-8818f48e9547','111b304d2631c7bfb7c0987b8b9cb8a4c3341e9a','[]',1,'b77c2906dd44672e9d766358ee772213f35555f2'),(7,'fails_with_too_much_output','e505f41e8cec5608209392c06950bba5d995bdd8','f600cdd4-8345-459e-98d4-94ea23df58ac','2b33bde7ae44e5a68f5ede1c8477f6f5ec9cbae0','[]',1,'e505f41e8cec5608209392c06950bba5d995bdd8'),(8,'foo','0ee95716c58cf7aab3ef7301ff907118552c2dda','453ef826-6fab-4c06-9e6b-b03c764b5918','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(9,'foo_1','0ee95716c58cf7aab3ef7301ff907118552c2dda','9f00abb7-0f27-4d3a-bfab-85118b4c5a90','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(10,'foo_10','0ee95716c58cf7aab3ef7301ff907118552c2dda','64e48f1e-9b55-4db2-8b91-6780bc44de06','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(11,'foo_2','0ee95716c58cf7aab3ef7301ff907118552c2dda','b0a74552-5731-4e0e-b5cb-f285401708e7','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(12,'foo_3','0ee95716c58cf7aab3ef7301ff907118552c2dda','35d526ad-f7c4-4b66-99ea-f47c6e450fd8','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(13,'foo_4','0ee95716c58cf7aab3ef7301ff907118552c2dda','da71771f-9d0f-4111-8906-3db4e1b7dd0d','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(14,'foo_5','0ee95716c58cf7aab3ef7301ff907118552c2dda','6521bea8-84b0-4bed-b427-ab50cd4ce1e3','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(15,'foo_6','0ee95716c58cf7aab3ef7301ff907118552c2dda','c9333d2d-f65f-44d9-b1e1-569df24d7c10','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(16,'foo_7','0ee95716c58cf7aab3ef7301ff907118552c2dda','86d4f28b-3790-4b4e-834b-abed3941da5f','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(17,'foo_8','0ee95716c58cf7aab3ef7301ff907118552c2dda','f6ee4766-bd6d-43fa-839f-a8eb6858465d','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda'),(18,'foo_9','0ee95716c58cf7aab3ef7301ff907118552c2dda','acf49197-67df-4364-9e9e-cdceafbb8d77','ff635a4694c5ad71de2433cfe77c2334583d1c7a','[]',1,'0ee95716c58cf7aab3ef7301ff907118552c2dda');
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
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;
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
  PRIMARY KEY (`id`),
  UNIQUE KEY `disk_cid` (`disk_cid`),
  KEY `instance_id` (`instance_id`),
  CONSTRAINT `persistent_disks_ibfk_1` FOREIGN KEY (`instance_id`) REFERENCES `instances` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `records`
--

LOCK TABLES `records` WRITE;
/*!40000 ALTER TABLE `records` DISABLE KEYS */;
INSERT INTO `records` VALUES (1,'bosh','SOA','localhost hostmaster@localhost 0 10800 604800 30',300,NULL,1487174152,1),(2,'bosh','NS','ns.bosh',14400,NULL,1487174152,1),(3,'ns.bosh','A',NULL,18000,NULL,1487174152,1),(4,'0.foobar1.a.simple.bosh','A','192.168.1.2',300,NULL,1487174137,1),(5,'1.168.192.in-addr.arpa','SOA','localhost hostmaster@localhost 0 10800 604800 30',14400,NULL,NULL,2),(6,'1.168.192.in-addr.arpa','NS','ns.bosh',14400,NULL,NULL,2),(7,'2.1.168.192.in-addr.arpa','PTR','0.foobar1.a.simple.bosh',300,NULL,1487174137,2),(8,'153fc256-a6cb-4586-a6c2-5c988ac1abdc.foobar1.a.simple.bosh','A','192.168.1.2',300,NULL,1487174137,1),(9,'2.1.168.192.in-addr.arpa','PTR','153fc256-a6cb-4586-a6c2-5c988ac1abdc.foobar1.a.simple.bosh',300,NULL,1487174137,2),(10,'1.foobar1.a.simple.bosh','A','192.168.1.3',300,NULL,1487174144,1),(11,'3.1.168.192.in-addr.arpa','PTR','1.foobar1.a.simple.bosh',300,NULL,1487174144,2),(12,'2aa748ab-0a6f-4ded-8c64-37e5831ae043.foobar1.a.simple.bosh','A','192.168.1.3',300,NULL,1487174144,1),(13,'3.1.168.192.in-addr.arpa','PTR','2aa748ab-0a6f-4ded-8c64-37e5831ae043.foobar1.a.simple.bosh',300,NULL,1487174144,2);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions`
--

LOCK TABLES `release_versions` WRITE;
/*!40000 ALTER TABLE `release_versions` DISABLE KEYS */;
INSERT INTO `release_versions` VALUES (1,'0+dev.1',1,'b8f50f4f',0);
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
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `release_versions_templates`
--

LOCK TABLES `release_versions_templates` WRITE;
/*!40000 ALTER TABLE `release_versions_templates` DISABLE KEYS */;
INSERT INTO `release_versions_templates` VALUES (1,1,1),(2,1,2),(3,1,3),(4,1,4),(5,1,5),(6,1,6),(7,1,7),(8,1,8),(9,1,9),(10,1,10),(11,1,11),(12,1,12),(13,1,13),(14,1,14),(15,1,15),(16,1,16),(17,1,17),(18,1,18),(19,1,19),(20,1,20),(21,1,21),(22,1,22);
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rendered_templates_archives`
--

LOCK TABLES `rendered_templates_archives` WRITE;
/*!40000 ALTER TABLE `rendered_templates_archives` DISABLE KEYS */;
INSERT INTO `rendered_templates_archives` VALUES (1,1,'8abf62a1-d034-46ad-9c18-80be04f867cb','6ac7065964b994dbd683563a8600bcbaf14e0c00','5aa846467fd96bab2055eea142993604be221ac0','2017-02-15 15:55:30'),(2,2,'9bfdd38b-9f7d-456c-9638-97bb60548705','9b159716759c2b726ddd5602dff6beb3609d79c1','d5b2ae227496dc0a522e347af08b369d8eac3dcf','2017-02-15 15:55:30');
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (1,'done','2017-02-15 15:55:24','create release','Created release \'bosh-release/0+dev.1\'','/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-17440/sandbox/boshdir/tasks/1','2017-02-15 15:55:23','update_release','test',NULL,'2017-02-15 15:55:23'),(2,'done','2017-02-15 15:55:26','create stemcell','/stemcells/ubuntu-stemcell/1','/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-17440/sandbox/boshdir/tasks/2','2017-02-15 15:55:26','update_stemcell','test',NULL,'2017-02-15 15:55:26'),(3,'done','2017-02-15 15:55:50','create deployment','/deployments/simple','/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-17440/sandbox/boshdir/tasks/3','2017-02-15 15:55:29','update_deployment','test','simple','2017-02-15 15:55:29'),(4,'done','2017-02-15 15:55:54','create deployment','/deployments/simple','/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-17440/sandbox/boshdir/tasks/4','2017-02-15 15:55:52','update_deployment','test','simple','2017-02-15 15:55:52');
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `templates`
--

LOCK TABLES `templates` WRITE;
/*!40000 ALTER TABLE `templates` DISABLE KEYS */;
INSERT INTO `templates` VALUES (1,'errand1','7f328d7a3dc4ab55246ca3e61552a00d7e29bc1d','f9d6b1b4-0611-4ff4-bcca-9bdfb71fc22f','fb80a05d5a7ede5f57390e7290cc5e16628b9eb2','[\"errand1\"]',1,'null','7f328d7a3dc4ab55246ca3e61552a00d7e29bc1d','{\"errand1.stdout\":{\"description\":\"Stdout to print from the errand script\",\"default\":\"errand1-stdout\"},\"errand1.stdout_multiplier\":{\"description\":\"Number of times stdout will be repeated in the output\",\"default\":1},\"errand1.stderr\":{\"description\":\"Stderr to print from the errand script\",\"default\":\"errand1-stderr\"},\"errand1.stderr_multiplier\":{\"description\":\"Number of times stderr will be repeated in the output\",\"default\":1},\"errand1.run_package_file\":{\"description\":\"Should bin/run run script from errand1 package to show that package is present on the vm\",\"default\":false},\"errand1.exit_code\":{\"description\":\"Exit code to return from the errand script\",\"default\":0},\"errand1.blocking_errand\":{\"description\":\"Whether to block errand execution\",\"default\":false},\"errand1.logs.stdout\":{\"description\":\"Output to place into sys/log/errand1/stdout.log\",\"default\":\"errand1-stdout-log\"},\"errand1.logs.custom\":{\"description\":\"Output to place into sys/log/custom.log\",\"default\":\"errand1-custom-log\"}}',NULL,NULL),(2,'errand_without_package','46355c83cafbe162d99bb46a53006b7a52f677b6','4fe34168-ef9d-4688-bfbc-12365a34b34e','b0282cee559057de95e2e1084e80227a4f072b76','[]',1,'null','46355c83cafbe162d99bb46a53006b7a52f677b6','{}',NULL,NULL),(3,'fails_with_too_much_output','a1667f8047671c33bc75ba5163b5626407cf5a22','6b799e96-4e27-4465-b43e-85d6fe5c3edb','e59623c16352cee7cc0bddbd78215a7baeb5815c','[\"fails_with_too_much_output\"]',1,'null','a1667f8047671c33bc75ba5163b5626407cf5a22','{}',NULL,NULL),(4,'foobar','025e461e609c1596443e845f64af1d1239a1a32b','0d930e6c-5948-48e3-ad64-b152d6ca1475','be95c4a20c73b85086af7229951898f7a9532167','[\"foo\",\"bar\"]',1,'null','025e461e609c1596443e845f64af1d1239a1a32b','{\"test_property\":{\"description\":\"A test property\",\"default\":1},\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"dynamic_drain_wait1\":{\"description\":\"Number of seconds to wait when drain script is first called\",\"default\":-3},\"dynamic_drain_wait2\":{\"description\":\"Number of seconds to wait when drain script is called a second time\",\"default\":-2},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}',NULL,NULL),(5,'foobar_with_bad_properties','a61cb7a7ed77e9535ebd20f931b492a8e9997830','8c28ff5d-10c9-4ce3-a7f0-864134caaeb1','badebf1e07b0999c74f33f1e2ea5d293155ca16d','[\"foo\",\"bar\"]',1,'null','a61cb7a7ed77e9535ebd20f931b492a8e9997830','{\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}',NULL,NULL),(6,'foobar_with_bad_properties_2','99f3d044ad5d4dcfa23dce45e165edf7ac248225','7b37e10e-8058-4664-82f1-c5664a777ba5','390b5efcec26d79e9330048040d4f0d5f299dea9','[\"foo\",\"bar\"]',1,'null','99f3d044ad5d4dcfa23dce45e165edf7ac248225','{\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"},\"networks\":{\"description\":\"All networks\"}}',NULL,NULL),(7,'foobar_without_packages','6cb4d446ecb1c0ac8cfa8e099873114f29c20ea8','9e7404ef-70d8-4fd1-8e3f-e56d418026d4','51d7a6ca99881bb769f311d174cac5439bbe0800','[]',1,'null','6cb4d446ecb1c0ac8cfa8e099873114f29c20ea8','{}',NULL,NULL),(8,'has_drain_script','ef4301ef90caf2aa524b68aba7ff7653a194a8b8','f0755f96-bb26-4026-9966-da8120049dc6','137a5eb3554d99e76a3e254092477d51d3b9f8fe','[\"foo\",\"bar\"]',1,'null','ef4301ef90caf2aa524b68aba7ff7653a194a8b8','{\"test_property\":{\"description\":\"A test property\",\"default\":1},\"drain_type\":{\"description\":\"Used in drain script to trigger dynamic vs static drain behavior\",\"default\":\"static\"},\"dynamic_drain_wait1\":{\"description\":\"Number of seconds to wait when drain script is first called\",\"default\":-3},\"dynamic_drain_wait2\":{\"description\":\"Number of seconds to wait when drain script is called a second time\",\"default\":-2},\"network_name\":{\"description\":\"Network name used for determining printed IP address\"}}',NULL,NULL),(9,'id_job','03639fea005823b43a511fe788f796fca1c9ff56','8077f5e1-a435-401c-97ae-69d161a62b16','73f559691e63b3168c467e65174165dbe76e7e5b','[]',1,'null','03639fea005823b43a511fe788f796fca1c9ff56','{}',NULL,NULL),(10,'job_1_with_many_properties','383c1f964898cdd3d6ab108857aa00145f371004','5d5c4429-97cf-4fe6-9cd7-ba07bd3183e7','6e9a57fc9b4428599522795e2f3aecc58c138851','[]',1,'null','383c1f964898cdd3d6ab108857aa00145f371004','{\"smurfs.color\":{\"description\":\"The color of the smurfs\",\"default\":\"blue\"},\"gargamel.color\":{\"description\":\"The color of gargamel it is required\"}}',NULL,NULL),(11,'job_1_with_post_deploy_script','7aaaaf94f16bd171602f67b17c5a3222b5476215','ce29c218-49ab-4fba-9758-199033b7e207','27742cb1d86388424cac678fca599172375c49f6','[]',1,'null','7aaaaf94f16bd171602f67b17c5a3222b5476215','{\"post_deploy_message_1\":{\"description\":\"A message echoed by the post-deploy script 1\",\"default\":\"this is post_deploy_message_1\"}}',NULL,NULL),(12,'job_1_with_pre_start_script','551696c571b5e6d120567be5a2dc42eb23be9de7','c87f5570-068c-46ef-836a-d593f4956128','677335e5faa092f8c0dfb18e34db0ac79db027ea','[]',1,'null','551696c571b5e6d120567be5a2dc42eb23be9de7','{\"pre_start_message_1\":{\"description\":\"A message echoed by the pre-start script 1\",\"default\":\"this is pre_start_message_1\"}}',NULL,NULL),(13,'job_2_with_many_properties','7ae8ba20811b57b75dfb8ad525149aaa01f38df6','34d5f55f-fc86-4aa1-9c08-cd03f84ae386','1306e864266eea012451b668c50d4d23c9c0ad2c','[]',1,'null','7ae8ba20811b57b75dfb8ad525149aaa01f38df6','{\"smurfs.color\":{\"description\":\"The color of the smurfs\",\"default\":\"blue\"},\"gargamel.color\":{\"description\":\"The color of gargamel it is required\"}}',NULL,NULL),(14,'job_2_with_post_deploy_script','a4e8beab4bd8d6dee0110eb9e902593b8355d648','3c864a67-e66d-4ca3-9a37-f6fc746c4c36','a848e5091e5e9daba855f72ac670b03a666cac21','[]',1,'null','a4e8beab4bd8d6dee0110eb9e902593b8355d648','{}',NULL,NULL),(15,'job_2_with_pre_start_script','48cbe195e05f7932448f67614ac945f7123f9468','1a00ca56-e86d-4fa9-b2af-96d978b0791e','a781f9ed9b712e20ff289a42fb64dc0662abab4c','[]',1,'null','48cbe195e05f7932448f67614ac945f7123f9468','{}',NULL,NULL),(16,'job_3_with_broken_post_deploy_script','a9556deadf132fffc4e748a2ba3cbf608a78ea9b','3a6a7d54-d23e-40f2-bc57-8444d38c4d5b','e61e33a2aae549485c4b4d6fc16c9667f30e9ec6','[]',1,'null','a9556deadf132fffc4e748a2ba3cbf608a78ea9b','{}',NULL,NULL),(17,'job_that_modifies_properties','4f0d51063f726d82de480cc5e2ce34ffbf2197c3','d844e86b-aa54-4155-a219-7676c9d40796','e333c2c63e206a6834fbee678691e951beb21f88','[\"foo\",\"bar\"]',1,'null','4f0d51063f726d82de480cc5e2ce34ffbf2197c3','{\"some_namespace.test_property\":{\"description\":\"A test property\",\"default\":1}}',NULL,NULL),(18,'job_with_blocking_compilation','e3196092c9350a8fb8e05adae02f863ef90620a3','d2bab46a-f27b-4052-bd36-2c00329071e1','a7a94967722921d1b2ab1438c8d9f965c2186432','[\"blocking_package\"]',1,'null','e3196092c9350a8fb8e05adae02f863ef90620a3','{}',NULL,NULL),(19,'job_with_many_packages','baca495de93c403ff7a0b4536cb808713ce5a6e3','7686bac0-494d-42dd-84b5-733e80ce3104','e3791c25f54e59d610e3c37b9d3431e74ebe418e','[\"foo_1\",\"foo_2\",\"foo_3\",\"foo_4\",\"foo_5\",\"foo_6\",\"foo_7\",\"foo_8\",\"foo_9\",\"foo_10\"]',1,'null','baca495de93c403ff7a0b4536cb808713ce5a6e3','{}',NULL,NULL),(20,'job_with_post_start_script','0965c83e1af2d0cdbfabf21bcd4808d142e2a7a5','6ba41b29-f643-41e0-8ca2-3aa529800772','cd37ad6a89c593a77e3a1ed9615e9b92e06b703a','[]',1,'null','0965c83e1af2d0cdbfabf21bcd4808d142e2a7a5','{\"post_start_message\":{\"description\":\"A message echoed by the post-start script\",\"default\":\"this is post_start_message\"},\"job_pidfile\":{\"description\":\"Path to jobs pid file\",\"default\":\"/var/vcap/sys/run/job_with_post_start_script.pid\"},\"exit_code\":{\"default\":0}}',NULL,NULL),(21,'job_with_property_types','19e3428b15aa041130d26edf679c01829f5f79be','c3890542-c199-4067-b895-b284de40b5ca','ba4f3652167a7b5126d5ee3f676855427ac9013e','[]',1,'null','19e3428b15aa041130d26edf679c01829f5f79be','{\"smurfs.phone_password\":{\"description\":\"The phone password of the smurfs village\",\"type\":\"password\"},\"smurfs.happiness_level\":{\"description\":\"The level of the Smurfs overall happiness\",\"type\":\"happy\"},\"gargamel.secret_recipe\":{\"description\":\"The secret recipe of gargamel to take down the smurfs\",\"type\":\"password\"},\"gargamel.password\":{\"description\":\"The password I used for everything\",\"default\":\"abc123\",\"type\":\"password\"},\"gargamel.cert\":{\"description\":\"The certificate used for everything\",\"type\":\"certificate\"},\"gargamel.hard_coded_cert\":{\"description\":\"The hardcoded cert of gargamel\",\"default\":\"good luck hardcoding certs and private keys\",\"type\":\"certificate\"}}',NULL,NULL),(22,'transitive_deps','8020351635287d3158b65b50f8c728e71051c8a7','c0752595-d3d4-4dc8-9258-61c6bb0dabad','1ca05f243169beca588e13686030de016040c5c5','[\"a\"]',1,'null','8020351635287d3158b65b50f8c728e71051c8a7','{}',NULL,NULL);
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
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

-- Dump completed on 2017-02-15 16:00:54
