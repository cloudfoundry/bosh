--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

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
-- Name: agent_dns_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: blobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: cloud_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: compiled_packages; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: cpi_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployment_problems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployment_properties; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployments_release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployments_runtime_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE deployments_runtime_configs (
    deployment_id integer NOT NULL,
    runtime_config_id integer NOT NULL
);


ALTER TABLE deployments_runtime_configs OWNER TO postgres;

--
-- Name: deployments_stemcells; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: deployments_teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE deployments_teams (
    deployment_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE deployments_teams OWNER TO postgres;

--
-- Name: director_attributes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: dns_schema; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dns_schema (
    filename text NOT NULL
);


ALTER TABLE dns_schema OWNER TO postgres;

--
-- Name: domains; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: errand_runs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: events; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: instances; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: instances_templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: ip_addresses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: local_dns_blobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: local_dns_records; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: locks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: log_bundles; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: orphan_disks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: orphan_snapshots; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: packages; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: packages_release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: persistent_disks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: records; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: release_versions_templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: releases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: rendered_templates_archives; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: runtime_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE schema_migrations (
    filename text NOT NULL
);


ALTER TABLE schema_migrations OWNER TO postgres;

--
-- Name: snapshots; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: stemcells; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: tasks_teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tasks_teams (
    task_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE tasks_teams OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: users; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: variable_sets; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: variables; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: vms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
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
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY agent_dns_versions ALTER COLUMN id SET DEFAULT nextval('agent_dns_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY blobs ALTER COLUMN id SET DEFAULT nextval('ephemeral_blobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cloud_configs ALTER COLUMN id SET DEFAULT nextval('cloud_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages ALTER COLUMN id SET DEFAULT nextval('compiled_packages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cpi_configs ALTER COLUMN id SET DEFAULT nextval('cpi_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems ALTER COLUMN id SET DEFAULT nextval('deployment_problems_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties ALTER COLUMN id SET DEFAULT nextval('deployment_properties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments ALTER COLUMN id SET DEFAULT nextval('deployments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions ALTER COLUMN id SET DEFAULT nextval('deployments_release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells ALTER COLUMN id SET DEFAULT nextval('deployments_stemcells_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY director_attributes ALTER COLUMN id SET DEFAULT nextval('director_attributes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains ALTER COLUMN id SET DEFAULT nextval('domains_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs ALTER COLUMN id SET DEFAULT nextval('errand_runs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances ALTER COLUMN id SET DEFAULT nextval('instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates ALTER COLUMN id SET DEFAULT nextval('instances_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses ALTER COLUMN id SET DEFAULT nextval('ip_addresses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs ALTER COLUMN id SET DEFAULT nextval('local_dns_blobs_id_seq1'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records ALTER COLUMN id SET DEFAULT nextval('local_dns_records_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks ALTER COLUMN id SET DEFAULT nextval('locks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles ALTER COLUMN id SET DEFAULT nextval('log_bundles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks ALTER COLUMN id SET DEFAULT nextval('orphan_disks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots ALTER COLUMN id SET DEFAULT nextval('orphan_snapshots_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages ALTER COLUMN id SET DEFAULT nextval('packages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions ALTER COLUMN id SET DEFAULT nextval('packages_release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks ALTER COLUMN id SET DEFAULT nextval('persistent_disks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records ALTER COLUMN id SET DEFAULT nextval('records_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions ALTER COLUMN id SET DEFAULT nextval('release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates ALTER COLUMN id SET DEFAULT nextval('release_versions_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases ALTER COLUMN id SET DEFAULT nextval('releases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives ALTER COLUMN id SET DEFAULT nextval('rendered_templates_archives_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY runtime_configs ALTER COLUMN id SET DEFAULT nextval('runtime_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots ALTER COLUMN id SET DEFAULT nextval('snapshots_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells ALTER COLUMN id SET DEFAULT nextval('stemcells_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks ALTER COLUMN id SET DEFAULT nextval('tasks_new_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams ALTER COLUMN id SET DEFAULT nextval('teams_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates ALTER COLUMN id SET DEFAULT nextval('templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variable_sets ALTER COLUMN id SET DEFAULT nextval('variable_sets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables ALTER COLUMN id SET DEFAULT nextval('variables_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms ALTER COLUMN id SET DEFAULT nextval('vms_id_seq'::regclass);


--
-- Data for Name: agent_dns_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY agent_dns_versions (id, agent_id, dns_version) FROM stdin;
1	8deb7e35-dcb4-4acf-b89e-b59b72802df4	1
\.


--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('agent_dns_versions_id_seq', 1, true);


--
-- Data for Name: blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY blobs (id, blobstore_id, sha1, created_at, type) FROM stdin;
1	d6b0f0bf-27a4-4238-af60-0e3b1ac78882	e6aaf418a01ae65140cee17c9e2c32539fe2444f	2017-07-14 15:51:33.163676	\N
2	cc160bd6-3bdd-45ca-9566-e174b3b1ea02	7617c65a555a29dbb7dca6b9ac0176dfb4be4df9	2017-07-14 15:51:41.446935	\N
\.


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cloud_configs (id, properties, created_at) FROM stdin;
1	azs:\n- name: z1\ncompilation:\n  az: z1\n  network: private\n  reuse_compilation_vms: true\n  vm_type: small\n  workers: 1\ndisk_types:\n- disk_size: 3000\n  name: small\nnetworks:\n- name: private\n  subnets:\n  - az: z1\n    dns:\n    - 10.10.0.2\n    gateway: 10.10.0.1\n    range: 10.10.0.0/24\n    static:\n    - 10.10.0.62\n  type: manual\nvm_types:\n- name: small\n	2017-07-14 15:51:31.365754
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
1	simple	---\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: provider\n    properties:\n      a: '1'\n      b: '2'\n      c: '3'\n    provides:\n      provider:\n        as: provider_link\n        shared: true\n  name: ig_provider\n  networks:\n  - name: private\n  persistent_disk_type: small\n  stemcell: default\n  vm_type: small\nname: simple\nreleases:\n- name: bosh-release\n  version: 0+dev.1\nstemcells:\n- alias: default\n  os: toronto-os\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	1	{"ig_provider":{"provider":{"provider_link":{"provider":{"deployment_name":"simple","networks":["private"],"properties":{"a":"1","b":"2","c":"3"},"instances":[{"name":"ig_provider","index":0,"bootstrap":true,"id":"095b1f3c-a15f-4635-bc66-e8fde422cfcd","az":"z1","address":"095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh","addresses":{"private":"10.10.0.2"}}]}}}}}
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
1	\N	_director	2017-07-14 15:51:26.56463	start	worker	worker_1	\N	\N	\N	\N	{}
2	\N	_director	2017-07-14 15:51:26.569093	start	director	deadbeef	\N	\N	\N	\N	{"version":"0.0.0"}
3	\N	_director	2017-07-14 15:51:26.575509	start	worker	worker_0	\N	\N	\N	\N	{}
4	\N	_director	2017-07-14 15:51:26.576838	start	worker	worker_2	\N	\N	\N	\N	{}
5	\N	test	2017-07-14 15:51:28.67678	acquire	lock	lock:release:bosh-release	\N	1	\N	\N	{}
6	\N	test	2017-07-14 15:51:29.667005	release	lock	lock:release:bosh-release	\N	1	\N	\N	{}
7	\N	test	2017-07-14 15:51:31.36693	update	cloud-config	\N	\N	\N	\N	\N	{}
8	\N	test	2017-07-14 15:51:31.657816	create	deployment	simple	\N	3	simple	\N	{}
9	\N	test	2017-07-14 15:51:31.665098	acquire	lock	lock:deployment:simple	\N	3	simple	\N	{}
10	\N	test	2017-07-14 15:51:31.705052	acquire	lock	lock:release:bosh-release	\N	3	\N	\N	{}
11	\N	test	2017-07-14 15:51:31.713991	release	lock	lock:release:bosh-release	\N	3	\N	\N	{}
12	\N	test	2017-07-14 15:51:31.802772	create	vm	\N	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
13	12	test	2017-07-14 15:51:31.954106	create	vm	75548	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
14	\N	test	2017-07-14 15:51:33.301473	create	instance	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{"az":"z1"}
15	\N	test	2017-07-14 15:51:34.485998	create	disk	\N	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
16	15	test	2017-07-14 15:51:34.632286	create	disk	c0e8ab1a15720feac1987035ed39c1be	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
17	14	test	2017-07-14 15:51:39.949654	create	instance	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	\N	3	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
18	8	test	2017-07-14 15:51:39.964444	create	deployment	simple	\N	3	simple	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
19	\N	test	2017-07-14 15:51:39.96782	release	lock	lock:deployment:simple	\N	3	simple	\N	{}
20	\N	test	2017-07-14 15:51:40.836576	update	deployment	simple	\N	4	simple	\N	{}
21	\N	test	2017-07-14 15:51:40.84412	acquire	lock	lock:deployment:simple	\N	4	simple	\N	{}
22	\N	test	2017-07-14 15:51:40.875146	acquire	lock	lock:release:bosh-release	\N	4	\N	\N	{}
23	\N	test	2017-07-14 15:51:40.881081	release	lock	lock:release:bosh-release	\N	4	\N	\N	{}
24	\N	test	2017-07-14 15:51:41.085199	stop	instance	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	\N	4	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
25	\N	test	2017-07-14 15:51:41.247158	delete	vm	75548	\N	4	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
26	25	test	2017-07-14 15:51:41.403093	delete	vm	75548	\N	4	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
27	24	test	2017-07-14 15:51:41.57764	stop	instance	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	\N	4	simple	ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd	{}
28	20	test	2017-07-14 15:51:41.589771	update	deployment	simple	\N	4	simple	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
29	\N	test	2017-07-14 15:51:41.593187	release	lock	lock:deployment:simple	\N	4	simple	\N	{}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 29, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid_bak, agent_id_bak, credentials_json_bak, trusted_certs_sha1_bak, update_completed, ignore, variable_set_id) FROM stdin;
1	ig_provider	0	1	detached	f	095b1f3c-a15f-4635-bc66-e8fde422cfcd	z1	{}	f	t	["0.ig-provider.private.simple.bosh","095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh"]	{"deployment":"simple","job":{"name":"ig_provider","templates":[{"name":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"f04065c3cbd06e1d398c689e5a097e1203b14114","blobstore_id":"37052fdc-1af6-4d54-bbc3-0defaef5550f"}],"template":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"f04065c3cbd06e1d398c689e5a097e1203b14114","blobstore_id":"37052fdc-1af6-4d54-bbc3-0defaef5550f"},"index":0,"bootstrap":true,"lifecycle":"service","name":"ig_provider","id":"095b1f3c-a15f-4635-bc66-e8fde422cfcd","az":"z1","networks":{"private":{"type":"manual","ip":"10.10.0.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["10.10.0.2"],"gateway":"10.10.0.1"}},"vm_type":{"name":"small","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"provider":{"a":"1","b":"2","c":"3"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":3000,"persistent_disk_pool":{"name":"small","disk_size":3000,"cloud_properties":{}},"persistent_disk_type":{"name":"small","disk_size":3000,"cloud_properties":{}},"template_hashes":{"provider":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"57be004c-e21d-4487-abed-ebd1b1140689","sha1":"2142010f8f02e873f3dc794d7ed452e07c083eb5"},"configuration_hash":"90c5d1358d128117989fc21f2897a25c99205e50"}	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
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
1	private	168427522	f	1	2017-07-14 15:51:31.736393	3
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 1, true);


--
-- Data for Name: local_dns_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_blobs (id, blob_id, version, created_at) FROM stdin;
1	1	1	2017-07-14 15:51:33.163676
2	2	2	2017-07-14 15:51:41.446935
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
1	pkg_1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b	cfbc0409-1498-4227-bc9d-962c3adf2d22	68d9f02abe641a360f0d331b2bfd6f1472c75993	[]	1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b
2	pkg_2	fa48497a19f12e925b32fcb8f5ca2b42144e4444	0e0f2cb9-09a9-4924-adb3-8ede0ddd0536	3a0e47944c2c28dcf16e65c602c0de9987a84d9e	[]	1	fa48497a19f12e925b32fcb8f5ca2b42144e4444
3	pkg_3_depends_on_2	2dfa256bc0b0750ae9952118c428b0dcd1010305	610bdf35-b489-4637-9153-c81b817de53c	984e2044ee88ee272be89781ca313e27993bfccf	["pkg_2"]	1	2dfa256bc0b0750ae9952118c428b0dcd1010305
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
1	1	c0e8ab1a15720feac1987035ed39c1be	3000	t	{}	
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
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1500047500	1
2	bosh	NS	ns.bosh	14400	\N	1500047500	1
3	ns.bosh	A	\N	18000	\N	1500047500	1
4	0.ig-provider.private.simple.bosh	A	10.10.0.2	300	\N	1500047501	1
7	2.0.10.10.in-addr.arpa	PTR	0.ig-provider.private.simple.bosh	300	\N	1500047501	2
8	095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh	A	10.10.0.2	300	\N	1500047501	1
9	2.0.10.10.in-addr.arpa	PTR	095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh	300	\N	1500047501	2
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
1	1	57be004c-e21d-4487-abed-ebd1b1140689	2142010f8f02e873f3dc794d7ed452e07c083eb5	90c5d1358d128117989fc21f2897a25c99205e50	2017-07-14 15:51:33.311658
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
1	1	t	2017-07-14 15:51:41.230255	cbd51a74681ee21bb4c537a1c533f5c7
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
2	done	2017-07-14 15:51:30.977871	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-74973/sandbox/boshdir/tasks/2	2017-07-14 15:51:30.63671	update_stemcell	test	\N	2017-07-14 15:51:30.6366	{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"started","progress":0}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"finished","progress":100}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"started","progress":0}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"finished","progress":100}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"started","progress":0}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"finished","progress":100}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"started","progress":0}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"finished","progress":100}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"started","progress":0}\n{"time":1500047490,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"finished","progress":100}\n		
4	done	2017-07-14 15:51:41.597091	create deployment	/deployments/simple	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-74973/sandbox/boshdir/tasks/4	2017-07-14 15:51:40.821849	update_deployment	test	simple	2017-07-14 15:51:40.821771	{"time":1500047500,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1500047500,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1500047500,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1500047500,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1500047501,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1500047501,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0) (canary)","index":1,"state":"finished","progress":100}\n		
5	done	2017-07-14 15:51:42.103958	retrieve vm-stats		/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-74973/sandbox/boshdir/tasks/5	2017-07-14 15:51:42.088605	vms	test	simple	2017-07-14 15:51:42.088523		{"vm_cid":null,"disk_cid":"c0e8ab1a15720feac1987035ed39c1be","disk_cids":["c0e8ab1a15720feac1987035ed39c1be"],"ips":["10.10.0.2"],"dns":["095b1f3c-a15f-4635-bc66-e8fde422cfcd.ig-provider.private.simple.bosh","0.ig-provider.private.simple.bosh"],"agent_id":null,"job_name":"ig_provider","index":0,"job_state":null,"state":"detached","resource_pool":"small","vm_type":"small","vitals":null,"processes":[],"resurrection_paused":false,"az":"z1","id":"095b1f3c-a15f-4635-bc66-e8fde422cfcd","bootstrap":true,"ignore":false}\n	
3	done	2017-07-14 15:51:39.97404	create deployment	/deployments/simple	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-74973/sandbox/boshdir/tasks/3	2017-07-14 15:51:31.645601	update_deployment	test	simple	2017-07-14 15:51:31.645522	{"time":1500047491,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1500047491,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1500047491,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1500047491,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1500047491,"stage":"Creating missing vms","tags":[],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0)","index":1,"state":"started","progress":0}\n{"time":1500047493,"stage":"Creating missing vms","tags":[],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0)","index":1,"state":"finished","progress":100}\n{"time":1500047493,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1500047499,"stage":"Updating instance","tags":["ig_provider"],"total":1,"task":"ig_provider/095b1f3c-a15f-4635-bc66-e8fde422cfcd (0) (canary)","index":1,"state":"finished","progress":100}\n		
1	done	2017-07-14 15:51:29.681613	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-74973/sandbox/boshdir/tasks/1	2017-07-14 15:51:28.623272	update_release	test	\N	2017-07-14 15:51:28.623191	{"time":1500047488,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"started","progress":0}\n{"time":1500047488,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"started","progress":0}\n{"time":1500047488,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"started","progress":0}\n{"time":1500047488,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf","index":2,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/db761328436e7557b071dbcf4ddcc4417ef9b1bf","index":2,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"finished","progress":100}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"started","progress":0}\n{"time":1500047488,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/142c10d6cd586cd9b092b2618922194b608160f7","index":10,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/142c10d6cd586cd9b092b2618922194b608160f7","index":10,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6","index":13,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/323401e6d25c0420d6dc85d2a2964c2c6569cfd6","index":13,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/c12835da15038bedad6c49d20a2dda00375a0dc0","index":19,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/c12835da15038bedad6c49d20a2dda00375a0dc0","index":19,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"started","progress":0}\n{"time":1500047489,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"finished","progress":100}\n{"time":1500047489,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"started","progress":0}\n{"time":1500047489,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"finished","progress":100}\n		
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
1	addon	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	e1666720-0f03-4626-825f-f4d8d995caaf	b1b6f853290bf4a8aa89472cf4ce83fb9ddf4dcd	[]	1	null	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	{}	[{"name":"db","type":"db"}]	\N
2	api_server	db761328436e7557b071dbcf4ddcc4417ef9b1bf	0164b91a-9651-49f9-8606-d321415b3dac	c2e01fa34ce90165608eddf4115040e0181724ab	["pkg_3_depends_on_2"]	1	null	db761328436e7557b071dbcf4ddcc4417ef9b1bf	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
3	api_server_with_bad_link_types	058b26819bd6561a75c2fed45ec49e671c9fbc6a	ed500df5-69a5-410a-b3d3-5e6577c45bea	54ffa0afee4283ec23e27767841ee42a33d8d45f	["pkg_3_depends_on_2"]	1	null	058b26819bd6561a75c2fed45ec49e671c9fbc6a	{}	[{"name":"db","type":"bad_link"},{"name":"backup_db","type":"bad_link_2"},{"name":"some_link_name","type":"bad_link_3"}]	\N
4	api_server_with_bad_optional_links	8a2485f1de3d99657e101fd269202c39cf3b5d73	c519cb27-379d-45ac-8186-58d1aa3d8305	a6e4f71f328c3c55878701ab9317c8de940d1d04	["pkg_3_depends_on_2"]	1	null	8a2485f1de3d99657e101fd269202c39cf3b5d73	{}	[{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
5	api_server_with_optional_db_link	00831c288b4a42454543ff69f71360634bd06b7b	ef1b8c22-0152-4ef0-9e13-922dc4963821	c93869852098dc404f5603bc1326e3e756bf1021	["pkg_3_depends_on_2"]	1	null	00831c288b4a42454543ff69f71360634bd06b7b	{}	[{"name":"db","type":"db","optional":true}]	\N
6	api_server_with_optional_links_1	0efc908dd04d84858e3cf8b75c326f35af5a5a98	92c74d19-9bdf-48cf-9e0b-662d2e35d2ca	befe3ecc3f1c21574a8feed5aeb206446c8e4ec1	["pkg_3_depends_on_2"]	1	null	0efc908dd04d84858e3cf8b75c326f35af5a5a98	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"},{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
7	api_server_with_optional_links_2	15f815868a057180e21dbac61629f73ad3558fec	2f5b0c9e-5e85-4de3-be84-dac89680ea57	6b4724479335d96912e2efca4f901f16d7227fa7	["pkg_3_depends_on_2"]	1	null	15f815868a057180e21dbac61629f73ad3558fec	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db","optional":true}]	\N
8	app_server	58e364fb74a01a1358475fc1da2ad905b78b4487	48972874-0acd-4f15-b6a2-931b4fda353f	404cad5b5b48ad9221e510aedc2475a786196286	[]	1	null	58e364fb74a01a1358475fc1da2ad905b78b4487	{}	\N	\N
9	backup_database	822933af7d854849051ca16539653158ad233e5e	2ec8e8fb-8f21-42a3-9c69-e4056b9b0bbc	c7b6eb57539164aec7fd3a960f0c7d6a248b06ea	[]	1	null	822933af7d854849051ca16539653158ad233e5e	{"foo":{"default":"backup_bar"}}	\N	[{"name":"backup_db","type":"db","properties":["foo"]}]
10	consumer	142c10d6cd586cd9b092b2618922194b608160f7	f398253d-6a4b-43e4-b6c0-846d34d76922	dd444514663ceacebe4e49f701026accdbbefd7e	[]	1	null	142c10d6cd586cd9b092b2618922194b608160f7	{}	[{"name":"provider","type":"provider"}]	\N
11	database	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	3e7ed53a-4435-41be-b6f4-faea7bc5bfb4	cdab2f77f81227003d49d15ba37d42d7655030b7	[]	1	null	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	{"foo":{"default":"normal_bar"},"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db","type":"db","properties":["foo"]}]
12	database_with_two_provided_link_of_same_type	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	2457e6d3-5a1f-41c9-a67e-cb780e4d4caa	43257afc72bc9ae49440aff21fd2a5d6afc997b5	[]	1	null	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	{"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db1","type":"db"},{"name":"db2","type":"db"}]
13	errand_with_links	323401e6d25c0420d6dc85d2a2964c2c6569cfd6	f9ca4c81-eac6-402d-882b-7dece107e1f1	2df37cbd4aa092395127e2defe7b4b9d45098639	[]	1	null	323401e6d25c0420d6dc85d2a2964c2c6569cfd6	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
14	http_endpoint_provider_with_property_types	30978e9fd0d29e52fe0369262e11fbcea1283889	c6b23985-3486-4913-b09f-aae71f508db7	8dc0591db03a80cd303155e409f55c0a6ca75176	[]	1	null	30978e9fd0d29e52fe0369262e11fbcea1283889	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"Has a type password and no default value","type":"password"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
15	http_proxy_with_requires	760680c4a796a2ffca24026c561c06dd5bdef6b3	a12b07ef-0dc3-42ed-ab1d-191bfed9e810	023d97f11d682091cafe8cc9ca2a0944ad8ec7ae	[]	1	null	760680c4a796a2ffca24026c561c06dd5bdef6b3	{"http_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"http_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"http_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"http_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"http_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}	[{"name":"proxied_http_endpoint","type":"http_endpoint"},{"name":"logs_http_endpoint","type":"http_endpoint2","optional":true}]	\N
16	http_server_with_provides	64244f12f2db2e7d93ccfbc13be744df87013389	899afc3d-6cce-4903-931d-9cdbfc8b80ea	9d72eece21fd5336fcca99e28784af4cd2023006	[]	1	null	64244f12f2db2e7d93ccfbc13be744df87013389	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
17	kv_http_server	044ec02730e6d068ecf88a0d37fe48937687bdba	adc1a5ba-777e-4952-aeda-9e1e07d459b9	00ff6a238c8b352901df1137b5b7947dc7ffdf17	[]	1	null	044ec02730e6d068ecf88a0d37fe48937687bdba	{"kv_http_server.listen_port":{"description":"Port to listen on","default":8080}}	[{"name":"kv_http_server","type":"kv_http_server"}]	[{"name":"kv_http_server","type":"kv_http_server"}]
18	mongo_db	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	5f2429d7-e518-4eb2-be39-d9d13c06cf6a	ff9043cc794aa0661a284b5a9a0801dddc6f1b03	["pkg_1"]	1	null	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	{"foo":{"default":"mongo_foo_db"}}	\N	[{"name":"read_only_db","type":"db","properties":["foo"]}]
19	node	c12835da15038bedad6c49d20a2dda00375a0dc0	c49b3b68-1e2e-4305-8d47-e94417bdfac5	a473e01d62e6445019ee968cf6a7b13106773920	[]	1	null	c12835da15038bedad6c49d20a2dda00375a0dc0	{}	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]
20	provider	e1ff4ff9a6304e1222484570a400788c55154b1c	37052fdc-1af6-4d54-bbc3-0defaef5550f	f04065c3cbd06e1d398c689e5a097e1203b14114	[]	1	null	e1ff4ff9a6304e1222484570a400788c55154b1c	{"a":{"description":"description for a","default":"default_a"},"b":{"description":"description for b"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider","type":"provider","properties":["a","b","c"]}]
21	provider_fail	314c385e96711cb5d56dd909a086563dae61bc37	4240eb42-74d6-45b4-a289-d569e84d1d6b	9e6e64b3a9db7e953656949f8eaae0b7c020ddda	[]	1	null	314c385e96711cb5d56dd909a086563dae61bc37	{"a":{"description":"description for a","default":"default_a"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider_fail","type":"provider","properties":["a","b","c"]}]
22	tcp_proxy_with_requires	e60ea353cdd24b6997efdedab144431c0180645b	345127d4-4aa3-41f5-96b3-cba963a4fc38	24b31cd4e22504da7ef4442318291c5945db623d	[]	1	null	e60ea353cdd24b6997efdedab144431c0180645b	{"tcp_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"tcp_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"tcp_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"tcp_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"tcp_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}	[{"name":"proxied_http_endpoint","type":"http_endpoint"}]	\N
23	tcp_server_with_provides	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	00e159d5-1984-4b62-934d-3ab55090b97e	984a6380c9efd24148f82fad8a34989d2501baf6	[]	1	null	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
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
1	1	2017-07-14 15:51:31.668104	t	f
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
-- Name: agent_dns_versions_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_agent_id_key UNIQUE (agent_id);


--
-- Name: agent_dns_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cloud_configs
    ADD CONSTRAINT cloud_configs_pkey PRIMARY KEY (id);


--
-- Name: compiled_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY compiled_packages
    ADD CONSTRAINT compiled_packages_pkey PRIMARY KEY (id);


--
-- Name: cpi_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cpi_configs
    ADD CONSTRAINT cpi_configs_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deployment_id_runtime_config_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployment_id_runtime_config_id_unique UNIQUE (deployment_id, runtime_config_id);


--
-- Name: deployment_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployment_problems
    ADD CONSTRAINT deployment_problems_pkey PRIMARY KEY (id);


--
-- Name: deployment_properties_deployment_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_name_key UNIQUE (deployment_id, name);


--
-- Name: deployment_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_pkey PRIMARY KEY (id);


--
-- Name: deployments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_name_key UNIQUE (name);


--
-- Name: deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_release_version_id_deployment__key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_deployment__key UNIQUE (release_version_id, deployment_id);


--
-- Name: deployments_stemcells_deployment_id_stemcell_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_stemcell_id_key UNIQUE (deployment_id, stemcell_id);


--
-- Name: deployments_stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_pkey PRIMARY KEY (id);


--
-- Name: deployments_teams_deployment_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_team_id_key UNIQUE (deployment_id, team_id);


--
-- Name: director_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY director_attributes
    ADD CONSTRAINT director_attributes_pkey PRIMARY KEY (id);


--
-- Name: dns_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dns_schema
    ADD CONSTRAINT dns_schema_pkey PRIMARY KEY (filename);


--
-- Name: domains_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_name_key UNIQUE (name);


--
-- Name: domains_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- Name: ephemeral_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT ephemeral_blobs_pkey PRIMARY KEY (id);


--
-- Name: errand_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY errand_runs
    ADD CONSTRAINT errand_runs_pkey PRIMARY KEY (id);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: instances_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_agent_id_key UNIQUE (agent_id_bak);


--
-- Name: instances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: instances_templates_instance_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_instance_id_template_id_key UNIQUE (instance_id, template_id);


--
-- Name: instances_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_pkey PRIMARY KEY (id);


--
-- Name: instances_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_uuid_key UNIQUE (uuid);


--
-- Name: instances_vm_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_cid_key UNIQUE (vm_cid_bak);


--
-- Name: ip_addresses_address_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_address_key UNIQUE (address);


--
-- Name: ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: local_dns_blobs_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_pkey1 PRIMARY KEY (id);


--
-- Name: local_dns_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_pkey PRIMARY KEY (id);


--
-- Name: locks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_name_key UNIQUE (name);


--
-- Name: locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_pkey PRIMARY KEY (id);


--
-- Name: locks_uid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_uid_key UNIQUE (uid);


--
-- Name: log_bundles_blobstore_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_blobstore_id_key UNIQUE (blobstore_id);


--
-- Name: log_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_pkey PRIMARY KEY (id);


--
-- Name: orphan_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: orphan_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: packages_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: packages_release_versions_package_id_release_version_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_release_version_id_key UNIQUE (package_id, release_version_id);


--
-- Name: packages_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_pkey PRIMARY KEY (id);


--
-- Name: persistent_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: persistent_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_pkey PRIMARY KEY (id);


--
-- Name: records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_pkey PRIMARY KEY (id);


--
-- Name: release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY release_versions
    ADD CONSTRAINT release_versions_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_release_version_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_template_id_key UNIQUE (release_version_id, template_id);


--
-- Name: releases_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_name_key UNIQUE (name);


--
-- Name: releases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: rendered_templates_archives_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_pkey PRIMARY KEY (id);


--
-- Name: runtime_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY runtime_configs
    ADD CONSTRAINT runtime_configs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_pkey PRIMARY KEY (id);


--
-- Name: snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: stemcells_name_version_cpi_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_name_version_cpi_key UNIQUE (name, version, cpi);


--
-- Name: stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_pkey PRIMARY KEY (id);


--
-- Name: tasks_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_new_pkey PRIMARY KEY (id);


--
-- Name: tasks_teams_task_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_team_id_key UNIQUE (task_id, team_id);


--
-- Name: teams_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: templates_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: variable_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY variable_sets
    ADD CONSTRAINT variable_sets_pkey PRIMARY KEY (id);


--
-- Name: variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: vms_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_agent_id_key UNIQUE (agent_id);


--
-- Name: vms_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_cid_key UNIQUE (cid);


--
-- Name: vms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cloud_configs_created_at_index ON cloud_configs USING btree (created_at);


--
-- Name: cpi_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cpi_configs_created_at_index ON cpi_configs USING btree (created_at);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX delayed_jobs_priority ON delayed_jobs USING btree (priority, run_at);


--
-- Name: deployment_problems_deployment_id_state_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deployment_problems_deployment_id_state_created_at_index ON deployment_problems USING btree (deployment_id, state, created_at);


--
-- Name: deployment_problems_deployment_id_type_state_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deployment_problems_deployment_id_type_state_index ON deployment_problems USING btree (deployment_id, type, state);


--
-- Name: events_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX events_timestamp_index ON events USING btree ("timestamp");


--
-- Name: locks_name_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX locks_name_index ON locks USING btree (name);


--
-- Name: log_bundles_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX log_bundles_timestamp_index ON log_bundles USING btree ("timestamp");


--
-- Name: orphan_disks_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orphan_disks_orphaned_at_index ON orphan_disks USING btree (created_at);


--
-- Name: orphan_snapshots_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orphan_snapshots_orphaned_at_index ON orphan_snapshots USING btree (created_at);


--
-- Name: package_stemcell_build_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX package_stemcell_build_idx ON compiled_packages USING btree (package_id, stemcell_os, stemcell_version, build);


--
-- Name: package_stemcell_dependency_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX package_stemcell_dependency_idx ON compiled_packages USING btree (package_id, stemcell_os, stemcell_version, dependency_key_sha1);


--
-- Name: packages_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX packages_fingerprint_index ON packages USING btree (fingerprint);


--
-- Name: packages_sha1_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX packages_sha1_index ON packages USING btree (sha1);


--
-- Name: records_domain_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_domain_id_index ON records USING btree (domain_id);


--
-- Name: records_name_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_name_index ON records USING btree (name);


--
-- Name: records_name_type_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_name_type_index ON records USING btree (name, type);


--
-- Name: rendered_templates_archives_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX rendered_templates_archives_created_at_index ON rendered_templates_archives USING btree (created_at);


--
-- Name: runtime_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX runtime_configs_created_at_index ON runtime_configs USING btree (created_at);


--
-- Name: tasks_context_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_context_id_index ON tasks USING btree (context_id);


--
-- Name: tasks_description_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_description_index ON tasks USING btree (description);


--
-- Name: tasks_state_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_state_index ON tasks USING btree (state);


--
-- Name: tasks_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_timestamp_index ON tasks USING btree ("timestamp");


--
-- Name: templates_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX templates_fingerprint_index ON templates USING btree (fingerprint);


--
-- Name: templates_sha1_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX templates_sha1_index ON templates USING btree (sha1);


--
-- Name: unique_attribute_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX unique_attribute_name ON director_attributes USING btree (name);


--
-- Name: variable_set_name_provider_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX variable_set_name_provider_idx ON variables USING btree (variable_set_id, variable_name, provider_deployment);


--
-- Name: variable_sets_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX variable_sets_created_at_index ON variable_sets USING btree (created_at);


--
-- Name: compiled_packages_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages
    ADD CONSTRAINT compiled_packages_package_id_fkey FOREIGN KEY (package_id) REFERENCES packages(id);


--
-- Name: deployment_problems_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems
    ADD CONSTRAINT deployment_problems_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployment_properties_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments_cloud_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_cloud_config_id_fkey FOREIGN KEY (cloud_config_id) REFERENCES cloud_configs(id);


--
-- Name: deployments_release_versions_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: deployments_runtime_configs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployments_runtime_configs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_runtime_configs_runtime_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_runtime_configs
    ADD CONSTRAINT deployments_runtime_configs_runtime_config_id_fkey FOREIGN KEY (runtime_config_id) REFERENCES runtime_configs(id) ON DELETE CASCADE;


--
-- Name: deployments_stemcells_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: deployments_stemcells_stemcell_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_stemcell_id_fkey FOREIGN KEY (stemcell_id) REFERENCES stemcells(id);


--
-- Name: deployments_teams_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;


--
-- Name: errands_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs
    ADD CONSTRAINT errands_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE;


--
-- Name: instance_table_variable_set_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instance_table_variable_set_fkey FOREIGN KEY (variable_set_id) REFERENCES variable_sets(id);


--
-- Name: instances_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id);


--
-- Name: instances_templates_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: instances_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES templates(id);


--
-- Name: ip_addresses_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: local_dns_blobs_blob_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id);


--
-- Name: local_dns_records_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: orphan_snapshots_orphan_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_orphan_disk_id_fkey FOREIGN KEY (orphan_disk_id) REFERENCES orphan_disks(id);


--
-- Name: packages_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: packages_release_versions_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_fkey FOREIGN KEY (package_id) REFERENCES packages(id);


--
-- Name: packages_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: persistent_disks_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: records_domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE;


--
-- Name: release_versions_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions
    ADD CONSTRAINT release_versions_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: release_versions_templates_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES release_versions(id);


--
-- Name: release_versions_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES templates(id);


--
-- Name: rendered_templates_archives_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: snapshots_persistent_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_persistent_disk_id_fkey FOREIGN KEY (persistent_disk_id) REFERENCES persistent_disks(id);


--
-- Name: tasks_teams_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE;


--
-- Name: tasks_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE;


--
-- Name: templates_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_release_id_fkey FOREIGN KEY (release_id) REFERENCES releases(id);


--
-- Name: variable_sets_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variable_sets
    ADD CONSTRAINT variable_sets_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


--
-- Name: variables_variable_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables
    ADD CONSTRAINT variables_variable_set_id_fkey FOREIGN KEY (variable_set_id) REFERENCES variable_sets(id) ON DELETE CASCADE;


--
-- Name: vms_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
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

