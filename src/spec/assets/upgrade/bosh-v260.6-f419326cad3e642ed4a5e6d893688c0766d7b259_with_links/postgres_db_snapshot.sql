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
-- Name: cloud_configs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cloud_configs ALTER COLUMN id SET DEFAULT nextval('cloud_configs_id_seq'::regclass);


--
-- Name: compiled_packages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY compiled_packages ALTER COLUMN id SET DEFAULT nextval('compiled_packages_id_seq'::regclass);


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
-- Name: ephemeral_blobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ephemeral_blobs ALTER COLUMN id SET DEFAULT nextval('ephemeral_blobs_id_seq'::regclass);


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

ALTER TABLE ONLY local_dns_blobs ALTER COLUMN id SET DEFAULT nextval('local_dns_blobs_id_seq'::regclass);


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
-- Name: vms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms ALTER COLUMN id SET DEFAULT nextval('vms_id_seq'::regclass);


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cloud_configs (id, properties, created_at) FROM stdin;
1	azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\n  vm_type: a\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n    - name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nvm_types:\n- cloud_properties: {}\n  name: a\n	2017-06-19 19:38:17.482561
\.


--
-- Name: cloud_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cloud_configs_id_seq', 1, true);


--
-- Data for Name: compiled_packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY compiled_packages (id, blobstore_id, sha1, dependency_key, build, package_id, dependency_key_sha1, stemcell_os, stemcell_version) FROM stdin;
1	b837c8e6-a22e-4bde-76ed-ec10fb069c1c	da917c507cf919282ec39dee56c3bc2403d936cc	[]	1	2	97d170e1550eee4afc0af065b78cda302a97674c	toronto-os	1
2	6f43c14e-813c-492a-4cf6-80f44a523144	cb580fbe2395d3f262778be4ceef6d20639bdcac	[["pkg_2","fa48497a19f12e925b32fcb8f5ca2b42144e4444"]]	1	3	b048798b462817f4ae6a5345dd9a0c45d1a1c8ea	toronto-os	1
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
1	simple	---\ndirector_uuid: deadbeef\njobs:\n- azs:\n  - z1\n  instances: 1\n  name: my_api\n  networks:\n  - name: a\n  properties: {}\n  vm_type: a\n  stemcell: default\n  templates:\n  - consumes:\n      backup_db:\n        from: link_alias\n      db:\n        from: link_alias\n    name: api_server\n  env:\n    bosh:\n      password: foobar\n- azs:\n  - z1\n  instances: 1\n  name: aliased_postgres\n  networks:\n  - name: a\n  properties: {}\n  vm_type: a\n  stemcell: default\n  templates:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: link_alias\n  env:\n    bosh:\n      password: foobar\n- azs:\n  - z1\n  instances: 1\n  lifecycle: errand\n  name: my_errand\n  networks:\n  - name: a\n  properties: {}\n  vm_type: a\n  stemcell: default\n  templates:\n  - consumes:\n      backup_db:\n        from: link_alias\n      db:\n        from: link_alias\n    name: errand_with_links\n  env:\n    bosh:\n      password: foobar\n- azs:\n  - z1\n  instances: 1\n  name: job_with_no_links\n  networks:\n  - name: a\n  properties: {}\n  vm_type: a\n  stemcell: default\n  templates:\n  - name: provider\n  env:\n    bosh:\n      password: foobar\nname: simple\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: 1\n	1	{}	\N
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
1	\N	test	2017-06-19 19:38:17.484753	update	cloud-config	\N	\N	\N	\N	\N	{}
2	\N	test	2017-06-19 19:38:18.059501	create	deployment	simple	\N	3	simple	\N	{}
3	\N	test	2017-06-19 19:38:18.478713	create	instance	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
4	\N	test	2017-06-19 19:38:18.486517	create	vm	\N	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
5	4	test	2017-06-19 19:38:18.515492	create	vm	25443	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
6	3	test	2017-06-19 19:38:18.621315	create	instance	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
7	\N	test	2017-06-19 19:38:19.636042	delete	instance	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
8	\N	test	2017-06-19 19:38:19.641078	delete	vm	25443	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
9	8	test	2017-06-19 19:38:19.655196	delete	vm	25443	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
10	7	test	2017-06-19 19:38:19.681715	delete	instance	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	\N	3	simple	compilation-7aeacf58-23bb-41af-8fdf-a1429533f487/c9134ecf-1166-48e3-a42f-d65ed77057ec	{}
11	\N	test	2017-06-19 19:38:19.81076	create	instance	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
12	\N	test	2017-06-19 19:38:19.819331	create	vm	\N	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
13	12	test	2017-06-19 19:38:19.84492	create	vm	25449	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
14	11	test	2017-06-19 19:38:20.912185	create	instance	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
15	\N	test	2017-06-19 19:38:21.925458	delete	instance	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
16	\N	test	2017-06-19 19:38:21.930228	delete	vm	25449	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
17	16	test	2017-06-19 19:38:21.94461	delete	vm	25449	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
18	15	test	2017-06-19 19:38:21.965257	delete	instance	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	\N	3	simple	compilation-925aca0b-3cb9-4f8b-8552-de0155492446/d6a1434e-960c-4778-b849-040df881379b	{}
19	\N	test	2017-06-19 19:38:22.106421	create	vm	\N	\N	3	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
20	\N	test	2017-06-19 19:38:22.1059	create	vm	\N	\N	3	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
21	\N	test	2017-06-19 19:38:22.107107	create	vm	\N	\N	3	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
22	19	test	2017-06-19 19:38:22.247385	create	vm	25457	\N	3	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
23	20	test	2017-06-19 19:38:22.258414	create	vm	25458	\N	3	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
24	21	test	2017-06-19 19:38:22.262975	create	vm	25456	\N	3	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
25	\N	test	2017-06-19 19:38:23.385388	create	instance	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	\N	3	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{"az":"z1"}
26	25	test	2017-06-19 19:38:29.511717	create	instance	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	\N	3	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
27	\N	test	2017-06-19 19:38:29.519723	create	instance	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	\N	3	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{"az":"z1"}
28	27	test	2017-06-19 19:38:34.671305	create	instance	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	\N	3	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
29	\N	test	2017-06-19 19:38:34.679302	create	instance	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	\N	3	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{"az":"z1"}
30	29	test	2017-06-19 19:38:41.764916	create	instance	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	\N	3	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
31	2	test	2017-06-19 19:38:41.783486	create	deployment	simple	\N	3	simple	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
32	\N	test	2017-06-19 19:38:42.420812	update	deployment	simple	\N	4	simple	\N	{}
33	\N	test	2017-06-19 19:38:42.69377	stop	instance	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	\N	4	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
34	\N	test	2017-06-19 19:38:42.70642	delete	vm	25457	\N	4	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
35	34	test	2017-06-19 19:38:42.722901	delete	vm	25457	\N	4	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
36	33	test	2017-06-19 19:38:42.741446	stop	instance	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	\N	4	simple	my_api/404278d5-e480-4430-b2b5-9991fc452c4e	{}
37	\N	test	2017-06-19 19:38:42.751397	stop	instance	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	\N	4	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
38	\N	test	2017-06-19 19:38:42.763441	delete	vm	25458	\N	4	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
39	38	test	2017-06-19 19:38:42.776555	delete	vm	25458	\N	4	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
40	37	test	2017-06-19 19:38:42.797355	stop	instance	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	\N	4	simple	aliased_postgres/f9f8af86-9431-4493-8dd0-baa9ebcd5da2	{}
41	\N	test	2017-06-19 19:38:42.806974	stop	instance	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	\N	4	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
42	\N	test	2017-06-19 19:38:42.818008	delete	vm	25456	\N	4	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
43	42	test	2017-06-19 19:38:42.833945	delete	vm	25456	\N	4	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
44	41	test	2017-06-19 19:38:42.85482	stop	instance	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	\N	4	simple	job_with_no_links/e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	{}
45	32	test	2017-06-19 19:38:42.865453	update	deployment	simple	\N	4	simple	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 45, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, vm_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid, agent_id, credentials_json, trusted_certs_sha1, update_completed, ignore) FROM stdin;
3	my_errand	0	1	\N	started	f	3ebdff9a-8c82-4d23-aec1-0066fdd0f5ca	z1	\N	f	t	[]	\N	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	f	f
1	my_api	0	1	\N	detached	f	404278d5-e480-4430-b2b5-9991fc452c4e	z1	{}	f	t	["0.my-api.a.simple.bosh","404278d5-e480-4430-b2b5-9991fc452c4e.my-api.a.simple.bosh"]	{"deployment":"simple","job":{"name":"my_api","templates":[{"name":"api_server","version":"76ff26229b603294a6f540e53faf68a2424cdf59","sha1":"7785c440aa26d49ac34371a3c9967bfdf8efc9ca","blobstore_id":"b3ac7b5b-bb02-42ec-9741-2a88c4b3c180"}],"template":"api_server","version":"76ff26229b603294a6f540e53faf68a2424cdf59","sha1":"7785c440aa26d49ac34371a3c9967bfdf8efc9ca","blobstore_id":"b3ac7b5b-bb02-42ec-9741-2a88c4b3c180"},"index":0,"bootstrap":true,"lifecycle":"service","name":"my_api","id":"404278d5-e480-4430-b2b5-9991fc452c4e","az":"z1","networks":{"a":{"ip":"192.168.1.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{"bosh":{"password":"foobar"}},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"cb580fbe2395d3f262778be4ceef6d20639bdcac","blobstore_id":"6f43c14e-813c-492a-4cf6-80f44a523144"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"db":{"deployment_name":"simple","networks":["a"],"properties":null,"instances":[{"name":"aliased_postgres","index":0,"bootstrap":true,"id":"f9f8af86-9431-4493-8dd0-baa9ebcd5da2","az":"z1","address":"192.168.1.3"}]},"backup_db":{"deployment_name":"simple","networks":["a"],"properties":null,"instances":[{"name":"aliased_postgres","index":0,"bootstrap":true,"id":"f9f8af86-9431-4493-8dd0-baa9ebcd5da2","az":"z1","address":"192.168.1.3"}]}},"address":"192.168.1.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true},"persistent_disk":0,"template_hashes":{"api_server":"fede710487492c882c7e808040a4a8f44f39ec62"},"rendered_templates_archive":{"blobstore_id":"fd957939-9324-444c-90c1-a876f6325981","sha1":"aadbc86753218d6dc9275dd9a2a587c6367f85cb"},"configuration_hash":"481ed4f6f4c60eabee765270a45224ffe3fd6b1c"}	\N	\N	null	\N	t	f
2	aliased_postgres	0	1	\N	detached	f	f9f8af86-9431-4493-8dd0-baa9ebcd5da2	z1	{}	f	t	["0.aliased-postgres.a.simple.bosh","f9f8af86-9431-4493-8dd0-baa9ebcd5da2.aliased-postgres.a.simple.bosh"]	{"deployment":"simple","job":{"name":"aliased_postgres","templates":[{"name":"backup_database","version":"29322b71c9a475beae1249873d8f6e136335448b","sha1":"a99b1eed86506adbdb55e6758afc2e86612fa938","blobstore_id":"e921e2af-57cb-4103-94a6-70525c6683be"}],"template":"backup_database","version":"29322b71c9a475beae1249873d8f6e136335448b","sha1":"a99b1eed86506adbdb55e6758afc2e86612fa938","blobstore_id":"e921e2af-57cb-4103-94a6-70525c6683be"},"index":0,"bootstrap":true,"lifecycle":"service","name":"aliased_postgres","id":"f9f8af86-9431-4493-8dd0-baa9ebcd5da2","az":"z1","networks":{"a":{"ip":"192.168.1.3","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{"bosh":{"password":"foobar"}},"packages":{},"properties":{"backup_database":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.3","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true},"persistent_disk":0,"template_hashes":{"backup_database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"2a597eb9-f9a2-41fb-b0ce-d95d998e9572","sha1":"63f1fe056dd616e21adda1564a6bbbb293ecfc57"},"configuration_hash":"4e4c9c0b7e76b5bc955b215edbd839e427d581aa"}	\N	\N	null	\N	t	f
4	job_with_no_links	0	1	\N	detached	f	e35504c2-26d8-4c61-b8ad-c20e5dfbbae0	z1	{}	f	t	["0.job-with-no-links.a.simple.bosh","e35504c2-26d8-4c61-b8ad-c20e5dfbbae0.job-with-no-links.a.simple.bosh"]	{"deployment":"simple","job":{"name":"job_with_no_links","templates":[{"name":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"1de4688c986988bf6aa4838f3c77a57bf2563c94","blobstore_id":"92632dc4-274a-4910-a4bb-c9d3519ba2e1"}],"template":"provider","version":"e1ff4ff9a6304e1222484570a400788c55154b1c","sha1":"1de4688c986988bf6aa4838f3c77a57bf2563c94","blobstore_id":"92632dc4-274a-4910-a4bb-c9d3519ba2e1"},"index":0,"bootstrap":true,"lifecycle":"service","name":"job_with_no_links","id":"e35504c2-26d8-4c61-b8ad-c20e5dfbbae0","az":"z1","networks":{"a":{"ip":"192.168.1.4","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{"bosh":{"password":"foobar"}},"packages":{},"properties":{"provider":{"a":"default_a","b":null,"c":"default_c"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.4","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true},"persistent_disk":0,"template_hashes":{"provider":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"2230fedc-76e3-4d83-a31f-4be41f3aa036","sha1":"966cd7acb767d481050d5e60e341bbf3f03fe10b"},"configuration_hash":"90c5d1358d128117989fc21f2897a25c99205e50"}	\N	\N	null	\N	t	f
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_id_seq', 6, true);


--
-- Data for Name: instances_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances_templates (id, instance_id, template_id) FROM stdin;
1	1	2
2	2	8
3	4	19
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_templates_id_seq', 3, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ip_addresses (id, network_name, address, static, instance_id, created_at, task_id) FROM stdin;
1	a	3232235778	f	1	2017-06-19 19:38:18.25163	3
2	a	3232235779	f	2	2017-06-19 19:38:18.267847	3
3	a	3232235780	f	4	2017-06-19 19:38:18.279247	3
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 5, true);


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
1	pkg_1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b	85dfefe2-fd8d-417d-8ed3-0a8c510b5c72	c23b7e56c5c2ecb4baed8c3bd7a56c581e788e17	[]	1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b
2	pkg_2	fa48497a19f12e925b32fcb8f5ca2b42144e4444	56cce084-0d95-49cb-81e9-205ec9f1521d	7f7412068feb7f6a0aad16afcb09ddd7ff723db5	[]	1	fa48497a19f12e925b32fcb8f5ca2b42144e4444
3	pkg_3_depends_on_2	2dfa256bc0b0750ae9952118c428b0dcd1010305	6acfd97b-6441-40a1-b874-588fb3e18d89	ea0a4ce49dcfb493d369182704820244700aafe2	["pkg_2"]	1	2dfa256bc0b0750ae9952118c428b0dcd1010305
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
\.


--
-- Name: persistent_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('persistent_disks_id_seq', 1, false);


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY records (id, name, type, content, ttl, prio, change_date, domain_id) FROM stdin;
4	0.my-api.a.simple.bosh	A	192.168.1.2	300	\N	1497901104	1
5	1.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	2
6	1.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	2
7	2.1.168.192.in-addr.arpa	PTR	0.my-api.a.simple.bosh	300	\N	1497901104	2
8	404278d5-e480-4430-b2b5-9991fc452c4e.my-api.a.simple.bosh	A	192.168.1.2	300	\N	1497901104	1
9	2.1.168.192.in-addr.arpa	PTR	404278d5-e480-4430-b2b5-9991fc452c4e.my-api.a.simple.bosh	300	\N	1497901104	2
10	0.aliased-postgres.a.simple.bosh	A	192.168.1.3	300	\N	1497901110	1
11	3.1.168.192.in-addr.arpa	PTR	0.aliased-postgres.a.simple.bosh	300	\N	1497901110	2
12	f9f8af86-9431-4493-8dd0-baa9ebcd5da2.aliased-postgres.a.simple.bosh	A	192.168.1.3	300	\N	1497901110	1
13	3.1.168.192.in-addr.arpa	PTR	f9f8af86-9431-4493-8dd0-baa9ebcd5da2.aliased-postgres.a.simple.bosh	300	\N	1497901110	2
14	0.job-with-no-links.a.simple.bosh	A	192.168.1.4	300	\N	1497901115	1
15	4.1.168.192.in-addr.arpa	PTR	0.job-with-no-links.a.simple.bosh	300	\N	1497901115	2
16	e35504c2-26d8-4c61-b8ad-c20e5dfbbae0.job-with-no-links.a.simple.bosh	A	192.168.1.4	300	\N	1497901115	1
17	4.1.168.192.in-addr.arpa	PTR	e35504c2-26d8-4c61-b8ad-c20e5dfbbae0.job-with-no-links.a.simple.bosh	300	\N	1497901115	2
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1497901122	1
2	bosh	NS	ns.bosh	14400	\N	1497901122	1
3	ns.bosh	A	\N	18000	\N	1497901122	1
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('records_id_seq', 17, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	f419326ca	t
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
\.


--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('release_versions_templates_id_seq', 20, true);


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
1	1	fd957939-9324-444c-90c1-a876f6325981	aadbc86753218d6dc9275dd9a2a587c6367f85cb	481ed4f6f4c60eabee765270a45224ffe3fd6b1c	2017-06-19 19:38:18.351542
2	2	2a597eb9-f9a2-41fb-b0ce-d95d998e9572	63f1fe056dd616e21adda1564a6bbbb293ecfc57	4e4c9c0b7e76b5bc955b215edbd839e427d581aa	2017-06-19 19:38:18.385942
3	4	2230fedc-76e3-4d83-a31f-4be41f3aa036	966cd7acb767d481050d5e60e341bbf3f03fe10b	90c5d1358d128117989fc21f2897a25c99205e50	2017-06-19 19:38:18.420199
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rendered_templates_archives_id_seq', 3, true);


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
1	done	2017-06-19 19:38:16.051604	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-24937/sandbox/boshdir/tasks/1	2017-06-19 19:38:14.931	update_release	test	\N	2017-06-19 19:38:14.930894
2	done	2017-06-19 19:38:17.136075	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-24937/sandbox/boshdir/tasks/2	2017-06-19 19:38:17.047747	update_stemcell	test	\N	2017-06-19 19:38:17.047601
3	done	2017-06-19 19:38:41.798957	create deployment	/deployments/simple	/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-24937/sandbox/boshdir/tasks/3	2017-06-19 19:38:18.041817	update_deployment	test	simple	2017-06-19 19:38:18.041699
4	done	2017-06-19 19:38:42.869614	create deployment	/deployments/simple	/Users/pivotal/Projects/bosh/tmp/integration-tests-workspace/pid-24937/sandbox/boshdir/tasks/4	2017-06-19 19:38:42.393064	update_deployment	test	simple	2017-06-19 19:38:42.392933
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
1	addon	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	a62bbef4-01ac-4957-8c40-fdee16e5d695	430eaff46d1b1dd8dfc07ba190789f0b61500c57	[]	1	null	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	{}	[{"name":"db","type":"db"}]	\N
2	api_server	76ff26229b603294a6f540e53faf68a2424cdf59	b3ac7b5b-bb02-42ec-9741-2a88c4b3c180	7785c440aa26d49ac34371a3c9967bfdf8efc9ca	["pkg_3_depends_on_2"]	1	null	76ff26229b603294a6f540e53faf68a2424cdf59	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
3	api_server_with_bad_link_types	058b26819bd6561a75c2fed45ec49e671c9fbc6a	4f95a77f-65eb-4ee5-bae9-41fa3bfb2741	fd9cebd1cb25c0c51dcc1d5510c4697da69903ae	["pkg_3_depends_on_2"]	1	null	058b26819bd6561a75c2fed45ec49e671c9fbc6a	{}	[{"name":"db","type":"bad_link"},{"name":"backup_db","type":"bad_link_2"},{"name":"some_link_name","type":"bad_link_3"}]	\N
4	api_server_with_bad_optional_links	8a2485f1de3d99657e101fd269202c39cf3b5d73	363ad095-a960-4608-868d-4baf7ea62615	6492b1a8b1ad3875c9ad0df7b15dec0c3c53b290	["pkg_3_depends_on_2"]	1	null	8a2485f1de3d99657e101fd269202c39cf3b5d73	{}	[{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
5	api_server_with_optional_db_link	00831c288b4a42454543ff69f71360634bd06b7b	249c748d-867d-48cc-bd96-3ee905967980	c3b627e9c730a7a7717dc059566b53ecf7f30a15	["pkg_3_depends_on_2"]	1	null	00831c288b4a42454543ff69f71360634bd06b7b	{}	[{"name":"db","type":"db","optional":true}]	\N
6	api_server_with_optional_links_1	0efc908dd04d84858e3cf8b75c326f35af5a5a98	0c0de456-0835-49eb-9f88-d6ac7caab354	697c0fde8afac2b812bbd52bedfe854883dae6d7	["pkg_3_depends_on_2"]	1	null	0efc908dd04d84858e3cf8b75c326f35af5a5a98	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"},{"name":"optional_link_name","type":"optional_link_type","optional":true}]	\N
7	api_server_with_optional_links_2	15f815868a057180e21dbac61629f73ad3558fec	d0b31716-7a7e-49a9-a8a2-9274ac850ba0	d941ea190726c9ab6968370c5b99a72e4e6a1d67	["pkg_3_depends_on_2"]	1	null	15f815868a057180e21dbac61629f73ad3558fec	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db","optional":true}]	\N
8	backup_database	29322b71c9a475beae1249873d8f6e136335448b	e921e2af-57cb-4103-94a6-70525c6683be	a99b1eed86506adbdb55e6758afc2e86612fa938	[]	1	null	29322b71c9a475beae1249873d8f6e136335448b	{}	\N	[{"name":"backup_db","type":"db"}]
9	consumer	142c10d6cd586cd9b092b2618922194b608160f7	ed8286a5-3c76-4a99-98da-0638d35c49f1	d8032ed186f3e1a90e881f85b5cf8046dedb680a	[]	1	null	142c10d6cd586cd9b092b2618922194b608160f7	{}	[{"name":"provider","type":"provider"}]	\N
10	database	f2929b306c9d89bede1b37cc27f8fa71bb1fd8e8	4426bef4-85a0-4d49-a720-06c1dc144bc9	663b55e8511ef9656a67f7ee214c3ed1e947d79f	[]	1	null	f2929b306c9d89bede1b37cc27f8fa71bb1fd8e8	{"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db","type":"db"}]
11	database_with_two_provided_link_of_same_type	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	e568540c-d28d-4dae-bc3e-3fcbacfcc2e7	31f91ad795c405f900177374b7195a135f36e186	[]	1	null	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	{"test":{"description":"test property","default":"default test property"}}	\N	[{"name":"db1","type":"db"},{"name":"db2","type":"db"}]
12	errand_with_links	87c3457f84c8e06f950c08c7e114df2cad29c43d	4f7df60b-65ef-4104-8862-365ccdacde75	6fc92c5bec6e7a03e2a2ee8d0597ac8315a1a072	[]	1	null	87c3457f84c8e06f950c08c7e114df2cad29c43d	{}	[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}]	\N
13	http_endpoint_provider_with_property_types	30978e9fd0d29e52fe0369262e11fbcea1283889	a4e1d6d3-08cd-4cba-8023-72e8e0216727	ade0c4b3d77fbcd5872cb80187b6ad4b07cb609e	[]	1	null	30978e9fd0d29e52fe0369262e11fbcea1283889	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"Has a type password and no default value","type":"password"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
14	http_proxy_with_requires	4592ccbff484de43750068a1b7eab120bcf80b50	f45e1ed6-3d74-411c-8712-ab626a3b8cfc	864a2b1edef2029dc7e145c5749979c97fb8a9e5	[]	1	null	4592ccbff484de43750068a1b7eab120bcf80b50	{"http_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"http_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null}}	[{"name":"proxied_http_endpoint","type":"http_endpoint"},{"name":"logs_http_endpoint","type":"http_endpoint2","optional":true}]	\N
15	http_server_with_provides	64244f12f2db2e7d93ccfbc13be744df87013389	91db1acf-cf99-42c3-8056-ac4bed7af736	6821c970a6012f045ea37441a80be8878834366d	[]	1	null	64244f12f2db2e7d93ccfbc13be744df87013389	{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}	\N	[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}]
16	kv_http_server	044ec02730e6d068ecf88a0d37fe48937687bdba	b2a15382-7c9c-4c0c-8961-6022d4248cb6	1c89195f154a7dfc257a1118642385bfdfb97793	[]	1	null	044ec02730e6d068ecf88a0d37fe48937687bdba	{"kv_http_server.listen_port":{"description":"Port to listen on","default":8080}}	[{"name":"kv_http_server","type":"kv_http_server"}]	[{"name":"kv_http_server","type":"kv_http_server"}]
17	mongo_db	6a6e241c0bd5c203397f0213bee9d3d28a4ff35f	9a856150-2ae2-4973-b950-2534d3430498	9231ac8f8aea8e395db5c3ea0e5ec6507932fc69	["pkg_1"]	1	null	6a6e241c0bd5c203397f0213bee9d3d28a4ff35f	{}	\N	[{"name":"read_only_db","type":"db"}]
18	node	c12835da15038bedad6c49d20a2dda00375a0dc0	d6a360a3-2927-4223-8f1e-7bbbb105944e	ec3ab1b0f1121d77c82e2bfedfc2ae55778f865d	[]	1	null	c12835da15038bedad6c49d20a2dda00375a0dc0	{}	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]	[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}]
19	provider	e1ff4ff9a6304e1222484570a400788c55154b1c	92632dc4-274a-4910-a4bb-c9d3519ba2e1	1de4688c986988bf6aa4838f3c77a57bf2563c94	[]	1	null	e1ff4ff9a6304e1222484570a400788c55154b1c	{"a":{"description":"description for a","default":"default_a"},"b":{"description":"description for b"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider","type":"provider","properties":["a","b","c"]}]
20	provider_fail	314c385e96711cb5d56dd909a086563dae61bc37	1613e130-c34b-43b5-98b0-75669c56d87e	5090bc96d1604ca69cdf283d96af9a2405a3f03a	[]	1	null	314c385e96711cb5d56dd909a086563dae61bc37	{"a":{"description":"description for a","default":"default_a"},"c":{"description":"description for c","default":"default_c"}}	\N	[{"name":"provider_fail","type":"provider","properties":["a","b","c"]}]
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('templates_id_seq', 20, true);


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
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


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
-- Name: ephemeral_blobs ephemeral_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ephemeral_blobs
    ADD CONSTRAINT ephemeral_blobs_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: instances instances_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_agent_id_key UNIQUE (agent_id);


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
    ADD CONSTRAINT instances_vm_cid_key UNIQUE (vm_cid);


--
-- Name: instances instances_vm_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_id_key UNIQUE (vm_id);


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
-- Name: local_dns_blobs local_dns_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_pkey PRIMARY KEY (id);


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
-- Name: stemcells stemcells_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stemcells
    ADD CONSTRAINT stemcells_name_version_key UNIQUE (name, version);


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
-- Name: vms vms_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vms
    ADD CONSTRAINT vms_agent_id_key UNIQUE (agent_id);


--
-- Name: vms vms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
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
-- Name: deployments deployments_runtime_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments
    ADD CONSTRAINT deployments_runtime_config_id_fkey FOREIGN KEY (runtime_config_id) REFERENCES runtime_configs(id);


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
-- Name: instances instances_vm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instances
    ADD CONSTRAINT instances_vm_id_fkey FOREIGN KEY (vm_id) REFERENCES vms(id);


--
-- Name: ip_addresses ip_addresses_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id);


--
-- Name: local_dns_records local_dns_records_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_records
    ADD CONSTRAINT local_dns_records_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES instances(id) ON DELETE CASCADE;


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
-- Name: public; Type: ACL; Schema: -; Owner: pivotal
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pivotal;
GRANT ALL ON SCHEMA public TO pivotal;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

