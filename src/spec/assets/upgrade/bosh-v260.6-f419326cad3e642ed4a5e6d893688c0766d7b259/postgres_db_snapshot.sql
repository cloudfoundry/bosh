--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.4
-- Dumped by pg_dump version 9.5.4

SET statement_timeout = 0;
SET lock_timeout = 0;
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
    link_spec_json text,
    runtime_config_id integer
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
-- Name: ephemeral_blobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ephemeral_blobs (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE ephemeral_blobs OWNER TO postgres;

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

ALTER SEQUENCE ephemeral_blobs_id_seq OWNED BY ephemeral_blobs.id;


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
    vm_id integer,
    state text NOT NULL,
    resurrection_paused boolean DEFAULT false,
    uuid text,
    availability_zone text,
    cloud_properties text,
    compilation boolean DEFAULT false,
    bootstrap boolean DEFAULT false,
    dns_records text,
    spec_json text,
    vm_cid text,
    agent_id text,
    credentials_json text,
    trusted_certs_sha1 text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    update_completed boolean DEFAULT false,
    ignore boolean DEFAULT false
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
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    version integer
);


ALTER TABLE local_dns_blobs OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_blobs_id_seq OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_blobs_id_seq OWNED BY local_dns_blobs.id;


--
-- Name: local_dns_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE local_dns_records (
    id integer NOT NULL,
    name text NOT NULL,
    ip text NOT NULL,
    instance_id integer NOT NULL
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
    created_at timestamp without time zone NOT NULL
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
    operating_system text
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
    started_at timestamp without time zone
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
-- Name: vms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vms (
    id integer NOT NULL,
    agent_id text NOT NULL,
    cid text,
    deployment_id integer NOT NULL,
    credentials_json text,
    env_json text,
    trusted_certs_sha1 text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text
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

ALTER TABLE ONLY cloud_configs ALTER COLUMN id SET DEFAULT nextval('cloud_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages ALTER COLUMN id SET DEFAULT nextval('compiled_packages_id_seq'::regclass);


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

ALTER TABLE ONLY ephemeral_blobs ALTER COLUMN id SET DEFAULT nextval('ephemeral_blobs_id_seq'::regclass);


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

ALTER TABLE ONLY local_dns_blobs ALTER COLUMN id SET DEFAULT nextval('local_dns_blobs_id_seq'::regclass);


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

ALTER TABLE ONLY vms ALTER COLUMN id SET DEFAULT nextval('vms_id_seq'::regclass);


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cloud_configs (id, properties, created_at) FROM stdin;
1	---\nnetworks:\n- name: a\n  subnets:\n  - range: 192.168.1.0/24\n    gateway: 192.168.1.1\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    static:\n    - 192.168.1.10\n    reserved: []\n    cloud_properties: {}\ncompilation:\n  workers: 1\n  network: a\n  cloud_properties: {}\nresource_pools:\n- name: a\n  cloud_properties: {}\n  stemcell:\n    name: ubuntu-stemcell\n    version: '1'\n  env:\n    bosh:\n      password: foobar\n	2017-02-14 21:02:59.161981
\.


--
-- Name: cloud_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cloud_configs_id_seq', 1, true);


--
-- Data for Name: compiled_packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY compiled_packages (id, blobstore_id, sha1, dependency_key, build, package_id, dependency_key_sha1, stemcell_os, stemcell_version) FROM stdin;
1	0ad430fc-3ec9-4f7f-5331-43377f1e6644	7fb116b2c796c111a22c9c5aaefef08b80fc380f	[]	1	8	97d170e1550eee4afc0af065b78cda302a97674c	toronto-os	1
2	fccc9af6-2817-4773-4ed3-0a65f26c60ef	d581241ce4cfa0d86e5d970e16e4e34a07235f2b	[["foo","0ee95716c58cf7aab3ef7301ff907118552c2dda"]]	1	3	2ab05f5881c448e1fdf9f2438f31a41d654c27e6	toronto-os	1
\.


--
-- Name: compiled_packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('compiled_packages_id_seq', 2, true);


--
-- Data for Name: delayed_jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delayed_jobs (id, priority, attempts, handler, last_error, run_at, locked_at, failed_at, locked_by, queue) FROM stdin;
\.


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delayed_jobs_id_seq', 4, true);


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

COPY deployments (id, name, manifest, cloud_config_id, link_spec_json, runtime_config_id) FROM stdin;
1	simple	---\nname: simple\ndirector_uuid: deadbeef\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\njobs:\n- name: foobar1\n  templates:\n  - name: foobar\n  resource_pool: a\n  instances: 2\n  networks:\n  - name: a\n  properties: {}\n	1	{}	\N
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
deadbeef	uuid	1
\.


--
-- Name: director_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('director_attributes_id_seq', 1, true);


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
2	1.168.192.in-addr.arpa	\N	\N	NATIVE	\N	\N
\.


--
-- Name: domains_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('domains_id_seq', 2, true);


--
-- Data for Name: ephemeral_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ephemeral_blobs (id, blobstore_id, sha1, created_at) FROM stdin;
\.


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ephemeral_blobs_id_seq', 1, false);


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY events (id, parent_id, "user", "timestamp", action, object_type, object_name, error, task, deployment, instance, context_json) FROM stdin;
1	\N	test	2017-02-14 21:02:59.167791	update	cloud-config	\N	\N	\N	\N	\N	{}
2	\N	test	2017-02-14 21:03:01.042457	create	deployment	simple	\N	3	simple	\N	{}
3	\N	test	2017-02-14 21:03:01.346567	create	instance	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
4	\N	test	2017-02-14 21:03:01.353649	create	vm	\N	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
5	4	test	2017-02-14 21:03:01.399515	create	vm	53949	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
6	3	test	2017-02-14 21:03:02.477168	create	instance	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
7	\N	test	2017-02-14 21:03:03.494485	delete	instance	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
8	\N	test	2017-02-14 21:03:03.498315	delete	vm	53949	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
9	8	test	2017-02-14 21:03:03.51196	delete	vm	53949	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
10	7	test	2017-02-14 21:03:03.539432	delete	instance	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	\N	3	simple	compilation-91beee7a-7053-47e5-ac0d-21717394b3db/2655289e-49de-4d8d-8290-489107aac08b	{}
11	\N	test	2017-02-14 21:03:03.617561	create	instance	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
12	\N	test	2017-02-14 21:03:03.623891	create	vm	\N	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
13	12	test	2017-02-14 21:03:03.640902	create	vm	53959	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
14	11	test	2017-02-14 21:03:04.680622	create	instance	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
15	\N	test	2017-02-14 21:03:05.689661	delete	instance	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
16	\N	test	2017-02-14 21:03:05.693562	delete	vm	53959	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
17	16	test	2017-02-14 21:03:05.706639	delete	vm	53959	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
18	15	test	2017-02-14 21:03:05.728095	delete	instance	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	\N	3	simple	compilation-9416a25f-7c7f-4cfa-967b-42023f99100c/b6cf548b-9b78-42b2-bf3b-dc80d852473c	{}
19	\N	test	2017-02-14 21:03:05.777893	create	vm	\N	\N	3	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
20	\N	test	2017-02-14 21:03:05.778315	create	vm	\N	\N	3	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
21	19	test	2017-02-14 21:03:05.807953	create	vm	53965	\N	3	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
22	20	test	2017-02-14 21:03:05.813759	create	vm	53966	\N	3	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
23	\N	test	2017-02-14 21:03:06.909117	create	instance	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	\N	3	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
24	23	test	2017-02-14 21:03:14.030405	create	instance	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	\N	3	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
25	\N	test	2017-02-14 21:03:14.032932	create	instance	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	\N	3	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
26	25	test	2017-02-14 21:03:21.129321	create	instance	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	\N	3	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
27	2	test	2017-02-14 21:03:21.139784	create	deployment	simple	\N	3	simple	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
28	\N	test	2017-02-14 21:03:23.291764	update	deployment	simple	\N	4	simple	\N	{}
29	\N	test	2017-02-14 21:03:23.527968	stop	instance	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	\N	4	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
30	\N	test	2017-02-14 21:03:24.546772	delete	vm	53966	\N	4	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
31	30	test	2017-02-14 21:03:24.562446	delete	vm	53966	\N	4	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
32	29	test	2017-02-14 21:03:24.582902	stop	instance	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	\N	4	simple	foobar1/7c0ef109-a4cb-414f-b663-933604e3ca5e	{}
33	\N	test	2017-02-14 21:03:24.585535	stop	instance	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	\N	4	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
34	\N	test	2017-02-14 21:03:25.604508	delete	vm	53965	\N	4	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
35	34	test	2017-02-14 21:03:25.618563	delete	vm	53965	\N	4	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
36	33	test	2017-02-14 21:03:25.640415	stop	instance	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	\N	4	simple	foobar1/6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	{}
37	28	test	2017-02-14 21:03:25.648767	update	deployment	simple	\N	4	simple	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 37, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, vm_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid, agent_id, credentials_json, trusted_certs_sha1, update_completed, ignore) FROM stdin;
1	foobar1	0	1	\N	detached	f	7c0ef109-a4cb-414f-b663-933604e3ca5e	\N	{}	f	t	["0.foobar1.a.simple.bosh","7c0ef109-a4cb-414f-b663-933604e3ca5e.foobar1.a.simple.bosh"]	{"deployment":"simple","job":{"name":"foobar1","templates":[{"name":"foobar","version":"025e461e609c1596443e845f64af1d1239a1a32b","sha1":"cf68241f29a30dce59d1b82fa8f24aefcf618211","blobstore_id":"4f636b73-44a2-420e-9452-79e2de8515d1"}],"template":"foobar","version":"025e461e609c1596443e845f64af1d1239a1a32b","sha1":"cf68241f29a30dce59d1b82fa8f24aefcf618211","blobstore_id":"4f636b73-44a2-420e-9452-79e2de8515d1"},"index":0,"bootstrap":true,"lifecycle":"service","name":"foobar1","id":"7c0ef109-a4cb-414f-b663-933604e3ca5e","az":null,"networks":{"a":{"ip":"192.168.1.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{"bosh":{"password":"foobar"}},"packages":{"foo":{"name":"foo","version":"0ee95716c58cf7aab3ef7301ff907118552c2dda.1","sha1":"7fb116b2c796c111a22c9c5aaefef08b80fc380f","blobstore_id":"0ad430fc-3ec9-4f7f-5331-43377f1e6644"},"bar":{"name":"bar","version":"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1","sha1":"d581241ce4cfa0d86e5d970e16e4e34a07235f2b","blobstore_id":"fccc9af6-2817-4773-4ed3-0a65f26c60ef"}},"properties":{"foobar":{"test_property":1,"drain_type":"static","dynamic_drain_wait1":-3,"dynamic_drain_wait2":-2,"network_name":null,"networks":null}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true},"persistent_disk":0,"template_hashes":{"foobar":"6494269118d8b27732a7cd66634f59d679c4f9c8"},"rendered_templates_archive":{"blobstore_id":"c9b45ef5-a1ce-4cdb-9a5e-2e3eb7edd90c","sha1":"edf26c3e8e1d0d7c24da9078eeae9b8a3bba6a49"},"configuration_hash":"3456b369ea11602dceef012f3c4f0986ac221747"}	\N	\N	null	\N	t	f
2	foobar1	1	1	\N	detached	f	6ffe470d-4795-4ffa-a4c0-f50a0fdfa290	\N	{}	f	f	["1.foobar1.a.simple.bosh","6ffe470d-4795-4ffa-a4c0-f50a0fdfa290.foobar1.a.simple.bosh"]	{"deployment":"simple","job":{"name":"foobar1","templates":[{"name":"foobar","version":"025e461e609c1596443e845f64af1d1239a1a32b","sha1":"cf68241f29a30dce59d1b82fa8f24aefcf618211","blobstore_id":"4f636b73-44a2-420e-9452-79e2de8515d1"}],"template":"foobar","version":"025e461e609c1596443e845f64af1d1239a1a32b","sha1":"cf68241f29a30dce59d1b82fa8f24aefcf618211","blobstore_id":"4f636b73-44a2-420e-9452-79e2de8515d1"},"index":1,"bootstrap":false,"lifecycle":"service","name":"foobar1","id":"6ffe470d-4795-4ffa-a4c0-f50a0fdfa290","az":null,"networks":{"a":{"ip":"192.168.1.3","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{"bosh":{"password":"foobar"}},"packages":{"foo":{"name":"foo","version":"0ee95716c58cf7aab3ef7301ff907118552c2dda.1","sha1":"7fb116b2c796c111a22c9c5aaefef08b80fc380f","blobstore_id":"0ad430fc-3ec9-4f7f-5331-43377f1e6644"},"bar":{"name":"bar","version":"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1","sha1":"d581241ce4cfa0d86e5d970e16e4e34a07235f2b","blobstore_id":"fccc9af6-2817-4773-4ed3-0a65f26c60ef"}},"properties":{"foobar":{"test_property":1,"drain_type":"static","dynamic_drain_wait1":-3,"dynamic_drain_wait2":-2,"network_name":null,"networks":null}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.3","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true},"persistent_disk":0,"template_hashes":{"foobar":"fb0ecdab2b762e0dda20615a2380a952734b608f"},"rendered_templates_archive":{"blobstore_id":"bcef9359-8e76-46e7-a491-414e6edac307","sha1":"9404a55de78847105e41415bf1322e52d38142f3"},"configuration_hash":"84b9f99b70222704172c0a8f57ceb391ed0bb8ab"}	\N	\N	null	\N	t	f
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_id_seq', 4, true);


--
-- Data for Name: instances_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances_templates (id, instance_id, template_id) FROM stdin;
1	1	4
2	2	4
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_templates_id_seq', 2, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ip_addresses (id, network_name, address, static, instance_id, created_at, task_id) FROM stdin;
1	a	3232235778	f	1	2017-02-14 21:03:01.168605	3
2	a	3232235779	f	2	2017-02-14 21:03:01.17318	3
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 4, true);


--
-- Data for Name: local_dns_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_blobs (id, blobstore_id, sha1, created_at, version) FROM stdin;
\.


--
-- Name: local_dns_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_blobs_id_seq', 1, false);


--
-- Data for Name: local_dns_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_records (id, name, ip, instance_id) FROM stdin;
\.


--
-- Name: local_dns_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_records_id_seq', 1, false);


--
-- Data for Name: locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locks (id, expired_at, name, uid) FROM stdin;
\.


--
-- Name: locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locks_id_seq', 7, true);


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
1	a	821fcd0a441062473a386e9297e9cb48b5f189f4	ad48b21e-0805-4a33-9d48-321d4ec49449	91622853c61c3c7516b51a0a9e792e017a4d89d1	["b"]	1	821fcd0a441062473a386e9297e9cb48b5f189f4
2	b	ec25004a81fc656a6c39871564f352d70268c637	2a1565b7-068a-4387-995a-8fccbb52793c	ac428a0d6a3200b922ed73b494f6df58ea7e9776	["c"]	1	ec25004a81fc656a6c39871564f352d70268c637
3	bar	f1267e1d4e06b60c91ef648fb9242e33ddcffa73	f3f83779-d0b1-4b0d-8285-d78f3a31797f	60a916fbc877e55fcbc9722e1de7dee7065c098a	["foo"]	1	f1267e1d4e06b60c91ef648fb9242e33ddcffa73
4	blocking_package	2ae8315faf952e6f69da493286387803ccfad248	11aee238-e662-4370-9e43-754f8301f46c	f1a2334ea04da4341c5fcb13acf9edd2b8692977	[]	1	2ae8315faf952e6f69da493286387803ccfad248
5	c	5bc40b65cca962dcc486673c6999d3b085b4a9ab	dff0e47e-183a-458c-aff9-e371c472ccda	cf601874fdf5829f9a1b1ab56e3440ce857da452	[]	1	5bc40b65cca962dcc486673c6999d3b085b4a9ab
6	errand1	b77c2906dd44672e9d766358ee772213f35555f2	683a8bd8-b870-4c91-af5d-e17feae5b0bd	1ff25c1ef311ee1d570f1edd4380a0a55d90df79	[]	1	b77c2906dd44672e9d766358ee772213f35555f2
7	fails_with_too_much_output	e505f41e8cec5608209392c06950bba5d995bdd8	a0f949aa-a585-42b0-837d-d1cfc5cf7f94	03ebed0bb96961f2969830776a94ade741710d94	[]	1	e505f41e8cec5608209392c06950bba5d995bdd8
8	foo	0ee95716c58cf7aab3ef7301ff907118552c2dda	d10439c3-90b8-4c92-9947-a6f05ce856e3	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
9	foo_1	0ee95716c58cf7aab3ef7301ff907118552c2dda	66237380-1e8a-4d3f-a153-36925b77c8c5	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
10	foo_10	0ee95716c58cf7aab3ef7301ff907118552c2dda	297bc128-d492-43a8-9cf6-5542063f896c	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
11	foo_2	0ee95716c58cf7aab3ef7301ff907118552c2dda	7d2a8007-3433-4574-8797-4b5ba21d8c8c	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
12	foo_3	0ee95716c58cf7aab3ef7301ff907118552c2dda	9c628191-d828-4dbb-a06f-092146979b23	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
13	foo_4	0ee95716c58cf7aab3ef7301ff907118552c2dda	8c0316cb-d523-435d-a415-200bf7d083e8	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
14	foo_5	0ee95716c58cf7aab3ef7301ff907118552c2dda	9cd9ec3b-a829-49a5-9a96-1fa0ba7f985c	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
15	foo_6	0ee95716c58cf7aab3ef7301ff907118552c2dda	99cde850-0d07-4bd1-b42b-e68470987979	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
16	foo_7	0ee95716c58cf7aab3ef7301ff907118552c2dda	e7d4751b-c6dc-420e-acb8-4f53a4735e38	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
17	foo_8	0ee95716c58cf7aab3ef7301ff907118552c2dda	19897770-9e95-4021-b61f-f67984f02511	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
18	foo_9	0ee95716c58cf7aab3ef7301ff907118552c2dda	d69ff435-908e-43ba-bee4-7fd2ad95c7be	02dbbfad33f4ec4bdc5cdaa01909cf8ad2f64d3b	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
\.


--
-- Name: packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('packages_id_seq', 18, true);


--
-- Data for Name: packages_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY packages_release_versions (id, package_id, release_version_id) FROM stdin;
1	1	1
2	2	1
3	3	1
4	4	1
5	5	1
6	6	1
7	7	1
8	8	1
9	9	1
10	10	1
11	11	1
12	12	1
13	13	1
14	14	1
15	15	1
16	16	1
17	17	1
18	18	1
\.


--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('packages_release_versions_id_seq', 18, true);


--
-- Data for Name: persistent_disks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY persistent_disks (id, instance_id, disk_cid, size, active, cloud_properties_json, name) FROM stdin;
\.


--
-- Name: persistent_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('persistent_disks_id_seq', 1, false);


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY records (id, name, type, content, ttl, prio, change_date, domain_id) FROM stdin;
4	0.foobar1.a.simple.bosh	A	192.168.1.2	300	\N	1487106187	1
5	1.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	2
6	1.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	2
7	2.1.168.192.in-addr.arpa	PTR	0.foobar1.a.simple.bosh	300	\N	1487106187	2
8	7c0ef109-a4cb-414f-b663-933604e3ca5e.foobar1.a.simple.bosh	A	192.168.1.2	300	\N	1487106187	1
9	2.1.168.192.in-addr.arpa	PTR	7c0ef109-a4cb-414f-b663-933604e3ca5e.foobar1.a.simple.bosh	300	\N	1487106187	2
10	1.foobar1.a.simple.bosh	A	192.168.1.3	300	\N	1487106195	1
11	3.1.168.192.in-addr.arpa	PTR	1.foobar1.a.simple.bosh	300	\N	1487106195	2
12	6ffe470d-4795-4ffa-a4c0-f50a0fdfa290.foobar1.a.simple.bosh	A	192.168.1.3	300	\N	1487106195	1
13	3.1.168.192.in-addr.arpa	PTR	6ffe470d-4795-4ffa-a4c0-f50a0fdfa290.foobar1.a.simple.bosh	300	\N	1487106195	2
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1487106203	1
2	bosh	NS	ns.bosh	14400	\N	1487106203	1
3	ns.bosh	A	\N	18000	\N	1487106203	1
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('records_id_seq', 13, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	64c06d8c	f
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
\.


--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('release_versions_templates_id_seq', 22, true);


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
1	1	c9b45ef5-a1ce-4cdb-9a5e-2e3eb7edd90c	edf26c3e8e1d0d7c24da9078eeae9b8a3bba6a49	3456b369ea11602dceef012f3c4f0986ac221747	2017-02-14 21:03:01.259173
2	2	bcef9359-8e76-46e7-a491-414e6edac307	9404a55de78847105e41415bf1322e52d38142f3	84b9f99b70222704172c0a8f57ceb391ed0bb8ab	2017-02-14 21:03:01.297658
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rendered_templates_archives_id_seq', 2, true);


--
-- Data for Name: runtime_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY runtime_configs (id, properties, created_at) FROM stdin;
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
20160803151600_add_name_to_persistent_disks.rb
20161031204534_populate_lifecycle_on_instance_spec.rb
\.


--
-- Data for Name: snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY snapshots (id, persistent_disk_id, clean, created_at, snapshot_cid) FROM stdin;
\.


--
-- Name: snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('snapshots_id_seq', 1, false);


--
-- Data for Name: stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY stemcells (id, name, version, cid, sha1, operating_system) FROM stdin;
1	ubuntu-stemcell	1	68aab7c44c857217641784806e2eeac4a3a99d1c	shawone	toronto-os
\.


--
-- Name: stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stemcells_id_seq', 1, true);


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tasks (id, state, "timestamp", description, result, output, checkpoint_time, type, username, deployment_name, started_at) FROM stdin;
1	done	2017-02-14 21:02:55.748895	create release	Created release 'bosh-release/0+dev.1'	/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-52872/sandbox/boshdir/tasks/1	2017-02-14 21:02:54.391581	update_release	test	\N	2017-02-14 21:02:54.391466
2	done	2017-02-14 21:02:57.898586	create stemcell	/stemcells/ubuntu-stemcell/1	/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-52872/sandbox/boshdir/tasks/2	2017-02-14 21:02:57.861183	update_stemcell	test	\N	2017-02-14 21:02:57.861042
3	done	2017-02-14 21:03:21.144466	create deployment	/deployments/simple	/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-52872/sandbox/boshdir/tasks/3	2017-02-14 21:03:01.013755	update_deployment	test	simple	2017-02-14 21:03:01.013642
4	done	2017-02-14 21:03:25.652845	create deployment	/deployments/simple	/private/tmp/mybosh/bosh/tmp/integration-tests-workspace/pid-52872/sandbox/boshdir/tasks/4	2017-02-14 21:03:23.259068	update_deployment	test	simple	2017-02-14 21:03:23.258945
\.


--
-- Name: tasks_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tasks_new_id_seq', 4, true);


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
1	errand1	7f328d7a3dc4ab55246ca3e61552a00d7e29bc1d	68446288-9f80-4351-8122-07399b28421b	4fb7a061a79e5f772425c4876aa8464a06cc07a7	["errand1"]	1	null	7f328d7a3dc4ab55246ca3e61552a00d7e29bc1d	{"errand1.stdout":{"description":"Stdout to print from the errand script","default":"errand1-stdout"},"errand1.stdout_multiplier":{"description":"Number of times stdout will be repeated in the output","default":1},"errand1.stderr":{"description":"Stderr to print from the errand script","default":"errand1-stderr"},"errand1.stderr_multiplier":{"description":"Number of times stderr will be repeated in the output","default":1},"errand1.run_package_file":{"description":"Should bin/run run script from errand1 package to show that package is present on the vm","default":false},"errand1.exit_code":{"description":"Exit code to return from the errand script","default":0},"errand1.blocking_errand":{"description":"Whether to block errand execution","default":false},"errand1.logs.stdout":{"description":"Output to place into sys/log/errand1/stdout.log","default":"errand1-stdout-log"},"errand1.logs.custom":{"description":"Output to place into sys/log/custom.log","default":"errand1-custom-log"}}	\N	\N
2	errand_without_package	46355c83cafbe162d99bb46a53006b7a52f677b6	7e893a6b-7bea-4b60-a856-f2fb89a53cd9	e16e9c976e7a83aa5125070969eb4aede8ecd371	[]	1	null	46355c83cafbe162d99bb46a53006b7a52f677b6	{}	\N	\N
3	fails_with_too_much_output	a1667f8047671c33bc75ba5163b5626407cf5a22	c4f4871f-2bc6-40f6-9ad2-ea43095674a6	52fdab927a7ab4a2d0597d444c99d20ccf68a0e2	["fails_with_too_much_output"]	1	null	a1667f8047671c33bc75ba5163b5626407cf5a22	{}	\N	\N
4	foobar	025e461e609c1596443e845f64af1d1239a1a32b	4f636b73-44a2-420e-9452-79e2de8515d1	cf68241f29a30dce59d1b82fa8f24aefcf618211	["foo","bar"]	1	null	025e461e609c1596443e845f64af1d1239a1a32b	{"test_property":{"description":"A test property","default":1},"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"dynamic_drain_wait1":{"description":"Number of seconds to wait when drain script is first called","default":-3},"dynamic_drain_wait2":{"description":"Number of seconds to wait when drain script is called a second time","default":-2},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}	\N	\N
5	foobar_with_bad_properties	a61cb7a7ed77e9535ebd20f931b492a8e9997830	e2a8d430-0cbb-4f95-86a3-5f64decd4993	b1a5195a4cd21fc31fe452ac02af831754b193df	["foo","bar"]	1	null	a61cb7a7ed77e9535ebd20f931b492a8e9997830	{"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}	\N	\N
6	foobar_with_bad_properties_2	99f3d044ad5d4dcfa23dce45e165edf7ac248225	5dc14e78-9297-4a2f-9c52-079ecaa4b035	fe3e2e71e5f52acd25a406e460e077a03638ea8c	["foo","bar"]	1	null	99f3d044ad5d4dcfa23dce45e165edf7ac248225	{"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}	\N	\N
7	foobar_without_packages	6cb4d446ecb1c0ac8cfa8e099873114f29c20ea8	0a9d8ca2-6239-409e-9de6-94b3a0c9e8a6	c964c67107af6ef2acfb815ff729460163739dd7	[]	1	null	6cb4d446ecb1c0ac8cfa8e099873114f29c20ea8	{}	\N	\N
8	has_drain_script	ef4301ef90caf2aa524b68aba7ff7653a194a8b8	adf0b017-7ed8-4a6b-af19-c63399b45c67	4daf86b14f341f5a67d512c279809870e141a56d	["foo","bar"]	1	null	ef4301ef90caf2aa524b68aba7ff7653a194a8b8	{"test_property":{"description":"A test property","default":1},"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"dynamic_drain_wait1":{"description":"Number of seconds to wait when drain script is first called","default":-3},"dynamic_drain_wait2":{"description":"Number of seconds to wait when drain script is called a second time","default":-2},"network_name":{"description":"Network name used for determining printed IP address"}}	\N	\N
9	id_job	03639fea005823b43a511fe788f796fca1c9ff56	88960830-3308-46c5-9ba4-fa76923ffc4a	434316ba4c7b6769f443f6e11b8fd8e721424055	[]	1	null	03639fea005823b43a511fe788f796fca1c9ff56	{}	\N	\N
10	job_1_with_many_properties	383c1f964898cdd3d6ab108857aa00145f371004	f55dbfcd-6e2a-4162-8c45-94ebda862862	eb4c1c172cfd7c2b672902c83167df0b4e8f8e7a	[]	1	null	383c1f964898cdd3d6ab108857aa00145f371004	{"smurfs.color":{"description":"The color of the smurfs","default":"blue"},"gargamel.color":{"description":"The color of gargamel it is required"}}	\N	\N
11	job_1_with_post_deploy_script	7aaaaf94f16bd171602f67b17c5a3222b5476215	3a9ddb2a-9dc7-4025-bbd7-c6f56a74b53b	a29e5b0039543820187595c59facdf63c65fa7ac	[]	1	null	7aaaaf94f16bd171602f67b17c5a3222b5476215	{"post_deploy_message_1":{"description":"A message echoed by the post-deploy script 1","default":"this is post_deploy_message_1"}}	\N	\N
12	job_1_with_pre_start_script	551696c571b5e6d120567be5a2dc42eb23be9de7	38873b3a-6b04-4c67-b727-53326a12bf37	601f097042b567a371760ea268cbe100256b2af1	[]	1	null	551696c571b5e6d120567be5a2dc42eb23be9de7	{"pre_start_message_1":{"description":"A message echoed by the pre-start script 1","default":"this is pre_start_message_1"}}	\N	\N
13	job_2_with_many_properties	7ae8ba20811b57b75dfb8ad525149aaa01f38df6	293c9f49-4b77-4475-8f65-2e3d03477863	95cf69a119f668f35b74e3c9733a988d83e035b7	[]	1	null	7ae8ba20811b57b75dfb8ad525149aaa01f38df6	{"smurfs.color":{"description":"The color of the smurfs","default":"blue"},"gargamel.color":{"description":"The color of gargamel it is required"}}	\N	\N
14	job_2_with_post_deploy_script	a4e8beab4bd8d6dee0110eb9e902593b8355d648	c1745396-24e8-41e5-8375-e88930c0e6fe	fa9ec3230c06e2dfd89d55525dbd6cf84c28691d	[]	1	null	a4e8beab4bd8d6dee0110eb9e902593b8355d648	{}	\N	\N
15	job_2_with_pre_start_script	48cbe195e05f7932448f67614ac945f7123f9468	d8fc284c-0b9b-48e6-a094-427e53148db0	3073927287f783d6e1e63e13b5932e9154801174	[]	1	null	48cbe195e05f7932448f67614ac945f7123f9468	{}	\N	\N
16	job_3_with_broken_post_deploy_script	a9556deadf132fffc4e748a2ba3cbf608a78ea9b	645449c6-477b-49f6-9d04-9c436a5c73d7	656b097b4e43cad6b88e0c3401588a91d71b0653	[]	1	null	a9556deadf132fffc4e748a2ba3cbf608a78ea9b	{}	\N	\N
17	job_that_modifies_properties	4f0d51063f726d82de480cc5e2ce34ffbf2197c3	23fdb171-a528-4830-aca3-e4c65293c901	3eaf3eba0467346bef06046aebdac6271bef707c	["foo","bar"]	1	null	4f0d51063f726d82de480cc5e2ce34ffbf2197c3	{"some_namespace.test_property":{"description":"A test property","default":1}}	\N	\N
18	job_with_blocking_compilation	e3196092c9350a8fb8e05adae02f863ef90620a3	077edcb3-bf01-4291-b494-2802e02c7389	f236b86d2fc0bbe6fa246474300b42b82f26c2dc	["blocking_package"]	1	null	e3196092c9350a8fb8e05adae02f863ef90620a3	{}	\N	\N
19	job_with_many_packages	baca495de93c403ff7a0b4536cb808713ce5a6e3	ad0b1e9d-78d5-414f-9ba6-688fcad96587	503b5be68afc3cc305a66b7beed49b6eaa8df10a	["foo_1","foo_2","foo_3","foo_4","foo_5","foo_6","foo_7","foo_8","foo_9","foo_10"]	1	null	baca495de93c403ff7a0b4536cb808713ce5a6e3	{}	\N	\N
20	job_with_post_start_script	0965c83e1af2d0cdbfabf21bcd4808d142e2a7a5	4262fb00-7e3b-46cc-84f4-f016f74e86bc	1e37a3f4865705da8919b20cab37c8809140f94c	[]	1	null	0965c83e1af2d0cdbfabf21bcd4808d142e2a7a5	{"post_start_message":{"description":"A message echoed by the post-start script","default":"this is post_start_message"},"job_pidfile":{"description":"Path to jobs pid file","default":"/var/vcap/sys/run/job_with_post_start_script.pid"},"exit_code":{"default":0}}	\N	\N
22	transitive_deps	8020351635287d3158b65b50f8c728e71051c8a7	85b8f6f4-0f0e-4975-931e-cd5ce39f2219	aee2a5402f2ee55bedbdc61df0650eaf3a4b3fe0	["a"]	1	null	8020351635287d3158b65b50f8c728e71051c8a7	{}	\N	\N
21	job_with_property_types	19e3428b15aa041130d26edf679c01829f5f79be	7438d676-3da6-4d03-b049-922593d6ca9b	71b51d1cbaeb69b7349a01e210fc2be215d33ada	[]	1	null	19e3428b15aa041130d26edf679c01829f5f79be	{"smurfs.phone_password":{"description":"The phone password of the smurfs village","type":"password"},"smurfs.happiness_level":{"description":"The level of the Smurfs overall happiness","type":"happy"},"gargamel.secret_recipe":{"description":"The secret recipe of gargamel to take down the smurfs","type":"password"},"gargamel.password":{"description":"The password I used for everything","default":"abc123","type":"password"},"gargamel.cert":{"description":"The certificate used for everything","type":"certificate"},"gargamel.hard_coded_cert":{"description":"The hardcoded cert of gargamel","default":"good luck hardcoding certs and private keys","type":"certificate"}}	\N	\N
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('templates_id_seq', 22, true);


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
-- Data for Name: vms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vms (id, agent_id, cid, deployment_id, credentials_json, env_json, trusted_certs_sha1) FROM stdin;
\.


--
-- Name: vms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vms_id_seq', 1, false);


--
-- Name: cloud_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cloud_configs
    ADD CONSTRAINT cloud_configs_pkey PRIMARY KEY (id);


--
-- Name: compiled_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages
    ADD CONSTRAINT compiled_packages_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deployment_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_problems
    ADD CONSTRAINT deployment_problems_pkey PRIMARY KEY (id);


--
-- Name: deployment_properties_deployment_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_name_key UNIQUE (deployment_id, name);


--
-- Name: deployment_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployment_properties
    ADD CONSTRAINT deployment_properties_pkey PRIMARY KEY (id);


--
-- Name: deployments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_name_key UNIQUE (name);


--
-- Name: deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_release_version_id_deployment__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_deployment__key UNIQUE (release_version_id, deployment_id);


--
-- Name: deployments_stemcells_deployment_id_stemcell_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_stemcell_id_key UNIQUE (deployment_id, stemcell_id);


--
-- Name: deployments_stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_pkey PRIMARY KEY (id);


--
-- Name: deployments_teams_deployment_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_team_id_key UNIQUE (deployment_id, team_id);


--
-- Name: director_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY director_attributes
    ADD CONSTRAINT director_attributes_pkey PRIMARY KEY (id);


--
-- Name: dns_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dns_schema
    ADD CONSTRAINT dns_schema_pkey PRIMARY KEY (filename);


--
-- Name: domains_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_name_key UNIQUE (name);


--
-- Name: domains_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- Name: ephemeral_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ephemeral_blobs
    ADD CONSTRAINT ephemeral_blobs_pkey PRIMARY KEY (id);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: instances_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_agent_id_key UNIQUE (agent_id);


--
-- Name: instances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: instances_templates_instance_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_instance_id_template_id_key UNIQUE (instance_id, template_id);


--
-- Name: instances_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances_templates
    ADD CONSTRAINT instances_templates_pkey PRIMARY KEY (id);


--
-- Name: instances_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_uuid_key UNIQUE (uuid);


--
-- Name: instances_vm_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_cid_key UNIQUE (vm_cid);


--
-- Name: instances_vm_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_id_key UNIQUE (vm_id);


--
-- Name: ip_addresses_address_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_address_key UNIQUE (address);


--
-- Name: ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: local_dns_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_pkey PRIMARY KEY (id);


--
-- Name: local_dns_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_pkey PRIMARY KEY (id);


--
-- Name: locks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_name_key UNIQUE (name);


--
-- Name: locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_pkey PRIMARY KEY (id);


--
-- Name: locks_uid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_uid_key UNIQUE (uid);


--
-- Name: log_bundles_blobstore_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_blobstore_id_key UNIQUE (blobstore_id);


--
-- Name: log_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_bundles
    ADD CONSTRAINT log_bundles_pkey PRIMARY KEY (id);


--
-- Name: orphan_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: orphan_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_disks
    ADD CONSTRAINT orphan_disks_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: packages_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages
    ADD CONSTRAINT packages_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: packages_release_versions_package_id_release_version_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_release_version_id_key UNIQUE (package_id, release_version_id);


--
-- Name: packages_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY packages_release_versions
    ADD CONSTRAINT packages_release_versions_pkey PRIMARY KEY (id);


--
-- Name: persistent_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: persistent_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persistent_disks
    ADD CONSTRAINT persistent_disks_pkey PRIMARY KEY (id);


--
-- Name: records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_pkey PRIMARY KEY (id);


--
-- Name: release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions
    ADD CONSTRAINT release_versions_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_release_version_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_template_id_key UNIQUE (release_version_id, template_id);


--
-- Name: releases_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_name_key UNIQUE (name);


--
-- Name: releases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: rendered_templates_archives_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_pkey PRIMARY KEY (id);


--
-- Name: runtime_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY runtime_configs
    ADD CONSTRAINT runtime_configs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_pkey PRIMARY KEY (id);


--
-- Name: snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY snapshots
    ADD CONSTRAINT snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: stemcells_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_name_version_key UNIQUE (name, version);


--
-- Name: stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_pkey PRIMARY KEY (id);


--
-- Name: tasks_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_new_pkey PRIMARY KEY (id);


--
-- Name: tasks_teams_task_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_team_id_key UNIQUE (task_id, team_id);


--
-- Name: teams_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: templates_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: vms_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_agent_id_key UNIQUE (agent_id);


--
-- Name: vms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_pkey PRIMARY KEY (id);


--
-- Name: blobstore_id_sha1_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX blobstore_id_sha1_idx ON local_dns_blobs USING btree (blobstore_id, sha1);


--
-- Name: cloud_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX cloud_configs_created_at_index ON cloud_configs USING btree (created_at);


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
-- Name: name_ip_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX name_ip_idx ON local_dns_records USING btree (name, ip);


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
-- Name: deployments_runtime_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_runtime_config_id_fkey FOREIGN KEY (runtime_config_id) REFERENCES runtime_configs(id);


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
-- Name: instances_vm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_id_fkey FOREIGN KEY (vm_id) REFERENCES vms(id);


--
-- Name: ip_addresses_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: local_dns_records_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE;


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
-- Name: public; Type: ACL; Schema: -; Owner: pivotal
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pivotal;
GRANT ALL ON SCHEMA public TO pivotal;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

