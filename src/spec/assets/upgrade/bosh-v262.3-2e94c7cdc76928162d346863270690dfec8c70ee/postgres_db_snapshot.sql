--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.12
-- Dumped by pg_dump version 9.6.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: agent_dns_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE agent_dns_versions (
    id bigint NOT NULL,
    agent_id text NOT NULL,
    dns_version bigint DEFAULT 0 NOT NULL
);


ALTER TABLE agent_dns_versions OWNER TO postgres;

--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE agent_dns_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE agent_dns_versions_id_seq OWNER TO postgres;

--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE agent_dns_versions_id_seq OWNED BY agent_dns_versions.id;


--
-- Name: blobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE blobs (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    type text
);


ALTER TABLE blobs OWNER TO postgres;

--
-- Name: cloud_configs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE cloud_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE cloud_configs OWNER TO postgres;

--
-- Name: cloud_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cloud_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cloud_configs_id_seq OWNER TO postgres;

--
-- Name: cloud_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cloud_configs_id_seq OWNED BY cloud_configs.id;


--
-- Name: compiled_packages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE compiled_packages (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    dependency_key text NOT NULL,
    build integer NOT NULL,
    package_id integer NOT NULL,
    dependency_key_sha1 text NOT NULL,
    stemcell_os text,
    stemcell_version text
);


ALTER TABLE compiled_packages OWNER TO postgres;

--
-- Name: compiled_packages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE compiled_packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compiled_packages_id_seq OWNER TO postgres;

--
-- Name: compiled_packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE compiled_packages_id_seq OWNED BY compiled_packages.id;


--
-- Name: cpi_configs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE cpi_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE cpi_configs OWNER TO postgres;

--
-- Name: cpi_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cpi_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cpi_configs_id_seq OWNER TO postgres;

--
-- Name: cpi_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cpi_configs_id_seq OWNED BY cpi_configs.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by text,
    queue text
);


ALTER TABLE delayed_jobs OWNER TO postgres;

--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delayed_jobs_id_seq OWNER TO postgres;

--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE delayed_jobs_id_seq OWNED BY delayed_jobs.id;


--
-- Name: deployment_problems; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployment_problems (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    state text NOT NULL,
    resource_id integer NOT NULL,
    type text NOT NULL,
    data_json text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    last_seen_at timestamp without time zone NOT NULL,
    counter integer DEFAULT 0 NOT NULL
);


ALTER TABLE deployment_problems OWNER TO postgres;

--
-- Name: deployment_problems_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deployment_problems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deployment_problems_id_seq OWNER TO postgres;

--
-- Name: deployment_problems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deployment_problems_id_seq OWNED BY deployment_problems.id;


--
-- Name: deployment_properties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployment_properties (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    name text NOT NULL,
    value text NOT NULL
);


ALTER TABLE deployment_properties OWNER TO postgres;

--
-- Name: deployment_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deployment_properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deployment_properties_id_seq OWNER TO postgres;

--
-- Name: deployment_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deployment_properties_id_seq OWNED BY deployment_properties.id;


--
-- Name: deployments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployments (
    id integer NOT NULL,
    name text NOT NULL,
    manifest text,
    cloud_config_id integer,
    link_spec_json text
);


ALTER TABLE deployments OWNER TO postgres;

--
-- Name: deployments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deployments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deployments_id_seq OWNER TO postgres;

--
-- Name: deployments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deployments_id_seq OWNED BY deployments.id;


--
-- Name: deployments_release_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployments_release_versions (
    id integer NOT NULL,
    release_version_id integer NOT NULL,
    deployment_id integer NOT NULL
);


ALTER TABLE deployments_release_versions OWNER TO postgres;

--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deployments_release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deployments_release_versions_id_seq OWNER TO postgres;

--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deployments_release_versions_id_seq OWNED BY deployments_release_versions.id;


--
-- Name: deployments_runtime_configs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployments_runtime_configs (
    deployment_id integer NOT NULL,
    runtime_config_id integer NOT NULL
);


ALTER TABLE deployments_runtime_configs OWNER TO postgres;

--
-- Name: deployments_stemcells; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployments_stemcells (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    stemcell_id integer NOT NULL
);


ALTER TABLE deployments_stemcells OWNER TO postgres;

--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deployments_stemcells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE deployments_stemcells_id_seq OWNER TO postgres;

--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deployments_stemcells_id_seq OWNED BY deployments_stemcells.id;


--
-- Name: deployments_teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE deployments_teams (
    deployment_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE deployments_teams OWNER TO postgres;

--
-- Name: director_attributes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE director_attributes (
    value text,
    name text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE director_attributes OWNER TO postgres;

--
-- Name: director_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE director_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE director_attributes_id_seq OWNER TO postgres;

--
-- Name: director_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE director_attributes_id_seq OWNED BY director_attributes.id;


--
-- Name: dns_schema; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE dns_schema (
    filename text NOT NULL
);


ALTER TABLE dns_schema OWNER TO postgres;

--
-- Name: domains; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE domains (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    master character varying(128) DEFAULT NULL::character varying,
    last_check integer,
    type character varying(6) NOT NULL,
    notified_serial integer,
    account character varying(40) DEFAULT NULL::character varying
);


ALTER TABLE domains OWNER TO postgres;

--
-- Name: domains_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE domains_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE domains_id_seq OWNER TO postgres;

--
-- Name: domains_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE domains_id_seq OWNED BY domains.id;


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ephemeral_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ephemeral_blobs_id_seq OWNER TO postgres;

--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ephemeral_blobs_id_seq OWNED BY blobs.id;


--
-- Name: errand_runs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE errand_runs (
    id integer NOT NULL,
    successful boolean DEFAULT false,
    successful_configuration_hash character varying(512),
    successful_packages_spec text,
    instance_id integer NOT NULL
);


ALTER TABLE errand_runs OWNER TO postgres;

--
-- Name: errand_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE errand_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE errand_runs_id_seq OWNER TO postgres;

--
-- Name: errand_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE errand_runs_id_seq OWNED BY errand_runs.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE events (
    id bigint NOT NULL,
    parent_id bigint,
    "user" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    action text NOT NULL,
    object_type text NOT NULL,
    object_name text,
    error text,
    task text,
    deployment text,
    instance text,
    context_json text
);


ALTER TABLE events OWNER TO postgres;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE events_id_seq OWNER TO postgres;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE events_id_seq OWNED BY events.id;


--
-- Name: instances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE instances (
    id integer NOT NULL,
    job text NOT NULL,
    index integer NOT NULL,
    deployment_id integer NOT NULL,
    state text NOT NULL,
    resurrection_paused boolean DEFAULT false,
    uuid text,
    availability_zone text,
    cloud_properties text,
    compilation boolean DEFAULT false,
    bootstrap boolean DEFAULT false,
    dns_records text,
    spec_json text,
    vm_cid_bak text,
    agent_id_bak text,
    credentials_json_bak text,
    trusted_certs_sha1_bak text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    update_completed boolean DEFAULT false,
    ignore boolean DEFAULT false,
    variable_set_id integer NOT NULL
);


ALTER TABLE instances OWNER TO postgres;

--
-- Name: instances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE instances_id_seq OWNER TO postgres;

--
-- Name: instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE instances_id_seq OWNED BY instances.id;


--
-- Name: instances_templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE instances_templates (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    template_id integer NOT NULL
);


ALTER TABLE instances_templates OWNER TO postgres;

--
-- Name: instances_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE instances_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE instances_templates_id_seq OWNER TO postgres;

--
-- Name: instances_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE instances_templates_id_seq OWNED BY instances_templates.id;


--
-- Name: ip_addresses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ip_addresses (
    id integer NOT NULL,
    network_name text,
    address bigint,
    static boolean,
    instance_id integer,
    created_at timestamp without time zone,
    task_id text
);


ALTER TABLE ip_addresses OWNER TO postgres;

--
-- Name: ip_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ip_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ip_addresses_id_seq OWNER TO postgres;

--
-- Name: ip_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ip_addresses_id_seq OWNED BY ip_addresses.id;


--
-- Name: local_dns_blobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE local_dns_blobs (
    id bigint NOT NULL,
    blob_id integer NOT NULL,
    version bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE local_dns_blobs OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_blobs_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_blobs_id_seq1 OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_blobs_id_seq1 OWNED BY local_dns_blobs.id;


--
-- Name: local_dns_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE local_dns_records (
    id bigint NOT NULL,
    ip text NOT NULL,
    az text,
    instance_group text,
    network text,
    deployment text,
    instance_id integer,
    agent_id text,
    domain text
);


ALTER TABLE local_dns_records OWNER TO postgres;

--
-- Name: local_dns_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_records_id_seq OWNER TO postgres;

--
-- Name: local_dns_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_records_id_seq OWNED BY local_dns_records.id;


--
-- Name: locks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE locks (
    id integer NOT NULL,
    expired_at timestamp without time zone NOT NULL,
    name text NOT NULL,
    uid text NOT NULL
);


ALTER TABLE locks OWNER TO postgres;

--
-- Name: locks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE locks_id_seq OWNER TO postgres;

--
-- Name: locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE locks_id_seq OWNED BY locks.id;


--
-- Name: log_bundles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE log_bundles (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
);


ALTER TABLE log_bundles OWNER TO postgres;

--
-- Name: log_bundles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE log_bundles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE log_bundles_id_seq OWNER TO postgres;

--
-- Name: log_bundles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE log_bundles_id_seq OWNED BY log_bundles.id;


--
-- Name: orphan_disks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orphan_disks (
    id integer NOT NULL,
    disk_cid text NOT NULL,
    size integer,
    availability_zone text,
    deployment_name text NOT NULL,
    instance_name text NOT NULL,
    cloud_properties_json text,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE orphan_disks OWNER TO postgres;

--
-- Name: orphan_disks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orphan_disks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orphan_disks_id_seq OWNER TO postgres;

--
-- Name: orphan_disks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orphan_disks_id_seq OWNED BY orphan_disks.id;


--
-- Name: orphan_snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orphan_snapshots (
    id integer NOT NULL,
    orphan_disk_id integer NOT NULL,
    snapshot_cid text NOT NULL,
    clean boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    snapshot_created_at timestamp without time zone
);


ALTER TABLE orphan_snapshots OWNER TO postgres;

--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orphan_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orphan_snapshots_id_seq OWNER TO postgres;

--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orphan_snapshots_id_seq OWNED BY orphan_snapshots.id;


--
-- Name: packages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE packages (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    blobstore_id text,
    sha1 text,
    dependency_set_json text NOT NULL,
    release_id integer NOT NULL,
    fingerprint text
);


ALTER TABLE packages OWNER TO postgres;

--
-- Name: packages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE packages_id_seq OWNER TO postgres;

--
-- Name: packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE packages_id_seq OWNED BY packages.id;


--
-- Name: packages_release_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE packages_release_versions (
    id integer NOT NULL,
    package_id integer NOT NULL,
    release_version_id integer NOT NULL
);


ALTER TABLE packages_release_versions OWNER TO postgres;

--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE packages_release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE packages_release_versions_id_seq OWNER TO postgres;

--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE packages_release_versions_id_seq OWNED BY packages_release_versions.id;


--
-- Name: persistent_disks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE persistent_disks (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    disk_cid text NOT NULL,
    size integer,
    active boolean DEFAULT false,
    cloud_properties_json text,
    name text DEFAULT ''::text
);


ALTER TABLE persistent_disks OWNER TO postgres;

--
-- Name: persistent_disks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE persistent_disks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE persistent_disks_id_seq OWNER TO postgres;

--
-- Name: persistent_disks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE persistent_disks_id_seq OWNED BY persistent_disks.id;


--
-- Name: records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE records (
    id integer NOT NULL,
    name character varying(255) DEFAULT NULL::character varying,
    type character varying(10) DEFAULT NULL::character varying,
    content character varying(4098) DEFAULT NULL::character varying,
    ttl integer,
    prio integer,
    change_date integer,
    domain_id integer
);


ALTER TABLE records OWNER TO postgres;

--
-- Name: records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE records_id_seq OWNER TO postgres;

--
-- Name: records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE records_id_seq OWNED BY records.id;


--
-- Name: release_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE release_versions (
    id integer NOT NULL,
    version text NOT NULL,
    release_id integer NOT NULL,
    commit_hash text DEFAULT 'unknown'::text,
    uncommitted_changes boolean DEFAULT false
);


ALTER TABLE release_versions OWNER TO postgres;

--
-- Name: release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE release_versions_id_seq OWNER TO postgres;

--
-- Name: release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE release_versions_id_seq OWNED BY release_versions.id;


--
-- Name: release_versions_templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE release_versions_templates (
    id integer NOT NULL,
    release_version_id integer NOT NULL,
    template_id integer NOT NULL
);


ALTER TABLE release_versions_templates OWNER TO postgres;

--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE release_versions_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE release_versions_templates_id_seq OWNER TO postgres;

--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE release_versions_templates_id_seq OWNED BY release_versions_templates.id;


--
-- Name: releases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE releases (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE releases OWNER TO postgres;

--
-- Name: releases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE releases_id_seq OWNER TO postgres;

--
-- Name: releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE releases_id_seq OWNED BY releases.id;


--
-- Name: rendered_templates_archives; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE rendered_templates_archives (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    content_sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE rendered_templates_archives OWNER TO postgres;

--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE rendered_templates_archives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rendered_templates_archives_id_seq OWNER TO postgres;

--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE rendered_templates_archives_id_seq OWNED BY rendered_templates_archives.id;


--
-- Name: runtime_configs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE runtime_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL,
    name text DEFAULT ''::text NOT NULL
);


ALTER TABLE runtime_configs OWNER TO postgres;

--
-- Name: runtime_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE runtime_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE runtime_configs_id_seq OWNER TO postgres;

--
-- Name: runtime_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE runtime_configs_id_seq OWNED BY runtime_configs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE schema_migrations (
    filename text NOT NULL
);


ALTER TABLE schema_migrations OWNER TO postgres;

--
-- Name: snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE snapshots (
    id integer NOT NULL,
    persistent_disk_id integer NOT NULL,
    clean boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    snapshot_cid text NOT NULL
);


ALTER TABLE snapshots OWNER TO postgres;

--
-- Name: snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE snapshots_id_seq OWNER TO postgres;

--
-- Name: snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE snapshots_id_seq OWNED BY snapshots.id;


--
-- Name: stemcells; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE stemcells (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    cid text NOT NULL,
    sha1 text,
    operating_system text,
    cpi text DEFAULT ''::text
);


ALTER TABLE stemcells OWNER TO postgres;

--
-- Name: stemcells_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE stemcells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE stemcells_id_seq OWNER TO postgres;

--
-- Name: stemcells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE stemcells_id_seq OWNED BY stemcells.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tasks (
    id integer NOT NULL,
    state text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    description text NOT NULL,
    result text,
    output text,
    checkpoint_time timestamp without time zone,
    type text NOT NULL,
    username text,
    deployment_name text,
    started_at timestamp without time zone,
    event_output text,
    result_output text,
    context_id character varying(64) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE tasks OWNER TO postgres;

--
-- Name: tasks_new_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tasks_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tasks_new_id_seq OWNER TO postgres;

--
-- Name: tasks_new_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tasks_new_id_seq OWNED BY tasks.id;


--
-- Name: tasks_teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tasks_teams (
    task_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE tasks_teams OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE teams (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE teams OWNER TO postgres;

--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE teams_id_seq OWNER TO postgres;

--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE teams_id_seq OWNED BY teams.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE templates (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    package_names_json text NOT NULL,
    release_id integer NOT NULL,
    logs_json text,
    fingerprint text,
    properties_json text,
    consumes_json text,
    provides_json text
);


ALTER TABLE templates OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE templates_id_seq OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE templates_id_seq OWNED BY templates.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users (
    id integer NOT NULL,
    username text NOT NULL,
    password text NOT NULL
);


ALTER TABLE users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: variable_sets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE variable_sets (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deployed_successfully boolean DEFAULT false,
    writable boolean DEFAULT false
);


ALTER TABLE variable_sets OWNER TO postgres;

--
-- Name: variable_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE variable_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE variable_sets_id_seq OWNER TO postgres;

--
-- Name: variable_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE variable_sets_id_seq OWNED BY variable_sets.id;


--
-- Name: variables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE variables (
    id integer NOT NULL,
    variable_id text NOT NULL,
    variable_name text NOT NULL,
    variable_set_id integer NOT NULL,
    is_local boolean DEFAULT true,
    provider_deployment text DEFAULT ''::text
);


ALTER TABLE variables OWNER TO postgres;

--
-- Name: variables_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE variables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE variables_id_seq OWNER TO postgres;

--
-- Name: variables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE variables_id_seq OWNED BY variables.id;


--
-- Name: vms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vms (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    agent_id text,
    cid text,
    credentials_json text,
    trusted_certs_sha1 text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    active boolean DEFAULT false
);


ALTER TABLE vms OWNER TO postgres;

--
-- Name: vms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE vms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vms_id_seq OWNER TO postgres;

--
-- Name: vms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE vms_id_seq OWNED BY vms.id;


--
-- Name: agent_dns_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY agent_dns_versions ALTER COLUMN id SET DEFAULT nextval('agent_dns_versions_id_seq'::regclass);


--
-- Name: blobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY blobs ALTER COLUMN id SET DEFAULT nextval('ephemeral_blobs_id_seq'::regclass);


--
-- Name: cloud_configs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cloud_configs ALTER COLUMN id SET DEFAULT nextval('cloud_configs_id_seq'::regclass);


--
-- Name: compiled_packages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages ALTER COLUMN id SET DEFAULT nextval('compiled_packages_id_seq'::regclass);


--
-- Name: cpi_configs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cpi_configs ALTER COLUMN id SET DEFAULT nextval('cpi_configs_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


--
-- Name: deployment_problems id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems ALTER COLUMN id SET DEFAULT nextval('deployment_problems_id_seq'::regclass);


--
-- Name: deployment_properties id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties ALTER COLUMN id SET DEFAULT nextval('deployment_properties_id_seq'::regclass);


--
-- Name: deployments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments ALTER COLUMN id SET DEFAULT nextval('deployments_id_seq'::regclass);


--
-- Name: deployments_release_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions ALTER COLUMN id SET DEFAULT nextval('deployments_release_versions_id_seq'::regclass);


--
-- Name: deployments_stemcells id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells ALTER COLUMN id SET DEFAULT nextval('deployments_stemcells_id_seq'::regclass);


--
-- Name: director_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY director_attributes ALTER COLUMN id SET DEFAULT nextval('director_attributes_id_seq'::regclass);


--
-- Name: domains id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains ALTER COLUMN id SET DEFAULT nextval('domains_id_seq'::regclass);


--
-- Name: errand_runs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs ALTER COLUMN id SET DEFAULT nextval('errand_runs_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);


--
-- Name: instances id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances ALTER COLUMN id SET DEFAULT nextval('instances_id_seq'::regclass);


--
-- Name: instances_templates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates ALTER COLUMN id SET DEFAULT nextval('instances_templates_id_seq'::regclass);


--
-- Name: ip_addresses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses ALTER COLUMN id SET DEFAULT nextval('ip_addresses_id_seq'::regclass);


--
-- Name: local_dns_blobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs ALTER COLUMN id SET DEFAULT nextval('local_dns_blobs_id_seq1'::regclass);


--
-- Name: local_dns_records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records ALTER COLUMN id SET DEFAULT nextval('local_dns_records_id_seq'::regclass);


--
-- Name: locks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks ALTER COLUMN id SET DEFAULT nextval('locks_id_seq'::regclass);


--
-- Name: log_bundles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles ALTER COLUMN id SET DEFAULT nextval('log_bundles_id_seq'::regclass);


--
-- Name: orphan_disks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks ALTER COLUMN id SET DEFAULT nextval('orphan_disks_id_seq'::regclass);


--
-- Name: orphan_snapshots id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots ALTER COLUMN id SET DEFAULT nextval('orphan_snapshots_id_seq'::regclass);


--
-- Name: packages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages ALTER COLUMN id SET DEFAULT nextval('packages_id_seq'::regclass);


--
-- Name: packages_release_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions ALTER COLUMN id SET DEFAULT nextval('packages_release_versions_id_seq'::regclass);


--
-- Name: persistent_disks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks ALTER COLUMN id SET DEFAULT nextval('persistent_disks_id_seq'::regclass);


--
-- Name: records id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records ALTER COLUMN id SET DEFAULT nextval('records_id_seq'::regclass);


--
-- Name: release_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions ALTER COLUMN id SET DEFAULT nextval('release_versions_id_seq'::regclass);


--
-- Name: release_versions_templates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates ALTER COLUMN id SET DEFAULT nextval('release_versions_templates_id_seq'::regclass);


--
-- Name: releases id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases ALTER COLUMN id SET DEFAULT nextval('releases_id_seq'::regclass);


--
-- Name: rendered_templates_archives id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives ALTER COLUMN id SET DEFAULT nextval('rendered_templates_archives_id_seq'::regclass);


--
-- Name: runtime_configs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY runtime_configs ALTER COLUMN id SET DEFAULT nextval('runtime_configs_id_seq'::regclass);


--
-- Name: snapshots id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots ALTER COLUMN id SET DEFAULT nextval('snapshots_id_seq'::regclass);


--
-- Name: stemcells id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells ALTER COLUMN id SET DEFAULT nextval('stemcells_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks ALTER COLUMN id SET DEFAULT nextval('tasks_new_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams ALTER COLUMN id SET DEFAULT nextval('teams_id_seq'::regclass);


--
-- Name: templates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates ALTER COLUMN id SET DEFAULT nextval('templates_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: variable_sets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variable_sets ALTER COLUMN id SET DEFAULT nextval('variable_sets_id_seq'::regclass);


--
-- Name: variables id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables ALTER COLUMN id SET DEFAULT nextval('variables_id_seq'::regclass);


--
-- Name: vms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms ALTER COLUMN id SET DEFAULT nextval('vms_id_seq'::regclass);


--
-- Data for Name: agent_dns_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY agent_dns_versions (id, agent_id, dns_version) FROM stdin;
1	4a48f59b-ec34-479b-9418-702d1c29c2dd	1
\.


--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('agent_dns_versions_id_seq', 1, true);


--
-- Data for Name: blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY blobs (id, blobstore_id, sha1, created_at, type) FROM stdin;
1	c828ee26-565d-45ed-82e3-3f94698d067a	e5a5b96566f0c9cb427ad62251cbf38b97ae5cbf	2017-07-12 21:40:42.579617	\N
2	3a880b35-56a3-486b-b546-2309f9c8483c	40b9fd954d1477e86fc7d0751af777007dc774c3	2017-07-12 21:40:50.804434	\N
\.


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cloud_configs (id, properties, created_at) FROM stdin;
1	azs:\n- name: z1\ncompilation:\n  az: z1\n  network: private\n  reuse_compilation_vms: true\n  vm_type: small\n  workers: 1\ndisk_types:\n- disk_size: 3000\n  name: small\nnetworks:\n- name: private\n  subnets:\n  - az: z1\n    dns:\n    - 10.10.0.2\n    gateway: 10.10.0.1\n    range: 10.10.0.0/24\n    static:\n    - 10.10.0.62\n  type: manual\nvm_types:\n- name: small\n	2017-07-12 21:40:40.514868
\.


--
-- Name: cloud_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cloud_configs_id_seq', 1, true);


--
-- Data for Name: compiled_packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY compiled_packages (id, blobstore_id, sha1, dependency_key, build, package_id, dependency_key_sha1, stemcell_os, stemcell_version) FROM stdin;
\.


--
-- Name: compiled_packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('compiled_packages_id_seq', 1, false);


--
-- Data for Name: cpi_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cpi_configs (id, properties, created_at) FROM stdin;
\.


--
-- Name: cpi_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cpi_configs_id_seq', 1, false);


--
-- Data for Name: delayed_jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delayed_jobs (id, priority, attempts, handler, last_error, run_at, locked_at, failed_at, locked_by, queue) FROM stdin;
\.


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delayed_jobs_id_seq', 5, true);


--
-- Data for Name: deployment_problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployment_problems (id, deployment_id, state, resource_id, type, data_json, created_at, last_seen_at, counter) FROM stdin;
\.


--
-- Name: deployment_problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployment_problems_id_seq', 1, false);


--
-- Data for Name: deployment_properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployment_properties (id, deployment_id, name, value) FROM stdin;
\.


--
-- Name: deployment_properties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployment_properties_id_seq', 1, false);


--
-- Data for Name: deployments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments (id, name, manifest, cloud_config_id, link_spec_json) FROM stdin;
1	simple	---\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: provider\n    properties:\n      a: '1'\n      b: '2'\n      c: '3'\n    provides:\n      provider:\n        as: provider_link\n        shared: true\n  name: ig_provider\n  networks:\n  - name: private\n  persistent_disk_type: small\n  stemcell: default\n  vm_type: small\nname: simple\nreleases:\n- name: bosh-release\n  version: 0+dev.1\nstemcells:\n- alias: default\n  os: toronto-os\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	1	{"ig_provider":{"provider":{"provider_link":{"provider":{"deployment_name":"simple","networks":["private"],"properties":{"a":"1","b":"2","c":"3"},"instances":[{"name":"ig_provider","index":0,"bootstrap":true,"id":"0abb811d-a080-4241-9e3f-1b61344628fa","az":"z1","address":"0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh","addresses":{"private":"10.10.0.2"}}]}}}}}
\.


--
-- Name: deployments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_id_seq', 1, true);


--
-- Data for Name: deployments_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_release_versions (id, release_version_id, deployment_id) FROM stdin;
1	1	1
\.


--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_release_versions_id_seq', 1, true);


--
-- Data for Name: deployments_runtime_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_runtime_configs (deployment_id, runtime_config_id) FROM stdin;
\.


--
-- Data for Name: deployments_stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_stemcells (id, deployment_id, stemcell_id) FROM stdin;
1	1	1
\.


--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_stemcells_id_seq', 1, true);


--
-- Data for Name: deployments_teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_teams (deployment_id, team_id) FROM stdin;
\.


--
-- Data for Name: director_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY director_attributes (value, name, id) FROM stdin;
\.


--
-- Name: director_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('director_attributes_id_seq', 1, false);


--
-- Data for Name: dns_schema; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dns_schema (filename) FROM stdin;
20120123234908_initial.rb
\.


--
-- Data for Name: domains; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY domains (id, name, master, last_check, type, notified_serial, account) FROM stdin;
1	bosh	\N	\N	NATIVE	\N	\N
2	0.10.10.in-addr.arpa	\N	\N	NATIVE	\N	\N
\.


--
-- Name: domains_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('domains_id_seq', 2, true);


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ephemeral_blobs_id_seq', 2, true);


--
-- Data for Name: errand_runs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY errand_runs (id, successful, successful_configuration_hash, successful_packages_spec, instance_id) FROM stdin;
\.


--
-- Name: errand_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('errand_runs_id_seq', 1, false);


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY events (id, parent_id, "user", "timestamp", action, object_type, object_name, error, task, deployment, instance, context_json) FROM stdin;
1	\N	_director	2017-07-12 21:40:36.800126	start	worker	worker_1	\N	\N	\N	\N	{}
2	\N	_director	2017-07-12 21:40:36.829424	start	worker	worker_0	\N	\N	\N	\N	{}
3	\N	_director	2017-07-12 21:40:36.877484	start	director	deadbeef	\N	\N	\N	\N	{"version":"0.0.0"}
4	\N	_director	2017-07-12 21:40:36.88289	start	worker	worker_2	\N	\N	\N	\N	{}
5	\N	test	2017-07-12 21:40:37.930096	acquire	lock	lock:release:bosh-release	\N	1	\N	\N	{}
6	\N	test	2017-07-12 21:40:38.931717	release	lock	lock:release:bosh-release	\N	1	\N	\N	{}
7	\N	test	2017-07-12 21:40:40.517761	update	cloud-config	\N	\N	\N	\N	\N	{}
8	\N	test	2017-07-12 21:40:40.994513	create	deployment	simple	\N	3	simple	\N	{}
9	\N	test	2017-07-12 21:40:41.001698	acquire	lock	lock:deployment:simple	\N	3	simple	\N	{}
10	\N	test	2017-07-12 21:40:41.0483	acquire	lock	lock:release:bosh-release	\N	3	\N	\N	{}
11	\N	test	2017-07-12 21:40:41.060264	release	lock	lock:release:bosh-release	\N	3	\N	\N	{}
12	\N	test	2017-07-12 21:40:41.166204	create	vm	\N	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
13	12	test	2017-07-12 21:40:41.352878	create	vm	49315	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
14	\N	test	2017-07-12 21:40:42.725066	create	instance	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{"az":"z1"}
15	\N	test	2017-07-12 21:40:43.913523	create	disk	\N	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
16	15	test	2017-07-12 21:40:44.063856	create	disk	b89bca7442e0c2b15e80d558200f9cb8	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
17	14	test	2017-07-12 21:40:49.402561	create	instance	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	\N	3	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
18	8	test	2017-07-12 21:40:49.417879	create	deployment	simple	\N	3	simple	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
19	\N	test	2017-07-12 21:40:49.421372	release	lock	lock:deployment:simple	\N	3	simple	\N	{}
20	\N	test	2017-07-12 21:40:50.155951	update	deployment	simple	\N	4	simple	\N	{}
21	\N	test	2017-07-12 21:40:50.163741	acquire	lock	lock:deployment:simple	\N	4	simple	\N	{}
22	\N	test	2017-07-12 21:40:50.192342	acquire	lock	lock:release:bosh-release	\N	4	\N	\N	{}
23	\N	test	2017-07-12 21:40:50.19826	release	lock	lock:release:bosh-release	\N	4	\N	\N	{}
24	\N	test	2017-07-12 21:40:50.407096	stop	instance	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	\N	4	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
25	\N	test	2017-07-12 21:40:50.595862	delete	vm	49315	\N	4	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
26	25	test	2017-07-12 21:40:50.759579	delete	vm	49315	\N	4	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
27	24	test	2017-07-12 21:40:50.937361	stop	instance	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	\N	4	simple	ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa	{}
28	20	test	2017-07-12 21:40:50.948175	update	deployment	simple	\N	4	simple	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
29	\N	test	2017-07-12 21:40:50.951811	release	lock	lock:deployment:simple	\N	4	simple	\N	{}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 29, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid_bak, agent_id_bak, credentials_json_bak, trusted_certs_sha1_bak, update_completed, ignore, variable_set_id) FROM stdin;
1	ig_provider	0	1	detached	f	0abb811d-a080-4241-9e3f-1b61344628fa	z1	{}	f	t	["0.ig-provider.private.simple.bosh","0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh"]	{"deployment":"simple","job":{"name":"ig_provider","templates":[{"name":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"52f1c6179ca50c452a105b71c3c092b19f9118fc","blobstore_id":"13b9733e-3a4f-4cda-b478-7461dbbfac7a"}],"template":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"52f1c6179ca50c452a105b71c3c092b19f9118fc","blobstore_id":"13b9733e-3a4f-4cda-b478-7461dbbfac7a"},"index":0,"bootstrap":true,"lifecycle":"service","name":"ig_provider","id":"0abb811d-a080-4241-9e3f-1b61344628fa","az":"z1","networks":{"private":{"type":"manual","ip":"10.10.0.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["10.10.0.2"],"gateway":"10.10.0.1"}},"vm_type":{"name":"small","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"provider":{"a":"1","b":"2","c":"3"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":3000,"persistent_disk_pool":{"name":"small","disk_size":3000,"cloud_properties":{}},"persistent_disk_type":{"name":"small","disk_size":3000,"cloud_properties":{}},"template_hashes":{"provider":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"0b54e765-67cb-4c1b-a24e-f121a48c7af1","sha1":"68082e68dadaff96a92919cec6305c9ee3e679e2"},"configuration_hash":"90c5d1358d128117989fc21f2897a25c99205e50"}	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_id_seq', 1, true);


--
-- Data for Name: instances_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances_templates (id, instance_id, template_id) FROM stdin;
1	1	20
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_templates_id_seq', 1, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ip_addresses (id, network_name, address, static, instance_id, created_at, task_id) FROM stdin;
1	private	168427522	f	1	2017-07-12 21:40:41.087358	3
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 1, true);


--
-- Data for Name: local_dns_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_blobs (id, blob_id, version, created_at) FROM stdin;
1	1	1	2017-07-12 21:40:42.579617
2	2	2	2017-07-12 21:40:50.804434
\.


--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_blobs_id_seq1', 2, true);


--
-- Data for Name: local_dns_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_records (id, ip, az, instance_group, network, deployment, instance_id, agent_id, domain) FROM stdin;
2	10.10.0.2	z1	ig_provider	private	simple	1	\N	bosh
\.


--
-- Name: local_dns_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_records_id_seq', 2, true);


--
-- Data for Name: locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locks (id, expired_at, name, uid) FROM stdin;
\.


--
-- Name: locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locks_id_seq', 5, true);


--
-- Data for Name: log_bundles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY log_bundles (id, blobstore_id, "timestamp") FROM stdin;
\.


--
-- Name: log_bundles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('log_bundles_id_seq', 1, false);


--
-- Data for Name: orphan_disks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orphan_disks (id, disk_cid, size, availability_zone, deployment_name, instance_name, cloud_properties_json, created_at) FROM stdin;
\.


--
-- Name: orphan_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orphan_disks_id_seq', 1, false);


--
-- Data for Name: orphan_snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orphan_snapshots (id, orphan_disk_id, snapshot_cid, clean, created_at, snapshot_created_at) FROM stdin;
\.


--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orphan_snapshots_id_seq', 1, false);


--
-- Data for Name: packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY packages (id, name, version, blobstore_id, sha1, dependency_set_json, release_id, fingerprint) FROM stdin;
1	pkg_1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b	8cdec552-0f64-4722-8fb7-cc01dc44c1a5	55d2abf3cb48eb3cb3243952ba5a1bb598159bc7	[]	1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b
2	pkg_2	fa48497a19f12e925b32fcb8f5ca2b42144e4444	f2b753f6-5c4e-4617-b6e7-18d5e5160ab9	236bf17bd878cef83ca9f1f44ded4ae1d33a2ea6	[]	1	fa48497a19f12e925b32fcb8f5ca2b42144e4444
3	pkg_3_depends_on_2	2dfa256bc0b0750ae9952118c428b0dcd1010305	c95183ae-714e-43b2-b599-dfb3a1ec51ac	824ce72eab6c4b37c83fe711c83273c1e6949366	["pkg_2"]	1	2dfa256bc0b0750ae9952118c428b0dcd1010305
\.


--
-- Name: packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('packages_id_seq', 3, true);


--
-- Data for Name: packages_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY packages_release_versions (id, package_id, release_version_id) FROM stdin;
1	1	1
2	2	1
3	3	1
\.


--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('packages_release_versions_id_seq', 3, true);


--
-- Data for Name: persistent_disks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY persistent_disks (id, instance_id, disk_cid, size, active, cloud_properties_json, name) FROM stdin;
1	1	b89bca7442e0c2b15e80d558200f9cb8	3000	t	{}	
\.


--
-- Name: persistent_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('persistent_disks_id_seq', 1, true);


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY records (id, name, type, content, ttl, prio, change_date, domain_id) FROM stdin;
5	0.10.10.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	2
6	0.10.10.in-addr.arpa	NS	ns.bosh	14400	\N	\N	2
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1499895650	1
2	bosh	NS	ns.bosh	14400	\N	1499895650	1
3	ns.bosh	A	\N	18000	\N	1499895650	1
4	0.ig-provider.private.simple.bosh	A	10.10.0.2	300	\N	1499895650	1
7	2.0.10.10.in-addr.arpa	PTR	0.ig-provider.private.simple.bosh	300	\N	1499895650	2
8	0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh	A	10.10.0.2	300	\N	1499895650	1
9	2.0.10.10.in-addr.arpa	PTR	0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh	300	\N	1499895650	2
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('records_id_seq', 9, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	2e94c7cdc	t
\.


--
-- Name: release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('release_versions_id_seq', 1, true);


--
-- Data for Name: release_versions_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions_templates (id, release_version_id, template_id) FROM stdin;
1	1	1
2	1	2
3	1	3
4	1	4
5	1	5
6	1	6
7	1	7
8	1	8
9	1	9
10	1	10
11	1	11
12	1	12
13	1	13
14	1	14
15	1	15
16	1	16
17	1	17
18	1	18
19	1	19
20	1	20
21	1	21
22	1	22
23	1	23
\.


--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('release_versions_templates_id_seq', 23, true);


--
-- Data for Name: releases; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY releases (id, name) FROM stdin;
1	bosh-release
\.


--
-- Name: releases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('releases_id_seq', 1, true);


--
-- Data for Name: rendered_templates_archives; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY rendered_templates_archives (id, instance_id, blobstore_id, sha1, content_sha1, created_at) FROM stdin;
1	1	0b54e765-67cb-4c1b-a24e-f121a48c7af1	68082e68dadaff96a92919cec6305c9ee3e679e2	90c5d1358d128117989fc21f2897a25c99205e50	2017-07-12 21:40:42.736916
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rendered_templates_archives_id_seq', 1, true);


--
-- Data for Name: runtime_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY runtime_configs (id, properties, created_at, name) FROM stdin;
\.


--
-- Name: runtime_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('runtime_configs_id_seq', 1, false);


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY schema_migrations (filename) FROM stdin;
20110209010747_initial.rb
20110406055800_add_task_user.rb
20110518225809_remove_cid_constrain.rb
20110617211923_add_deployments_release_versions.rb
20110622212607_add_task_checkpoint_timestamp.rb
20110628023039_add_state_to_instances.rb
20110709012332_add_disk_size_to_instances.rb
20110906183441_add_log_bundles.rb
20110907194830_add_logs_json_to_templates.rb
20110915205610_add_persistent_disks.rb
20111005180929_add_properties.rb
20111110024617_add_deployment_problems.rb
20111216214145_recreate_support_for_vms.rb
20120102084027_add_credentials_to_vms.rb
20120427235217_allow_multiple_releases_per_deployment.rb
20120524175805_add_task_type.rb
20120614001930_delete_redundant_deployment_release_relation.rb
20120822004528_add_fingerprint_to_templates_and_packages.rb
20120830191244_add_properties_to_templates.rb
20121106190739_persist_vm_env.rb
20130222232131_add_sha1_to_stemcells.rb
20130312211407_add_commit_hash_to_release_versions.rb
20130409235338_snapshot.rb
20130530164918_add_paused_flag_to_instance.rb
20130531172604_add_director_attributes.rb
20131121182231_add_rendered_templates_archives.rb
20131125232201_rename_rendered_templates_archives_blob_id_and_checksum_columns.rb
20140116002324_pivot_director_attributes.rb
20140124225348_proper_pk_for_attributes.rb
20140731215410_increase_text_limit_for_data_columns.rb
20141204234517_add_cloud_properties_to_persistent_disk.rb
20150102234124_denormalize_task_user_id_to_task_username.rb
20150223222605_increase_manifest_text_limit.rb
20150224193313_use_larger_text_types.rb
20150331002413_add_cloud_configs.rb
20150401184803_add_cloud_config_to_deployments.rb
20150513225143_ip_addresses.rb
20150611193110_add_trusted_certs_sha1_to_vms.rb
20150619135210_add_os_name_and_version_to_stemcells.rb
20150702004608_add_links.rb
20150708231924_add_link_spec.rb
20150716170926_allow_null_on_blobstore_id_and_sha1_on_package.rb
20150724183256_add_debugging_to_ip_addresses.rb
20150730225029_add_uuid_to_instances.rb
20150803215805_add_availabililty_zone_and_cloud_properties_to_instances.rb
20150804211419_add_compilation_flag_to_instance.rb
20150918003455_add_bootstrap_node_to_instance.rb
20151008232214_add_dns_records.rb
20151015172551_add_orphan_disks_and_snapshots.rb
20151030222853_add_templates_to_instance.rb
20151031001039_add_spec_to_instance.rb
20151109190602_rename_orphan_columns.rb
20151223172000_rename_requires_json.rb
20151229184742_add_vm_attributes_to_instance.rb
20160106162749_runtime_configs.rb
20160106163433_add_runtime_configs_to_deployments.rb
20160108191637_drop_vm_env_json_from_instance.rb
20160121003800_drop_vms_fkeys.rb
20160202162216_add_post_start_completed_to_instance.rb
20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb
20160211174110_add_events.rb
20160211193904_add_scopes_to_deployment.rb
20160219175840_add_column_teams_to_deployments.rb
20160224222508_add_deployment_name_to_task.rb
20160225182206_rename_post_start_completed.rb
20160324181932_create_delayed_jobs.rb
20160324182211_add_locks.rb
20160329201256_set_instances_with_nil_serial_to_false.rb
20160331225404_backfill_stemcell_os.rb
20160411104407_add_task_started_at.rb
20160414183654_set_teams_on_task.rb
20160427164345_add_teams.rb
20160511191928_ephemeral_blobs.rb
20160513102035_add_tracking_to_instance.rb
20160531164756_add_local_dns_blobs.rb
20160614182106_change_text_to_longtext_for_mysql.rb
20160615192201_change_text_to_longtext_for_mysql_for_additional_fields.rb
20160706131605_change_events_id_type.rb
20160708234509_add_local_dns_records.rb
20160712171230_add_version_to_local_dns_blobs.rb
20160725090007_add_cpi_configs.rb
20160803151600_add_name_to_persistent_disks.rb
20160817135953_add_cpi_to_stemcells.rb
20160818112257_change_stemcell_unique_key.rb
20161031204534_populate_lifecycle_on_instance_spec.rb
20161128181900_add_logs_to_tasks.rb
20161209104649_add_context_id_to_tasks.rb
20161221151107_allow_null_instance_id_local_dns.rb
20170104003158_add_agent_dns_version.rb
20170116235940_add_errand_runs.rb
20170119202003_update_sha1_column_sizes.rb
20170203212124_add_variables.rb
20170216194502_remove_blobstore_id_idx_from_local_dns_blobs.rb
20170217000000_variables_instance_table_foreign_key_update.rb
20170301192646_add_deployed_successfully_to_variable_sets.rb
20170303175054_expand_template_json_column_lengths.rb
20170306215659_expand_vms_json_column_lengths.rb
20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records.rb
20170321151400_add_writable_to_variable_set.rb
20170328224049_associate_vm_info_with_vms_table.rb
20170331171657_remove_active_vm_id_from_instances.rb
20170405144414_add_cross_deployment_links_support_for_variables.rb
20170405181126_backfill_local_dns_records_and_drop_name.rb
20170412205032_add_agent_id_and_domain_name_to_local_dns_records.rb
20170427194511_add_runtime_config_name_support.rb
20170503205545_change_id_local_dns_to_bigint.rb
20170510154449_add_multi_runtime_config_support.rb
20170510190908_alter_ephemeral_blobs.rb
20170616185237_migrate_spec_json_links.rb
\.


--
-- Data for Name: snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY snapshots (id, persistent_disk_id, clean, created_at, snapshot_cid) FROM stdin;
1	1	t	2017-07-12 21:40:50.578916	bbb7277167f7f3f24c77e108f6c9728c
\.


--
-- Name: snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('snapshots_id_seq', 1, true);


--
-- Data for Name: stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY stemcells (id, name, version, cid, sha1, operating_system, cpi) FROM stdin;
1	ubuntu-stemcell	1	68aab7c44c857217641784806e2eeac4a3a99d1c	shawone	toronto-os	
\.


--
-- Name: stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stemcells_id_seq', 1, true);


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tasks (id, state, "timestamp", description, result, output, checkpoint_time, type, username, deployment_name, started_at, event_output, result_output, context_id) FROM stdin;
2	done	2017-07-12 21:40:40.278985	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-48794/sandbox/boshdir/tasks/2	2017-07-12 21:40:39.895794	update_stemcell	test	\N	2017-07-12 21:40:39.895692	{"time":1499895639,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"started","progress":0}\n{"time":1499895639,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"finished","progress":100}\n{"time":1499895639,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"started","progress":0}\n{"time":1499895639,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"finished","progress":100}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"started","progress":0}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"finished","progress":100}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"started","progress":0}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"finished","progress":100}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"started","progress":0}\n{"time":1499895640,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"finished","progress":100}\n		
1	done	2017-07-12 21:40:38.947296	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-48794/sandbox/boshdir/tasks/1	2017-07-12 21:40:37.878568	update_release	test	\N	2017-07-12 21:40:37.878471	{"time":1499895637,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"started","progress":0}\n{"time":1499895637,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"finished","progress":100}\n{"time":1499895637,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"started","progress":0}\n{"time":1499895637,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"finished","progress":100}\n{"time":1499895637,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"started","progress":0}\n{"time":1499895637,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"finished","progress":100}\n{"time":1499895637,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"started","progress":0}\n{"time":1499895637,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"finished","progress":100}\n{"time":1499895637,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf","index":2,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf","index":2,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/142c10d6cd586cd9b092b2618922194b608160f7","index":10,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/142c10d6cd586cd9b092b2618922194b608160f7","index":10,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6","index":13,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6","index":13,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/c12835da15038bedad6c49d20a2dda00375a0dc0","index":19,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/c12835da15038bedad6c49d20a2dda00375a0dc0","index":19,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"started","progress":0}\n{"time":1499895638,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"finished","progress":100}\n{"time":1499895638,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"started","progress":0}\n{"time":1499895638,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"finished","progress":100}\n		
5	done	2017-07-12 21:40:51.464584	retrieve vm-stats		/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-48794/sandbox/boshdir/tasks/5	2017-07-12 21:40:51.447674	vms	test	simple	2017-07-12 21:40:51.447585		{"vm_cid":null,"disk_cid":"b89bca7442e0c2b15e80d558200f9cb8","disk_cids":["b89bca7442e0c2b15e80d558200f9cb8"],"ips":["10.10.0.2"],"dns":["0abb811d-a080-4241-9e3f-1b61344628fa.ig-provider.private.simple.bosh","0.ig-provider.private.simple.bosh"],"agent_id":null,"job_name":"ig_provider","index":0,"job_state":null,"state":"detached","resource_pool":"small","vm_type":"small","vitals":null,"processes":[],"resurrection_paused":false,"az":"z1","id":"0abb811d-a080-4241-9e3f-1b61344628fa","bootstrap":true,"ignore":false}\n	
3	done	2017-07-12 21:40:49.427809	create deployment	/deployments/simple	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-48794/sandbox/boshdir/tasks/3	2017-07-12 21:40:40.982808	update_deployment	test	simple	2017-07-12 21:40:40.982726	{"time":1499895641,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1499895641,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1499895641,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1499895641,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1499895641,"stage":"Creating missing vms","tags":[],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0)","index":1,"state":"started","progress":0}\n{"time":1499895642,"stage":"Creating missing vms","tags":[],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0)","index":1,"state":"finished","progress":100}\n{"time":1499895642,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1499895649,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0) (canary)","index":1,"state":"finished","progress":100}\n		
4	done	2017-07-12 21:40:50.955446	create deployment	/deployments/simple	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-48794/sandbox/boshdir/tasks/4	2017-07-12 21:40:50.140645	update_deployment	test	simple	2017-07-12 21:40:50.140476	{"time":1499895650,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1499895650,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1499895650,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1499895650,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1499895650,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1499895650,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/0abb811d-a080-4241-9e3f-1b61344628fa (0) (canary)","index":1,"state":"finished","progress":100}\n		
\.


--
-- Name: tasks_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tasks_new_id_seq', 5, true);


--
-- Data for Name: tasks_teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tasks_teams (task_id, team_id) FROM stdin;
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY teams (id, name) FROM stdin;
\.


--
-- Name: teams_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('teams_id_seq', 1, false);


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY templates (id, name, version, blobstore_id, sha1, package_names_json, release_id, logs_json, fingerprint, properties_json, consumes_json, provides_json) FROM stdin;
1	addon	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	85993d66-7c3d-4319-bc9d-42e79986bc5f	a0250d55ec0d3dd2f26aff89aab093f0269a1f12	[]	1	null	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	{}	[{"name":"db","type":"db"}]	\N
2	api_server	db761328436e7557b071dbcf4ddcc4417ef9b1bf	c032ed3f-5dc9-44d0-a205-1cff5764feb6	1cd138a12aefe6172277b156446269010bd83765	["pkg_3_depends_on_2"]	1	null	db761328436e7557b071dbcf4ddcc4417ef9b1bf	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
3	api_server_with_bad_link_types	058b26819bd6561a75c2fed45ec49e671c9fbc6a	5f166b68-340b-4537-a9db-736edb9419ee	cdcb7b33dad85077b73dedbb88bf5a41980f5ee6	["pkg_3_depends_on_2"]	1	null	058b26819bd6561a75c2fed45ec49e671c9fbc6a	{}	[{"name":"db","type":"bad_link"},{"name":"backup_db","type":"bad_link_2"},{"name":"some_link_name","type":"bad_link_3"}]	\N
4	api_server_with_bad_optional_links	8a2485f1de3d99657e101fd269202c39cf3b5d73	72710867-0256-4f50-8847-a3e83e4c161c	079bda86712501f6a1da013d18b342016007a518	["pkg_3_depends_on_2"]	1	null	8a2485f1de3d99657e101fd269202c39cf3b5d73	{}	[{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
5	api_server_with_optional_db_link	00831c288b4a42454543ff69f71360634bd06b7b	fe4e7b6d-56a6-4114-9d4f-be8ae1b31081	30c766fefb56bb8bc00e15cc3b5c2d0aeca31b75	["pkg_3_depends_on_2"]	1	null	00831c288b4a42454543ff69f71360634bd06b7b	{}	[{"name":"db","type":"db","optional":true}]	\N
6	api_server_with_optional_links_1	0efc908dd04d84858e3cf8b75c326f35af5a5a98	32d0c8dc-60fb-4bf2-8b38-67bd99e787c3	aeaa4e97f0a25036b190ad67b8ac712f5e961e1c	["pkg_3_depends_on_2"]	1	null	0efc908dd04d84858e3cf8b75c326f35af5a5a98	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"},{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
7	api_server_with_optional_links_2	15f815868a057180e21dbac61629f73ad3558fec	13147ee9-f11f-444d-bd9e-c280d9dcc68f	5574cc6396e138a17a2fa7700d4a52333b517c2a	["pkg_3_depends_on_2"]	1	null	15f815868a057180e21dbac61629f73ad3558fec	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db","optional":true}]	\N
8	app_server	58e364fb74a01a1358475fc1da2ad905b78b4487	84d3264b-beed-4bcb-a1bb-d7e9f4397dca	9021b52b01aff170d59aa9423ffa92ff3048a703	[]	1	null	58e364fb74a01a1358475fc1da2ad905b78b4487	{}	\N	\N
9	backup_database	822933af7d854849051ca16539653158ad233e5e	189ed1ef-ba38-40f1-a5be-a77b012e11f4	33dd1eb36dd403cb36a6497a3c65cf9fb1bcc2d8	[]	1	null	822933af7d854849051ca16539653158ad233e5e	{"foo":{"default":"backup_bar"}}	\N	[{"name":"backup_db","type":"db","properties":["foo"]}]
10	consumer	142c10d6cd586cd9b092b2618922194b608160f7	1b48e43d-541c-4068-99af-b92cf6284e24	1732960fa7d82e83a96a8bc5ae0278dd82b5bf68	[]	1	null	142c10d6cd586cd9b092b2618922194b608160f7	{}	[{"name":"provider","type":"provider"}]	\N
11	database	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	957455ec-fd03-4215-954f-091e2e7823d5	c8d0f8ef9298bd321f148acafbb9ff03a5001d3c	[]	1	null	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	{"foo":{"default":"normal_bar"},"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db","type":"db","properties":["foo"]}]
12	database_with_two_provided_link_of_same_type	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	3e3f3dc2-14cd-4a9f-8ab1-ba90164d0fae	fed280ed4267e18167c2321dad27718f31095880	[]	1	null	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	{"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db1","type":"db"},{"name":"db2","type":"db"}]
13	errand_with_links	323401e6d25c0420d6dc85d2a2964c2c6569cfd6	81f91cdf-af21-4fe3-9f4f-d730962c1053	197140d751fc896c63980afad1bdd6380d799e90	[]	1	null	323401e6d25c0420d6dc85d2a2964c2c6569cfd6	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
14	http_endpoint_provider_with_property_types	30978e9fd0d29e52fe0369262e11fbcea1283889	81b604fe-c932-4797-886d-2d1ce018e4a3	23144b9264a3a20ca70ff0fb3433fd710ed43205	[]	1	null	30978e9fd0d29e52fe0369262e11fbcea1283889	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"Has a type password and no default value","type":"password"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
15	http_proxy_with_requires	760680c4a796a2ffca24026c561c06dd5bdef6b3	d33c9429-37a5-47f7-97ff-f82cf1c65065	fdc81b15644f8273c5993afe867ece567d0495c2	[]	1	null	760680c4a796a2ffca24026c561c06dd5bdef6b3	{"http_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"http_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"http_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"http_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"http_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}	[{"name":"proxied_http_endpoint","type":"http_endpoint"},{"name":"logs_http_endpoint","type":"http_endpoint2","optional":true}]	\N
16	http_server_with_provides	64244f12f2db2e7d93ccfbc13be744df87013389	b436fab3-8e1c-43c2-856a-80532aec7ecd	249a542b69e9bd9b9d242462eb60b5c797da25dc	[]	1	null	64244f12f2db2e7d93ccfbc13be744df87013389	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
17	kv_http_server	044ec02730e6d068ecf88a0d37fe48937687bdba	e9beb83b-b897-4088-a7da-91d9c17a5f87	2e25111b225152b5614cfa4f7fec4aeb1e6c4320	[]	1	null	044ec02730e6d068ecf88a0d37fe48937687bdba	{"kv_http_server.listen_port":{"description":"Port to listen on","default":8080}}	[{"name":"kv_http_server","type":"kv_http_server"}]	[{"name":"kv_http_server","type":"kv_http_server"}]
18	mongo_db	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	0a4830d1-39d6-4d82-a174-b76225790cc5	0df486bf2f38e5cb5c63995e2ae384a10bd76399	["pkg_1"]	1	null	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	{"foo":{"default":"mongo_foo_db"}}	\N	[{"name":"read_only_db","type":"db","properties":["foo"]}]
19	node	c12835da15038bedad6c49d20a2dda00375a0dc0	5e0eadb2-101a-4de3-9a45-9eb0930a1350	93c1ce376aead4a97da24f7282bb6f1ed0dae141	[]	1	null	c12835da15038bedad6c49d20a2dda00375a0dc0	{}	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]
20	provider	e1ff4ff9a6304e1222484570a400788c55154b1c	13b9733e-3a4f-4cda-b478-7461dbbfac7a	52f1c6179ca50c452a105b71c3c092b19f9118fc	[]	1	null	e1ff4ff9a6304e1222484570a400788c55154b1c	{"a":{"description":"description for a","default":"default_a"},"b":{"description":"description for b"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider","type":"provider","properties":["a","b","c"]}]
21	provider_fail	314c385e96711cb5d56dd909a086563dae61bc37	2c63fc72-50f9-4132-a831-e746c027c548	b2622fde21907461bfd8517d26d620460b10667a	[]	1	null	314c385e96711cb5d56dd909a086563dae61bc37	{"a":{"description":"description for a","default":"default_a"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider_fail","type":"provider","properties":["a","b","c"]}]
22	tcp_proxy_with_requires	e60ea353cdd24b6997efdedab144431c0180645b	ca7c7808-27aa-4c72-84d3-d4ed285175b0	fe3d5cb9dc396b8bcc79f90f5522136ac82842cf	[]	1	null	e60ea353cdd24b6997efdedab144431c0180645b	{"tcp_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"tcp_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"tcp_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"tcp_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"tcp_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}	[{"name":"proxied_http_endpoint","type":"http_endpoint"}]	\N
23	tcp_server_with_provides	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	5a8d9f51-51eb-4b78-b891-6e3306a6428b	5b3e0e9a8b5289a4c7ec23f1fc92feaf16c4dd22	[]	1	null	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('templates_id_seq', 23, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users (id, username, password) FROM stdin;
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_id_seq', 1, false);


--
-- Data for Name: variable_sets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY variable_sets (id, deployment_id, created_at, deployed_successfully, writable) FROM stdin;
1	1	2017-07-12 21:40:41.004791	t	f
\.


--
-- Name: variable_sets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('variable_sets_id_seq', 1, true);


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY variables (id, variable_id, variable_name, variable_set_id, is_local, provider_deployment) FROM stdin;
\.


--
-- Name: variables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('variables_id_seq', 1, false);


--
-- Data for Name: vms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vms (id, instance_id, agent_id, cid, credentials_json, trusted_certs_sha1, active) FROM stdin;
\.


--
-- Name: vms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vms_id_seq', 1, true);


--
-- Name: agent_dns_versions agent_dns_versions_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_agent_id_key UNIQUE (agent_id);


--
-- Name: agent_dns_versions agent_dns_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs cloud_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cloud_configs
    ADD CONSTRAINT cloud_configs_pkey PRIMARY KEY (id);


--
-- Name: compiled_packages compiled_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages
    ADD CONSTRAINT compiled_packages_pkey PRIMARY KEY (id);


--
-- Name: cpi_configs cpi_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cpi_configs
    ADD CONSTRAINT cpi_configs_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deployments_runtime_configs deployment_id_runtime_config_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployment_id_runtime_config_id_unique UNIQUE (deployment_id, runtime_config_id);


--
-- Name: deployment_problems deployment_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems
    ADD CONSTRAINT deployment_problems_pkey PRIMARY KEY (id);


--
-- Name: deployment_properties deployment_properties_deployment_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_name_key UNIQUE (deployment_id, name);


--
-- Name: deployment_properties deployment_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_pkey PRIMARY KEY (id);


--
-- Name: deployments deployments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_name_key UNIQUE (name);


--
-- Name: deployments deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions deployments_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions deployments_release_versions_release_version_id_deployment__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_deployment__key UNIQUE (release_version_id, deployment_id);


--
-- Name: deployments_stemcells deployments_stemcells_deployment_id_stemcell_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_stemcell_id_key UNIQUE (deployment_id, stemcell_id);


--
-- Name: deployments_stemcells deployments_stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_pkey PRIMARY KEY (id);


--
-- Name: deployments_teams deployments_teams_deployment_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_team_id_key UNIQUE (deployment_id, team_id);


--
-- Name: director_attributes director_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY director_attributes
    ADD CONSTRAINT director_attributes_pkey PRIMARY KEY (id);


--
-- Name: dns_schema dns_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dns_schema
    ADD CONSTRAINT dns_schema_pkey PRIMARY KEY (filename);


--
-- Name: domains domains_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_name_key UNIQUE (name);


--
-- Name: domains domains_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- Name: blobs ephemeral_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT ephemeral_blobs_pkey PRIMARY KEY (id);


--
-- Name: errand_runs errand_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs
    ADD CONSTRAINT errand_runs_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: instances instances_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_agent_id_key UNIQUE (agent_id_bak);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: instances_templates instances_templates_instance_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_instance_id_template_id_key UNIQUE (instance_id, template_id);


--
-- Name: instances_templates instances_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_pkey PRIMARY KEY (id);


--
-- Name: instances instances_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_uuid_key UNIQUE (uuid);


--
-- Name: instances instances_vm_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_cid_key UNIQUE (vm_cid_bak);


--
-- Name: ip_addresses ip_addresses_address_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_address_key UNIQUE (address);


--
-- Name: ip_addresses ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: local_dns_blobs local_dns_blobs_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_pkey1 PRIMARY KEY (id);


--
-- Name: local_dns_records local_dns_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_pkey PRIMARY KEY (id);


--
-- Name: locks locks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_name_key UNIQUE (name);


--
-- Name: locks locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_pkey PRIMARY KEY (id);


--
-- Name: locks locks_uid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_uid_key UNIQUE (uid);


--
-- Name: log_bundles log_bundles_blobstore_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_blobstore_id_key UNIQUE (blobstore_id);


--
-- Name: log_bundles log_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_pkey PRIMARY KEY (id);


--
-- Name: orphan_disks orphan_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: orphan_disks orphan_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots orphan_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots orphan_snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: packages packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: packages packages_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: packages_release_versions packages_release_versions_package_id_release_version_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_release_version_id_key UNIQUE (package_id, release_version_id);


--
-- Name: packages_release_versions packages_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_pkey PRIMARY KEY (id);


--
-- Name: persistent_disks persistent_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: persistent_disks persistent_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_pkey PRIMARY KEY (id);


--
-- Name: records records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_pkey PRIMARY KEY (id);


--
-- Name: release_versions release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions
    ADD CONSTRAINT release_versions_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates release_versions_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates release_versions_templates_release_version_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_template_id_key UNIQUE (release_version_id, template_id);


--
-- Name: releases releases_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_name_key UNIQUE (name);


--
-- Name: releases releases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: rendered_templates_archives rendered_templates_archives_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_pkey PRIMARY KEY (id);


--
-- Name: runtime_configs runtime_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY runtime_configs
    ADD CONSTRAINT runtime_configs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: snapshots snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_pkey PRIMARY KEY (id);


--
-- Name: snapshots snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: stemcells stemcells_name_version_cpi_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_name_version_cpi_key UNIQUE (name, version, cpi);


--
-- Name: stemcells stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_new_pkey PRIMARY KEY (id);


--
-- Name: tasks_teams tasks_teams_task_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_team_id_key UNIQUE (task_id, team_id);


--
-- Name: teams teams_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: templates templates_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: variable_sets variable_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variable_sets
    ADD CONSTRAINT variable_sets_pkey PRIMARY KEY (id);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: vms vms_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_agent_id_key UNIQUE (agent_id);


--
-- Name: vms vms_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_cid_key UNIQUE (cid);


--
-- Name: vms vms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX cloud_configs_created_at_index ON cloud_configs USING btree (created_at);


--
-- Name: cpi_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX cpi_configs_created_at_index ON cpi_configs USING btree (created_at);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX delayed_jobs_priority ON delayed_jobs USING btree (priority, run_at);


--
-- Name: deployment_problems_deployment_id_state_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX deployment_problems_deployment_id_state_created_at_index ON deployment_problems USING btree (deployment_id, state, created_at);


--
-- Name: deployment_problems_deployment_id_type_state_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX deployment_problems_deployment_id_type_state_index ON deployment_problems USING btree (deployment_id, type, state);


--
-- Name: events_timestamp_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX events_timestamp_index ON events USING btree ("timestamp");


--
-- Name: locks_name_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX locks_name_index ON locks USING btree (name);


--
-- Name: log_bundles_timestamp_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX log_bundles_timestamp_index ON log_bundles USING btree ("timestamp");


--
-- Name: orphan_disks_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orphan_disks_orphaned_at_index ON orphan_disks USING btree (created_at);


--
-- Name: orphan_snapshots_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orphan_snapshots_orphaned_at_index ON orphan_snapshots USING btree (created_at);


--
-- Name: package_stemcell_build_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX package_stemcell_build_idx ON compiled_packages USING btree (package_id, stemcell_os, stemcell_version, build);


--
-- Name: package_stemcell_dependency_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX package_stemcell_dependency_idx ON compiled_packages USING btree (package_id, stemcell_os, stemcell_version, dependency_key_sha1);


--
-- Name: packages_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX packages_fingerprint_index ON packages USING btree (fingerprint);


--
-- Name: packages_sha1_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX packages_sha1_index ON packages USING btree (sha1);


--
-- Name: records_domain_id_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX records_domain_id_index ON records USING btree (domain_id);


--
-- Name: records_name_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX records_name_index ON records USING btree (name);


--
-- Name: records_name_type_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX records_name_type_index ON records USING btree (name, type);


--
-- Name: rendered_templates_archives_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rendered_templates_archives_created_at_index ON rendered_templates_archives USING btree (created_at);


--
-- Name: runtime_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX runtime_configs_created_at_index ON runtime_configs USING btree (created_at);


--
-- Name: tasks_context_id_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tasks_context_id_index ON tasks USING btree (context_id);


--
-- Name: tasks_description_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tasks_description_index ON tasks USING btree (description);


--
-- Name: tasks_state_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tasks_state_index ON tasks USING btree (state);


--
-- Name: tasks_timestamp_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tasks_timestamp_index ON tasks USING btree ("timestamp");


--
-- Name: templates_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX templates_fingerprint_index ON templates USING btree (fingerprint);


--
-- Name: templates_sha1_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX templates_sha1_index ON templates USING btree (sha1);


--
-- Name: unique_attribute_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_attribute_name ON director_attributes USING btree (name);


--
-- Name: variable_set_name_provider_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX variable_set_name_provider_idx ON variables USING btree (variable_set_id, variable_name, provider_deployment);


--
-- Name: variable_sets_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX variable_sets_created_at_index ON variable_sets USING btree (created_at);


--
-- Name: compiled_packages compiled_packages_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages
    ADD CONSTRAINT compiled_packages_package_id_fkey FOREIGN KEY (package_id) REFERENCES packages(id);


--
-- Name: deployment_problems deployment_problems_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems
    ADD CONSTRAINT deployment_problems_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployment_properties deployment_properties_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments deployments_cloud_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_cloud_config_id_fkey FOREIGN KEY (cloud_config_id) REFERENCES cloud_configs(id);


--
-- Name: deployments_release_versions deployments_release_versions_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments_release_versions deployments_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: deployments_runtime_configs deployments_runtime_configs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployments_runtime_configs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_runtime_configs deployments_runtime_configs_runtime_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployments_runtime_configs_runtime_config_id_fkey FOREIGN KEY (runtime_config_id) REFERENCES runtime_configs(id) ON DELETE CASCADE;


--
-- Name: deployments_stemcells deployments_stemcells_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments_stemcells deployments_stemcells_stemcell_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_stemcell_id_fkey FOREIGN KEY (stemcell_id) REFERENCES stemcells(id);


--
-- Name: deployments_teams deployments_teams_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_teams deployments_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;


--
-- Name: errand_runs errands_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs
    ADD CONSTRAINT errands_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE;


--
-- Name: instances instance_table_variable_set_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instance_table_variable_set_fkey FOREIGN KEY (variable_set_id) REFERENCES variable_sets(id);


--
-- Name: instances instances_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: instances_templates instances_templates_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: instances_templates instances_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES templates(id);


--
-- Name: ip_addresses ip_addresses_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: local_dns_blobs local_dns_blobs_blob_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id);


--
-- Name: local_dns_records local_dns_records_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: orphan_snapshots orphan_snapshots_orphan_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_orphan_disk_id_fkey FOREIGN KEY (orphan_disk_id) REFERENCES orphan_disks(id);


--
-- Name: packages packages_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: packages_release_versions packages_release_versions_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_fkey FOREIGN KEY (package_id) REFERENCES packages(id);


--
-- Name: packages_release_versions packages_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: persistent_disks persistent_disks_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: records records_domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE;


--
-- Name: release_versions release_versions_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions
    ADD CONSTRAINT release_versions_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: release_versions_templates release_versions_templates_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: release_versions_templates release_versions_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES templates(id);


--
-- Name: rendered_templates_archives rendered_templates_archives_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: snapshots snapshots_persistent_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_persistent_disk_id_fkey FOREIGN KEY (persistent_disk_id) REFERENCES persistent_disks(id);


--
-- Name: tasks_teams tasks_teams_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE;


--
-- Name: tasks_teams tasks_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;


--
-- Name: templates templates_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: variable_sets variable_sets_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variable_sets
    ADD CONSTRAINT variable_sets_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: variables variables_variable_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables
    ADD CONSTRAINT variables_variable_set_id_fkey FOREIGN KEY (variable_set_id) REFERENCES variable_sets(id) ON DELETE CASCADE;


--
-- Name: vms vms_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: pivotal
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pivotal;
GRANT ALL ON SCHEMA public TO pivotal;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

