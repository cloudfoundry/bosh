--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
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


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: agent_dns_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.agent_dns_versions (
    id bigint NOT NULL,
    agent_id text NOT NULL,
    dns_version bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public.agent_dns_versions OWNER TO postgres;

--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.agent_dns_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agent_dns_versions_id_seq OWNER TO postgres;

--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.agent_dns_versions_id_seq OWNED BY public.agent_dns_versions.id;


--
-- Name: blobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.blobs (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    type text
);


ALTER TABLE public.blobs OWNER TO postgres;

--
-- Name: cloud_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.cloud_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE public.cloud_configs OWNER TO postgres;

--
-- Name: cloud_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cloud_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cloud_configs_id_seq OWNER TO postgres;

--
-- Name: cloud_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cloud_configs_id_seq OWNED BY public.cloud_configs.id;


--
-- Name: compiled_packages; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.compiled_packages (
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


ALTER TABLE public.compiled_packages OWNER TO postgres;

--
-- Name: compiled_packages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.compiled_packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.compiled_packages_id_seq OWNER TO postgres;

--
-- Name: compiled_packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.compiled_packages_id_seq OWNED BY public.compiled_packages.id;


--
-- Name: configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.configs (
    id integer NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deleted boolean DEFAULT false,
    team_id integer
);


ALTER TABLE public.configs OWNER TO postgres;

--
-- Name: configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.configs_id_seq OWNER TO postgres;

--
-- Name: configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configs_id_seq OWNED BY public.configs.id;


--
-- Name: cpi_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.cpi_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE public.cpi_configs OWNER TO postgres;

--
-- Name: cpi_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cpi_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cpi_configs_id_seq OWNER TO postgres;

--
-- Name: cpi_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cpi_configs_id_seq OWNED BY public.cpi_configs.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.delayed_jobs (
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


ALTER TABLE public.delayed_jobs OWNER TO postgres;

--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delayed_jobs_id_seq OWNER TO postgres;

--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


--
-- Name: deployment_problems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployment_problems (
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


ALTER TABLE public.deployment_problems OWNER TO postgres;

--
-- Name: deployment_problems_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deployment_problems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deployment_problems_id_seq OWNER TO postgres;

--
-- Name: deployment_problems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deployment_problems_id_seq OWNED BY public.deployment_problems.id;


--
-- Name: deployment_properties; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployment_properties (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    name text NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.deployment_properties OWNER TO postgres;

--
-- Name: deployment_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deployment_properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deployment_properties_id_seq OWNER TO postgres;

--
-- Name: deployment_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deployment_properties_id_seq OWNED BY public.deployment_properties.id;


--
-- Name: deployments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployments (
    id integer NOT NULL,
    name text NOT NULL,
    manifest text,
    link_spec_json text
);


ALTER TABLE public.deployments OWNER TO postgres;

--
-- Name: deployments_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployments_configs (
    deployment_id integer NOT NULL,
    config_id integer NOT NULL
);


ALTER TABLE public.deployments_configs OWNER TO postgres;

--
-- Name: deployments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deployments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deployments_id_seq OWNER TO postgres;

--
-- Name: deployments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deployments_id_seq OWNED BY public.deployments.id;


--
-- Name: deployments_release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployments_release_versions (
    id integer NOT NULL,
    release_version_id integer NOT NULL,
    deployment_id integer NOT NULL
);


ALTER TABLE public.deployments_release_versions OWNER TO postgres;

--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deployments_release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deployments_release_versions_id_seq OWNER TO postgres;

--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deployments_release_versions_id_seq OWNED BY public.deployments_release_versions.id;


--
-- Name: deployments_stemcells; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployments_stemcells (
    id integer NOT NULL,
    deployment_id integer NOT NULL,
    stemcell_id integer NOT NULL
);


ALTER TABLE public.deployments_stemcells OWNER TO postgres;

--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deployments_stemcells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deployments_stemcells_id_seq OWNER TO postgres;

--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deployments_stemcells_id_seq OWNED BY public.deployments_stemcells.id;


--
-- Name: deployments_teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.deployments_teams (
    deployment_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE public.deployments_teams OWNER TO postgres;

--
-- Name: director_attributes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.director_attributes (
    value text,
    name text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.director_attributes OWNER TO postgres;

--
-- Name: director_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.director_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.director_attributes_id_seq OWNER TO postgres;

--
-- Name: director_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.director_attributes_id_seq OWNED BY public.director_attributes.id;


--
-- Name: dns_schema; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.dns_schema (
    filename text NOT NULL
);


ALTER TABLE public.dns_schema OWNER TO postgres;

--
-- Name: domains; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.domains (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    master character varying(128) DEFAULT NULL::character varying,
    last_check integer,
    type character varying(6) NOT NULL,
    notified_serial integer,
    account character varying(40) DEFAULT NULL::character varying
);


ALTER TABLE public.domains OWNER TO postgres;

--
-- Name: domains_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.domains_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.domains_id_seq OWNER TO postgres;

--
-- Name: domains_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.domains_id_seq OWNED BY public.domains.id;


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ephemeral_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ephemeral_blobs_id_seq OWNER TO postgres;

--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ephemeral_blobs_id_seq OWNED BY public.blobs.id;


--
-- Name: errand_runs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.errand_runs (
    id integer NOT NULL,
    deployment_id integer DEFAULT (-1) NOT NULL,
    errand_name text,
    successful_state_hash character varying(512)
);


ALTER TABLE public.errand_runs OWNER TO postgres;

--
-- Name: errand_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.errand_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.errand_runs_id_seq OWNER TO postgres;

--
-- Name: errand_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.errand_runs_id_seq OWNED BY public.errand_runs.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.events (
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


ALTER TABLE public.events OWNER TO postgres;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_id_seq OWNER TO postgres;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: instances; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.instances (
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
    trusted_certs_sha1_bak text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    update_completed boolean DEFAULT false,
    ignore boolean DEFAULT false,
    variable_set_id bigint NOT NULL
);


ALTER TABLE public.instances OWNER TO postgres;

--
-- Name: instances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instances_id_seq OWNER TO postgres;

--
-- Name: instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.instances_id_seq OWNED BY public.instances.id;


--
-- Name: instances_templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.instances_templates (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    template_id integer NOT NULL
);


ALTER TABLE public.instances_templates OWNER TO postgres;

--
-- Name: instances_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.instances_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instances_templates_id_seq OWNER TO postgres;

--
-- Name: instances_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.instances_templates_id_seq OWNED BY public.instances_templates.id;


--
-- Name: ip_addresses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.ip_addresses (
    id integer NOT NULL,
    network_name text,
    static boolean,
    instance_id integer,
    created_at timestamp without time zone,
    task_id text,
    address_str text NOT NULL
);


ALTER TABLE public.ip_addresses OWNER TO postgres;

--
-- Name: ip_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ip_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ip_addresses_id_seq OWNER TO postgres;

--
-- Name: ip_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ip_addresses_id_seq OWNED BY public.ip_addresses.id;


--
-- Name: local_dns_blobs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.local_dns_blobs (
    id bigint NOT NULL,
    blob_id integer NOT NULL,
    version bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE public.local_dns_blobs OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_dns_blobs_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.local_dns_blobs_id_seq1 OWNER TO postgres;

--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_dns_blobs_id_seq1 OWNED BY public.local_dns_blobs.id;


--
-- Name: local_dns_encoded_azs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.local_dns_encoded_azs (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.local_dns_encoded_azs OWNER TO postgres;

--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_dns_encoded_azs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.local_dns_encoded_azs_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_dns_encoded_azs_id_seq OWNED BY public.local_dns_encoded_azs.id;


--
-- Name: local_dns_encoded_instance_groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.local_dns_encoded_instance_groups (
    id integer NOT NULL,
    name text NOT NULL,
    deployment_id integer NOT NULL
);


ALTER TABLE public.local_dns_encoded_instance_groups OWNER TO postgres;

--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_dns_encoded_instance_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.local_dns_encoded_instance_groups_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_dns_encoded_instance_groups_id_seq OWNED BY public.local_dns_encoded_instance_groups.id;


--
-- Name: local_dns_encoded_networks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.local_dns_encoded_networks (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.local_dns_encoded_networks OWNER TO postgres;

--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_dns_encoded_networks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.local_dns_encoded_networks_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_dns_encoded_networks_id_seq OWNED BY public.local_dns_encoded_networks.id;


--
-- Name: local_dns_records; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.local_dns_records (
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


ALTER TABLE public.local_dns_records OWNER TO postgres;

--
-- Name: local_dns_records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_dns_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.local_dns_records_id_seq OWNER TO postgres;

--
-- Name: local_dns_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_dns_records_id_seq OWNED BY public.local_dns_records.id;


--
-- Name: locks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.locks (
    id integer NOT NULL,
    expired_at timestamp without time zone NOT NULL,
    name text NOT NULL,
    uid text NOT NULL,
    task_id text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.locks OWNER TO postgres;

--
-- Name: locks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.locks_id_seq OWNER TO postgres;

--
-- Name: locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.locks_id_seq OWNED BY public.locks.id;


--
-- Name: log_bundles; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.log_bundles (
    id integer NOT NULL,
    blobstore_id text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
);


ALTER TABLE public.log_bundles OWNER TO postgres;

--
-- Name: log_bundles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.log_bundles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_bundles_id_seq OWNER TO postgres;

--
-- Name: log_bundles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.log_bundles_id_seq OWNED BY public.log_bundles.id;


--
-- Name: orphan_disks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.orphan_disks (
    id integer NOT NULL,
    disk_cid text NOT NULL,
    size integer,
    availability_zone text,
    deployment_name text NOT NULL,
    instance_name text NOT NULL,
    cloud_properties_json text,
    created_at timestamp without time zone NOT NULL,
    cpi text DEFAULT ''::text
);


ALTER TABLE public.orphan_disks OWNER TO postgres;

--
-- Name: orphan_disks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orphan_disks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orphan_disks_id_seq OWNER TO postgres;

--
-- Name: orphan_disks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orphan_disks_id_seq OWNED BY public.orphan_disks.id;


--
-- Name: orphan_snapshots; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.orphan_snapshots (
    id integer NOT NULL,
    orphan_disk_id integer NOT NULL,
    snapshot_cid text NOT NULL,
    clean boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    snapshot_created_at timestamp without time zone
);


ALTER TABLE public.orphan_snapshots OWNER TO postgres;

--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orphan_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orphan_snapshots_id_seq OWNER TO postgres;

--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orphan_snapshots_id_seq OWNED BY public.orphan_snapshots.id;


--
-- Name: packages; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.packages (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    blobstore_id text,
    sha1 text,
    dependency_set_json text NOT NULL,
    release_id integer NOT NULL,
    fingerprint text
);


ALTER TABLE public.packages OWNER TO postgres;

--
-- Name: packages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.packages_id_seq OWNER TO postgres;

--
-- Name: packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.packages_id_seq OWNED BY public.packages.id;


--
-- Name: packages_release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.packages_release_versions (
    id integer NOT NULL,
    package_id integer NOT NULL,
    release_version_id integer NOT NULL
);


ALTER TABLE public.packages_release_versions OWNER TO postgres;

--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.packages_release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.packages_release_versions_id_seq OWNER TO postgres;

--
-- Name: packages_release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.packages_release_versions_id_seq OWNED BY public.packages_release_versions.id;


--
-- Name: persistent_disks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.persistent_disks (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    disk_cid text NOT NULL,
    size integer,
    active boolean DEFAULT false,
    cloud_properties_json text,
    name text DEFAULT ''::text,
    cpi text DEFAULT ''::text
);


ALTER TABLE public.persistent_disks OWNER TO postgres;

--
-- Name: persistent_disks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.persistent_disks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.persistent_disks_id_seq OWNER TO postgres;

--
-- Name: persistent_disks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.persistent_disks_id_seq OWNED BY public.persistent_disks.id;


--
-- Name: records; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.records (
    id integer NOT NULL,
    name character varying(255) DEFAULT NULL::character varying,
    type character varying(10) DEFAULT NULL::character varying,
    content character varying(4098) DEFAULT NULL::character varying,
    ttl integer,
    prio integer,
    change_date integer,
    domain_id integer
);


ALTER TABLE public.records OWNER TO postgres;

--
-- Name: records_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.records_id_seq OWNER TO postgres;

--
-- Name: records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.records_id_seq OWNED BY public.records.id;


--
-- Name: release_versions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.release_versions (
    id integer NOT NULL,
    version text NOT NULL,
    release_id integer NOT NULL,
    commit_hash text DEFAULT 'unknown'::text,
    uncommitted_changes boolean DEFAULT false
);


ALTER TABLE public.release_versions OWNER TO postgres;

--
-- Name: release_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.release_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.release_versions_id_seq OWNER TO postgres;

--
-- Name: release_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.release_versions_id_seq OWNED BY public.release_versions.id;


--
-- Name: release_versions_templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.release_versions_templates (
    id integer NOT NULL,
    release_version_id integer NOT NULL,
    template_id integer NOT NULL
);


ALTER TABLE public.release_versions_templates OWNER TO postgres;

--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.release_versions_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.release_versions_templates_id_seq OWNER TO postgres;

--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.release_versions_templates_id_seq OWNED BY public.release_versions_templates.id;


--
-- Name: releases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.releases (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.releases OWNER TO postgres;

--
-- Name: releases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.releases_id_seq OWNER TO postgres;

--
-- Name: releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.releases_id_seq OWNED BY public.releases.id;


--
-- Name: rendered_templates_archives; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.rendered_templates_archives (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    blobstore_id text NOT NULL,
    sha1 text NOT NULL,
    content_sha1 text NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE public.rendered_templates_archives OWNER TO postgres;

--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rendered_templates_archives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rendered_templates_archives_id_seq OWNER TO postgres;

--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rendered_templates_archives_id_seq OWNED BY public.rendered_templates_archives.id;


--
-- Name: runtime_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.runtime_configs (
    id integer NOT NULL,
    properties text,
    created_at timestamp without time zone NOT NULL,
    name text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.runtime_configs OWNER TO postgres;

--
-- Name: runtime_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.runtime_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.runtime_configs_id_seq OWNER TO postgres;

--
-- Name: runtime_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.runtime_configs_id_seq OWNED BY public.runtime_configs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.schema_migrations (
    filename text NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO postgres;

--
-- Name: snapshots; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.snapshots (
    id integer NOT NULL,
    persistent_disk_id integer NOT NULL,
    clean boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    snapshot_cid text NOT NULL
);


ALTER TABLE public.snapshots OWNER TO postgres;

--
-- Name: snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.snapshots_id_seq OWNER TO postgres;

--
-- Name: snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.snapshots_id_seq OWNED BY public.snapshots.id;


--
-- Name: stemcell_uploads; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.stemcell_uploads (
    id integer NOT NULL,
    name text,
    version text,
    cpi text
);


ALTER TABLE public.stemcell_uploads OWNER TO postgres;

--
-- Name: stemcell_matches_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stemcell_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stemcell_matches_id_seq OWNER TO postgres;

--
-- Name: stemcell_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stemcell_matches_id_seq OWNED BY public.stemcell_uploads.id;


--
-- Name: stemcells; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.stemcells (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    cid text NOT NULL,
    sha1 text,
    operating_system text,
    cpi text DEFAULT ''::text
);


ALTER TABLE public.stemcells OWNER TO postgres;

--
-- Name: stemcells_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stemcells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stemcells_id_seq OWNER TO postgres;

--
-- Name: stemcells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stemcells_id_seq OWNED BY public.stemcells.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.tasks (
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


ALTER TABLE public.tasks OWNER TO postgres;

--
-- Name: tasks_new_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tasks_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tasks_new_id_seq OWNER TO postgres;

--
-- Name: tasks_new_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tasks_new_id_seq OWNED BY public.tasks.id;


--
-- Name: tasks_teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.tasks_teams (
    task_id integer NOT NULL,
    team_id integer NOT NULL
);


ALTER TABLE public.tasks_teams OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.teams (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.teams OWNER TO postgres;

--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.teams_id_seq OWNER TO postgres;

--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.templates (
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
    provides_json text,
    templates_json text,
    spec_json text
);


ALTER TABLE public.templates OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.templates_id_seq OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_id_seq OWNED BY public.templates.id;


--
-- Name: variable_sets; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.variable_sets (
    id bigint NOT NULL,
    deployment_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deployed_successfully boolean DEFAULT false,
    writable boolean DEFAULT false
);


ALTER TABLE public.variable_sets OWNER TO postgres;

--
-- Name: variable_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variable_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variable_sets_id_seq OWNER TO postgres;

--
-- Name: variable_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variable_sets_id_seq OWNED BY public.variable_sets.id;


--
-- Name: variables; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.variables (
    id bigint NOT NULL,
    variable_id text NOT NULL,
    variable_name text NOT NULL,
    variable_set_id bigint NOT NULL,
    is_local boolean DEFAULT true,
    provider_deployment text DEFAULT ''::text
);


ALTER TABLE public.variables OWNER TO postgres;

--
-- Name: variables_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_id_seq OWNER TO postgres;

--
-- Name: variables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variables_id_seq OWNED BY public.variables.id;


--
-- Name: vms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE public.vms (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    agent_id text,
    cid text,
    trusted_certs_sha1 text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    active boolean DEFAULT false,
    cpi text DEFAULT ''::text,
    created_at timestamp without time zone
);


ALTER TABLE public.vms OWNER TO postgres;

--
-- Name: vms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vms_id_seq OWNER TO postgres;

--
-- Name: vms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vms_id_seq OWNED BY public.vms.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.agent_dns_versions ALTER COLUMN id SET DEFAULT nextval('public.agent_dns_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blobs ALTER COLUMN id SET DEFAULT nextval('public.ephemeral_blobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cloud_configs ALTER COLUMN id SET DEFAULT nextval('public.cloud_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compiled_packages ALTER COLUMN id SET DEFAULT nextval('public.compiled_packages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configs ALTER COLUMN id SET DEFAULT nextval('public.configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cpi_configs ALTER COLUMN id SET DEFAULT nextval('public.cpi_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployment_problems ALTER COLUMN id SET DEFAULT nextval('public.deployment_problems_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployment_properties ALTER COLUMN id SET DEFAULT nextval('public.deployment_properties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments ALTER COLUMN id SET DEFAULT nextval('public.deployments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_release_versions ALTER COLUMN id SET DEFAULT nextval('public.deployments_release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_stemcells ALTER COLUMN id SET DEFAULT nextval('public.deployments_stemcells_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.director_attributes ALTER COLUMN id SET DEFAULT nextval('public.director_attributes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domains ALTER COLUMN id SET DEFAULT nextval('public.domains_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.errand_runs ALTER COLUMN id SET DEFAULT nextval('public.errand_runs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances ALTER COLUMN id SET DEFAULT nextval('public.instances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances_templates ALTER COLUMN id SET DEFAULT nextval('public.instances_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_addresses ALTER COLUMN id SET DEFAULT nextval('public.ip_addresses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_blobs ALTER COLUMN id SET DEFAULT nextval('public.local_dns_blobs_id_seq1'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_encoded_azs ALTER COLUMN id SET DEFAULT nextval('public.local_dns_encoded_azs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_encoded_instance_groups ALTER COLUMN id SET DEFAULT nextval('public.local_dns_encoded_instance_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_encoded_networks ALTER COLUMN id SET DEFAULT nextval('public.local_dns_encoded_networks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_records ALTER COLUMN id SET DEFAULT nextval('public.local_dns_records_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locks ALTER COLUMN id SET DEFAULT nextval('public.locks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_bundles ALTER COLUMN id SET DEFAULT nextval('public.log_bundles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orphan_disks ALTER COLUMN id SET DEFAULT nextval('public.orphan_disks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orphan_snapshots ALTER COLUMN id SET DEFAULT nextval('public.orphan_snapshots_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packages ALTER COLUMN id SET DEFAULT nextval('public.packages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packages_release_versions ALTER COLUMN id SET DEFAULT nextval('public.packages_release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persistent_disks ALTER COLUMN id SET DEFAULT nextval('public.persistent_disks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.records ALTER COLUMN id SET DEFAULT nextval('public.records_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.release_versions ALTER COLUMN id SET DEFAULT nextval('public.release_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.release_versions_templates ALTER COLUMN id SET DEFAULT nextval('public.release_versions_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.releases ALTER COLUMN id SET DEFAULT nextval('public.releases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rendered_templates_archives ALTER COLUMN id SET DEFAULT nextval('public.rendered_templates_archives_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.runtime_configs ALTER COLUMN id SET DEFAULT nextval('public.runtime_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snapshots ALTER COLUMN id SET DEFAULT nextval('public.snapshots_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stemcell_uploads ALTER COLUMN id SET DEFAULT nextval('public.stemcell_matches_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stemcells ALTER COLUMN id SET DEFAULT nextval('public.stemcells_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_new_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates ALTER COLUMN id SET DEFAULT nextval('public.templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_sets ALTER COLUMN id SET DEFAULT nextval('public.variable_sets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables ALTER COLUMN id SET DEFAULT nextval('public.variables_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vms ALTER COLUMN id SET DEFAULT nextval('public.vms_id_seq'::regclass);


--
-- Data for Name: agent_dns_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.agent_dns_versions (id, agent_id, dns_version) FROM stdin;
\.


--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.agent_dns_versions_id_seq', 1, false);


--
-- Data for Name: blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blobs (id, blobstore_id, sha1, created_at, type) FROM stdin;
\.


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cloud_configs (id, properties, created_at) FROM stdin;
\.


--
-- Name: cloud_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cloud_configs_id_seq', 1, false);


--
-- Data for Name: compiled_packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.compiled_packages (id, blobstore_id, sha1, dependency_key, build, package_id, dependency_key_sha1, stemcell_os, stemcell_version) FROM stdin;
1	a6b90a2a-1556-4cf3-4ac8-c3df40992a69	5c4f1cfeb7691cc08b7df517ad5573bb1de07afc	[]	1	8	97d170e1550eee4afc0af065b78cda302a97674c	toronto-os	1
2	13ae5950-dcf0-404d-5eb5-cc7fb69ef0e2	52229b05a35d741bf1c1f7ee40a964df52a8de1b	[["foo","0ee95716c58cf7aab3ef7301ff907118552c2dda"]]	1	3	2ab05f5881c448e1fdf9f2438f31a41d654c27e6	toronto-os	1
\.


--
-- Name: compiled_packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.compiled_packages_id_seq', 2, true);


--
-- Data for Name: configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.configs (id, name, type, content, created_at, deleted, team_id) FROM stdin;
1	default	cloud	azs:\n- cloud_properties: {}\n  name: zone-1\n- cloud_properties: {}\n  name: zone-2\n- cloud_properties: {}\n  name: zone-3\ncompilation:\n  az: zone-1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: zone-1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n  - az: zone-2\n    cloud_properties: {}\n    dns:\n    - 192.168.2.1\n    - 192.168.2.2\n    gateway: 192.168.2.1\n    range: 192.168.2.0/24\n    reserved: []\n    static:\n    - 192.168.2.10\n  - az: zone-3\n    cloud_properties: {}\n    dns:\n    - 192.168.3.1\n    - 192.168.3.2\n    gateway: 192.168.3.1\n    range: 192.168.3.0/24\n    reserved: []\n    static:\n    - 192.168.3.10\nvm_types:\n- cloud_properties: {}\n  name: a\n	2018-04-10 23:11:14.161138	f	\N
\.


--
-- Name: configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configs_id_seq', 1, true);


--
-- Data for Name: cpi_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cpi_configs (id, properties, created_at) FROM stdin;
\.


--
-- Name: cpi_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cpi_configs_id_seq', 1, false);


--
-- Data for Name: delayed_jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.delayed_jobs (id, priority, attempts, handler, last_error, run_at, locked_at, failed_at, locked_by, queue) FROM stdin;
\.


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.delayed_jobs_id_seq', 3, true);


--
-- Data for Name: deployment_problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployment_problems (id, deployment_id, state, resource_id, type, data_json, created_at, last_seen_at, counter) FROM stdin;
\.


--
-- Name: deployment_problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deployment_problems_id_seq', 1, false);


--
-- Data for Name: deployment_properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployment_properties (id, deployment_id, name, value) FROM stdin;
\.


--
-- Name: deployment_properties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deployment_properties_id_seq', 1, false);


--
-- Data for Name: deployments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployments (id, name, manifest, link_spec_json) FROM stdin;
1	simple	---\ndirector_uuid: deadbeef\njobs:\n- azs:\n  - zone-1\n  - zone-2\n  - zone-3\n  instances: 3\n  name: foobar\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  templates:\n  - name: foobar\n  vm_type: a\nname: simple\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
\.


--
-- Data for Name: deployments_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployments_configs (deployment_id, config_id) FROM stdin;
1	1
\.


--
-- Name: deployments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deployments_id_seq', 1, true);


--
-- Data for Name: deployments_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployments_release_versions (id, release_version_id, deployment_id) FROM stdin;
1	1	1
\.


--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deployments_release_versions_id_seq', 1, true);


--
-- Data for Name: deployments_stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployments_stemcells (id, deployment_id, stemcell_id) FROM stdin;
1	1	1
\.


--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deployments_stemcells_id_seq', 1, true);


--
-- Data for Name: deployments_teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deployments_teams (deployment_id, team_id) FROM stdin;
\.


--
-- Data for Name: director_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.director_attributes (value, name, id) FROM stdin;
\.


--
-- Name: director_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.director_attributes_id_seq', 1, false);


--
-- Data for Name: dns_schema; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dns_schema (filename) FROM stdin;
20120123234908_initial.rb
\.


--
-- Data for Name: domains; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.domains (id, name, master, last_check, type, notified_serial, account) FROM stdin;
1	bosh	\N	\N	NATIVE	\N	\N
2	1.168.192.in-addr.arpa	\N	\N	NATIVE	\N	\N
3	2.168.192.in-addr.arpa	\N	\N	NATIVE	\N	\N
4	3.168.192.in-addr.arpa	\N	\N	NATIVE	\N	\N
\.


--
-- Name: domains_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.domains_id_seq', 4, true);


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ephemeral_blobs_id_seq', 1, false);


--
-- Data for Name: errand_runs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.errand_runs (id, deployment_id, errand_name, successful_state_hash) FROM stdin;
\.


--
-- Name: errand_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.errand_runs_id_seq', 1, false);


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (id, parent_id, "user", "timestamp", action, object_type, object_name, error, task, deployment, instance, context_json) FROM stdin;
1	\N	_director	2018-04-10 23:11:09.584444	start	director	deadbeef	\N	\N	\N	\N	{"version":"0.0.0"}
2	\N	_director	2018-04-10 23:11:09.605266	start	worker	worker_1	\N	\N	\N	\N	{}
3	\N	_director	2018-04-10 23:11:09.608282	start	worker	worker_0	\N	\N	\N	\N	{}
4	\N	_director	2018-04-10 23:11:09.638806	start	worker	worker_2	\N	\N	\N	\N	{}
5	\N	test	2018-04-10 23:11:10.709579	acquire	lock	lock:release:bosh-release	\N	1	\N	\N	{}
6	\N	test	2018-04-10 23:11:12.492138	release	lock	lock:release:bosh-release	\N	1	\N	\N	{}
7	\N	test	2018-04-10 23:11:14.162376	update	cloud-config	default	\N	\N	\N	\N	{}
8	\N	test	2018-04-10 23:11:14.701787	create	deployment	simple	\N	3	simple	\N	{}
9	\N	test	2018-04-10 23:11:14.710114	acquire	lock	lock:deployment:simple	\N	3	simple	\N	{}
10	\N	test	2018-04-10 23:11:14.783964	acquire	lock	lock:release:bosh-release	\N	3	\N	\N	{}
11	\N	test	2018-04-10 23:11:14.793508	release	lock	lock:release:bosh-release	\N	3	\N	\N	{}
12	\N	test	2018-04-10 23:11:14.956428	acquire	lock	lock:compile:8:toronto-os/1	\N	3	simple	\N	{}
13	\N	test	2018-04-10 23:11:14.969187	create	instance	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
14	\N	test	2018-04-10 23:11:14.996856	create	vm	\N	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
15	14	test	2018-04-10 23:11:15.260062	create	vm	45838	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
16	13	test	2018-04-10 23:11:16.463542	create	instance	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
17	\N	test	2018-04-10 23:11:17.628573	delete	instance	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
18	\N	test	2018-04-10 23:11:17.635098	delete	vm	45838	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
19	18	test	2018-04-10 23:11:17.802819	delete	vm	45838	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
20	17	test	2018-04-10 23:11:17.818511	delete	instance	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	\N	3	simple	compilation-7343e5c2-dc23-4f87-9599-ff468c145949/b2fb0f80-dfa4-4c3e-bfc4-1b1bf3050440	{}
21	\N	test	2018-04-10 23:11:17.835038	release	lock	lock:compile:8:toronto-os/1	\N	3	simple	\N	{}
22	\N	test	2018-04-10 23:11:17.87549	acquire	lock	lock:compile:3:toronto-os/1	\N	3	simple	\N	{}
23	\N	test	2018-04-10 23:11:17.88765	create	instance	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
24	\N	test	2018-04-10 23:11:17.91361	create	vm	\N	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
25	24	test	2018-04-10 23:11:18.389605	create	vm	45856	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
26	23	test	2018-04-10 23:11:19.589982	create	instance	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
27	\N	test	2018-04-10 23:11:20.755632	delete	instance	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
28	\N	test	2018-04-10 23:11:20.762674	delete	vm	45856	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
29	28	test	2018-04-10 23:11:20.927238	delete	vm	45856	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
30	27	test	2018-04-10 23:11:20.941167	delete	instance	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	\N	3	simple	compilation-6ec5157d-3e43-4d1b-9387-b6905bba95b6/be812536-3e25-4bee-a3af-808c5ca307c3	{}
31	\N	test	2018-04-10 23:11:20.957868	release	lock	lock:compile:3:toronto-os/1	\N	3	simple	\N	{}
32	\N	test	2018-04-10 23:11:21.083267	create	vm	\N	\N	3	simple	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	{}
33	\N	test	2018-04-10 23:11:21.08911	create	vm	\N	\N	3	simple	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	{}
34	\N	test	2018-04-10 23:11:21.088765	create	vm	\N	\N	3	simple	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	{}
35	32	test	2018-04-10 23:11:21.35717	create	vm	45876	\N	3	simple	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	{}
36	34	test	2018-04-10 23:11:21.532844	create	vm	45886	\N	3	simple	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	{}
37	33	test	2018-04-10 23:11:21.653237	create	vm	45890	\N	3	simple	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	{}
38	\N	test	2018-04-10 23:11:22.944072	create	instance	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	\N	3	simple	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	{"az":"zone-1"}
39	38	test	2018-04-10 23:11:29.103608	create	instance	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	\N	3	simple	foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a	{}
40	\N	test	2018-04-10 23:11:29.110281	create	instance	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	\N	3	simple	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	{"az":"zone-2"}
41	40	test	2018-04-10 23:11:31.278921	create	instance	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	\N	3	simple	foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee	{}
42	\N	test	2018-04-10 23:11:31.285302	create	instance	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	\N	3	simple	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	{"az":"zone-3"}
43	42	test	2018-04-10 23:11:33.45829	create	instance	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	\N	3	simple	foobar/9825ed61-24f9-4780-a823-a761a0f9f182	{}
44	8	test	2018-04-10 23:11:33.475616	create	deployment	simple	\N	3	simple	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
45	\N	test	2018-04-10 23:11:33.479947	release	lock	lock:deployment:simple	\N	3	simple	\N	{}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_id_seq', 45, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instances (id, job, index, deployment_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid_bak, agent_id_bak, trusted_certs_sha1_bak, update_completed, ignore, variable_set_id) FROM stdin;
2	foobar	1	1	started	f	7d834cdf-3ac2-4c14-bd39-e44a615f9bee	zone-2	{}	f	f	["1.foobar.a.simple.bosh","7d834cdf-3ac2-4c14-bd39-e44a615f9bee.foobar.a.simple.bosh"]	{"deployment":"simple","job":{"name":"foobar","templates":[{"name":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]}],"template":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]},"index":1,"bootstrap":false,"lifecycle":"service","name":"foobar","id":"7d834cdf-3ac2-4c14-bd39-e44a615f9bee","az":"zone-2","networks":{"a":{"type":"manual","ip":"192.168.2.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.2.1","192.168.2.2"],"gateway":"192.168.2.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"foo":{"name":"foo","version":"0ee95716c58cf7aab3ef7301ff907118552c2dda.1","sha1":"5c4f1cfeb7691cc08b7df517ad5573bb1de07afc","blobstore_id":"a6b90a2a-1556-4cf3-4ac8-c3df40992a69"},"bar":{"name":"bar","version":"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1","sha1":"52229b05a35d741bf1c1f7ee40a964df52a8de1b","blobstore_id":"13ae5950-dcf0-404d-5eb5-cc7fb69ef0e2"}},"properties":{"foobar":{"test_property":1,"drain_type":"static","dynamic_drain_wait1":-3,"dynamic_drain_wait2":-2,"network_name":null,"networks":null}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.2.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"foobar":"2338676ace4ac97c96b7175262aadd57c381a94d"},"rendered_templates_archive":{"blobstore_id":"879a866e-efc0-4e11-94cf-186549a6105f","sha1":"6c20cceb30384e758f80219e0cfe94331fa24255"},"configuration_hash":"b7faead3cbbefd126e4d00d07f10feffd701d0e4"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
1	foobar	0	1	started	f	6cba1794-cb07-4d7a-a90c-b289a61ed92a	zone-1	{}	f	t	["0.foobar.a.simple.bosh","6cba1794-cb07-4d7a-a90c-b289a61ed92a.foobar.a.simple.bosh"]	{"deployment":"simple","job":{"name":"foobar","templates":[{"name":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]}],"template":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"foobar","id":"6cba1794-cb07-4d7a-a90c-b289a61ed92a","az":"zone-1","networks":{"a":{"type":"manual","ip":"192.168.1.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"foo":{"name":"foo","version":"0ee95716c58cf7aab3ef7301ff907118552c2dda.1","sha1":"5c4f1cfeb7691cc08b7df517ad5573bb1de07afc","blobstore_id":"a6b90a2a-1556-4cf3-4ac8-c3df40992a69"},"bar":{"name":"bar","version":"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1","sha1":"52229b05a35d741bf1c1f7ee40a964df52a8de1b","blobstore_id":"13ae5950-dcf0-404d-5eb5-cc7fb69ef0e2"}},"properties":{"foobar":{"test_property":1,"drain_type":"static","dynamic_drain_wait1":-3,"dynamic_drain_wait2":-2,"network_name":null,"networks":null}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"foobar":"b7b7532f3ce29aa91e4061d48821a44e383c561c"},"rendered_templates_archive":{"blobstore_id":"6b870d5c-c121-4caa-be66-e8ad7da5cfbc","sha1":"4557660f830c5672f59b755be0aec4bbd28256f2"},"configuration_hash":"88364b4df2389acf12b447c3164396342604f256"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
3	foobar	2	1	started	f	9825ed61-24f9-4780-a823-a761a0f9f182	zone-3	{}	f	f	["2.foobar.a.simple.bosh","9825ed61-24f9-4780-a823-a761a0f9f182.foobar.a.simple.bosh"]	{"deployment":"simple","job":{"name":"foobar","templates":[{"name":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]}],"template":"foobar","version":"47eeeaec61f68baf6fc94108ac32aece496fa50e","sha1":"57bd8b832aecb467cd4817b5f692b90ece6a8df8","blobstore_id":"0fdba5da-0871-4398-a5b4-07798d959541","logs":[]},"index":2,"bootstrap":false,"lifecycle":"service","name":"foobar","id":"9825ed61-24f9-4780-a823-a761a0f9f182","az":"zone-3","networks":{"a":{"type":"manual","ip":"192.168.3.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.3.1","192.168.3.2"],"gateway":"192.168.3.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"foo":{"name":"foo","version":"0ee95716c58cf7aab3ef7301ff907118552c2dda.1","sha1":"5c4f1cfeb7691cc08b7df517ad5573bb1de07afc","blobstore_id":"a6b90a2a-1556-4cf3-4ac8-c3df40992a69"},"bar":{"name":"bar","version":"f1267e1d4e06b60c91ef648fb9242e33ddcffa73.1","sha1":"52229b05a35d741bf1c1f7ee40a964df52a8de1b","blobstore_id":"13ae5950-dcf0-404d-5eb5-cc7fb69ef0e2"}},"properties":{"foobar":{"test_property":1,"drain_type":"static","dynamic_drain_wait1":-3,"dynamic_drain_wait2":-2,"network_name":null,"networks":null}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.3.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"foobar":"b39256be29bf1af81bd3c6ca6336ad636b71f35e"},"rendered_templates_archive":{"blobstore_id":"23957078-28d5-4227-bc12-c46daf570b80","sha1":"ed7a0a980eadaa05a6180a8959f9944cf66a2912"},"configuration_hash":"e0812187e60615c4e47f1574f4637d3390cff324"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instances_id_seq', 5, true);


--
-- Data for Name: instances_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instances_templates (id, instance_id, template_id) FROM stdin;
1	1	5
2	2	5
3	3	5
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instances_templates_id_seq', 3, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ip_addresses (id, network_name, static, instance_id, created_at, task_id, address_str) FROM stdin;
1	a	f	1	2018-04-10 23:11:14.83433	3	3232235778
2	a	f	2	2018-04-10 23:11:14.839391	3	3232236034
3	a	f	3	2018-04-10 23:11:14.843747	3	3232236290
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ip_addresses_id_seq', 5, true);


--
-- Data for Name: local_dns_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_dns_blobs (id, blob_id, version, created_at) FROM stdin;
\.


--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_dns_blobs_id_seq1', 1, false);


--
-- Data for Name: local_dns_encoded_azs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_dns_encoded_azs (id, name) FROM stdin;
1	zone-1
2	zone-2
3	zone-3
\.


--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_dns_encoded_azs_id_seq', 3, true);


--
-- Data for Name: local_dns_encoded_instance_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_dns_encoded_instance_groups (id, name, deployment_id) FROM stdin;
1	foobar	1
\.


--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_dns_encoded_instance_groups_id_seq', 1, true);


--
-- Data for Name: local_dns_encoded_networks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_dns_encoded_networks (id, name) FROM stdin;
1	a
\.


--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_dns_encoded_networks_id_seq', 1, true);


--
-- Data for Name: local_dns_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_dns_records (id, ip, az, instance_group, network, deployment, instance_id, agent_id, domain) FROM stdin;
1	192.168.1.2	zone-1	foobar	a	simple	1	09bc16a8-79a9-49ab-84a7-38141c6c064a	bosh
2	192.168.2.2	zone-2	foobar	a	simple	2	4c6e18ef-653a-4bf1-9669-f404f96eff63	bosh
3	192.168.3.2	zone-3	foobar	a	simple	3	017676de-d4a8-4fdd-af66-ec29b5906a99	bosh
\.


--
-- Name: local_dns_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_dns_records_id_seq', 3, true);


--
-- Data for Name: locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locks (id, expired_at, name, uid, task_id) FROM stdin;
\.


--
-- Name: locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locks_id_seq', 5, true);


--
-- Data for Name: log_bundles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.log_bundles (id, blobstore_id, "timestamp") FROM stdin;
\.


--
-- Name: log_bundles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.log_bundles_id_seq', 1, false);


--
-- Data for Name: orphan_disks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orphan_disks (id, disk_cid, size, availability_zone, deployment_name, instance_name, cloud_properties_json, created_at, cpi) FROM stdin;
\.


--
-- Name: orphan_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orphan_disks_id_seq', 1, false);


--
-- Data for Name: orphan_snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orphan_snapshots (id, orphan_disk_id, snapshot_cid, clean, created_at, snapshot_created_at) FROM stdin;
\.


--
-- Name: orphan_snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orphan_snapshots_id_seq', 1, false);


--
-- Data for Name: packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.packages (id, name, version, blobstore_id, sha1, dependency_set_json, release_id, fingerprint) FROM stdin;
1	a	821fcd0a441062473a386e9297e9cb48b5f189f4	4432382f-5133-4230-b3b5-5791172859d9	f1150c33b9fe0ba0a02cb47c25e46f5fe8ee450e	["b"]	1	821fcd0a441062473a386e9297e9cb48b5f189f4
2	b	ec25004a81fc656a6c39871564f352d70268c637	9411e40e-5a28-4a35-a3a3-8b025234dc70	7171c79f9eed1f68661f27badd48b9c75f1e17f8	["c"]	1	ec25004a81fc656a6c39871564f352d70268c637
3	bar	f1267e1d4e06b60c91ef648fb9242e33ddcffa73	607eac1d-19e0-470d-a541-61542d9940b5	8d49c7d4aa1b45d622fa84686e4b13c32469c725	["foo"]	1	f1267e1d4e06b60c91ef648fb9242e33ddcffa73
4	blocking_package	2ae8315faf952e6f69da493286387803ccfad248	6d490a12-14ef-4e4a-91e8-0bf0025aca40	f4dbf8a10bba04812aa2acdb689d1f2070f535b9	[]	1	2ae8315faf952e6f69da493286387803ccfad248
5	c	5bc40b65cca962dcc486673c6999d3b085b4a9ab	1c338918-6d03-49d0-8ad8-72fd972bcdb4	6756db5c4cecbe0708c3292c496b27f202471bd8	[]	1	5bc40b65cca962dcc486673c6999d3b085b4a9ab
6	errand1	7976e3d21a6d6d00885c44b0192f6daa8afc0587	e4895439-ea61-4565-93d5-16a839317556	ae951418f43e560cfa5e6c0568f3de798b8b8a46	[]	1	7976e3d21a6d6d00885c44b0192f6daa8afc0587
7	fails_with_too_much_output	e505f41e8cec5608209392c06950bba5d995bdd8	1701c1d6-0d5b-4b16-954a-7dd8f2b258b1	2c50b6d78114aa50b86ef8bad8ac4df448ce82d5	[]	1	e505f41e8cec5608209392c06950bba5d995bdd8
8	foo	0ee95716c58cf7aab3ef7301ff907118552c2dda	79a0de3a-1d27-4d8c-b684-deeac60e58f6	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
9	foo_1	0ee95716c58cf7aab3ef7301ff907118552c2dda	afbc3bfa-29bc-4536-ae46-bfd6adefcb7a	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
10	foo_10	0ee95716c58cf7aab3ef7301ff907118552c2dda	45f6c95d-f5e0-4a8a-9ef0-e4028e53c4cd	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
11	foo_2	0ee95716c58cf7aab3ef7301ff907118552c2dda	812331ce-1759-482c-b460-85fe133c50ab	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
12	foo_3	0ee95716c58cf7aab3ef7301ff907118552c2dda	562fe22c-1b28-4290-bd18-1e5f5dc92c1f	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
13	foo_4	0ee95716c58cf7aab3ef7301ff907118552c2dda	3ac48299-9be4-4211-a42e-c407b8080ee5	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
14	foo_5	0ee95716c58cf7aab3ef7301ff907118552c2dda	141230c0-cfc6-4ff8-89d1-2c0e9e5faea8	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
15	foo_6	0ee95716c58cf7aab3ef7301ff907118552c2dda	3fd05ade-33f8-4ce3-b4d3-f0d9cda8fa2b	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
16	foo_7	0ee95716c58cf7aab3ef7301ff907118552c2dda	0d78d092-2071-4f6a-8e05-69fb18ac4316	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
17	foo_8	0ee95716c58cf7aab3ef7301ff907118552c2dda	84234673-a745-4b3a-8972-eaed8931152d	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
18	foo_9	0ee95716c58cf7aab3ef7301ff907118552c2dda	8e7d8227-2a09-49cd-9ab1-2dfc79555bd8	ef57a860a205c71e123fab33e5de8fc21087c43e	[]	1	0ee95716c58cf7aab3ef7301ff907118552c2dda
\.


--
-- Name: packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.packages_id_seq', 18, true);


--
-- Data for Name: packages_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.packages_release_versions (id, package_id, release_version_id) FROM stdin;
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

SELECT pg_catalog.setval('public.packages_release_versions_id_seq', 18, true);


--
-- Data for Name: persistent_disks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.persistent_disks (id, instance_id, disk_cid, size, active, cloud_properties_json, name, cpi) FROM stdin;
\.


--
-- Name: persistent_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.persistent_disks_id_seq', 1, false);


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.records (id, name, type, content, ttl, prio, change_date, domain_id) FROM stdin;
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1523401874	1
2	bosh	NS	ns.bosh	14400	\N	1523401874	1
3	ns.bosh	A	\N	18000	\N	1523401874	1
4	0.foobar.a.simple.bosh	A	192.168.1.2	300	\N	1523401884	1
5	1.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	2
6	1.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	2
7	2.1.168.192.in-addr.arpa	PTR	0.foobar.a.simple.bosh	300	\N	1523401884	2
8	6cba1794-cb07-4d7a-a90c-b289a61ed92a.foobar.a.simple.bosh	A	192.168.1.2	300	\N	1523401884	1
9	2.1.168.192.in-addr.arpa	PTR	6cba1794-cb07-4d7a-a90c-b289a61ed92a.foobar.a.simple.bosh	300	\N	1523401884	2
10	1.foobar.a.simple.bosh	A	192.168.2.2	300	\N	1523401890	1
11	2.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	3
12	2.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	3
13	2.2.168.192.in-addr.arpa	PTR	1.foobar.a.simple.bosh	300	\N	1523401890	3
14	7d834cdf-3ac2-4c14-bd39-e44a615f9bee.foobar.a.simple.bosh	A	192.168.2.2	300	\N	1523401890	1
15	2.2.168.192.in-addr.arpa	PTR	7d834cdf-3ac2-4c14-bd39-e44a615f9bee.foobar.a.simple.bosh	300	\N	1523401890	3
16	2.foobar.a.simple.bosh	A	192.168.3.2	300	\N	1523401892	1
17	3.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	4
18	3.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	4
19	2.3.168.192.in-addr.arpa	PTR	2.foobar.a.simple.bosh	300	\N	1523401892	4
20	9825ed61-24f9-4780-a823-a761a0f9f182.foobar.a.simple.bosh	A	192.168.3.2	300	\N	1523401892	1
21	2.3.168.192.in-addr.arpa	PTR	9825ed61-24f9-4780-a823-a761a0f9f182.foobar.a.simple.bosh	300	\N	1523401892	4
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.records_id_seq', 21, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	ebbcf5e	f
\.


--
-- Name: release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.release_versions_id_seq', 1, true);


--
-- Data for Name: release_versions_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.release_versions_templates (id, release_version_id, template_id) FROM stdin;
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
24	1	24
25	1	25
26	1	26
\.


--
-- Name: release_versions_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.release_versions_templates_id_seq', 26, true);


--
-- Data for Name: releases; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.releases (id, name) FROM stdin;
1	bosh-release
\.


--
-- Name: releases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.releases_id_seq', 1, true);


--
-- Data for Name: rendered_templates_archives; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rendered_templates_archives (id, instance_id, blobstore_id, sha1, content_sha1, created_at) FROM stdin;
1	1	6b870d5c-c121-4caa-be66-e8ad7da5cfbc	4557660f830c5672f59b755be0aec4bbd28256f2	88364b4df2389acf12b447c3164396342604f256	2018-04-10 23:11:22.956172
2	2	879a866e-efc0-4e11-94cf-186549a6105f	6c20cceb30384e758f80219e0cfe94331fa24255	b7faead3cbbefd126e4d00d07f10feffd701d0e4	2018-04-10 23:11:29.122285
3	3	23957078-28d5-4227-bc12-c46daf570b80	ed7a0a980eadaa05a6180a8959f9944cf66a2912	e0812187e60615c4e47f1574f4637d3390cff324	2018-04-10 23:11:31.296478
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rendered_templates_archives_id_seq', 3, true);


--
-- Data for Name: runtime_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.runtime_configs (id, properties, created_at, name) FROM stdin;
\.


--
-- Name: runtime_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.runtime_configs_id_seq', 1, false);


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schema_migrations (filename) FROM stdin;
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
20170606225018_add_cpi_to_cloud_records.rb
20170607182149_add_task_id_to_locks.rb
20170612013910_add_created_at_to_vms.rb
20170616173221_remove_users_table.rb
20170616185237_migrate_spec_json_links.rb
20170628221611_add_canonical_az_names_and_ids.rb
20170705204352_add_cpi_to_disks.rb
20170705211620_add_templates_json_to_templates.rb
20170803163303_register_known_az_names.rb
20170804191205_add_deployment_and_errand_name_to_errand_runs.rb
20170815175515_change_variable_ids_to_bigint.rb
20170821141953_remove_unused_credentials_json_columns.rb
20170825141953_change_address_to_be_string_for_ipv6.rb
20170828174622_add_spec_json_to_templates.rb
20170915205722_create_dns_encoded_networks_and_instance_groups.rb
20171010144941_add_configs.rb
20171010150659_migrate_runtime_configs.rb
20171010161532_migrate_cloud_configs.rb
20171011122118_migrate_cpi_configs.rb
20171018102040_remove_compilation_local_dns_records.rb
20171030224934_convert_nil_configs_to_empty.rb
20180119183014_add_stemcell_matches.rb
20180130182844_rename_stemcell_matches_to_stemcell_uploads.rb
20180130182845_add_team_id_to_configs.rb
\.


--
-- Data for Name: snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snapshots (id, persistent_disk_id, clean, created_at, snapshot_cid) FROM stdin;
\.


--
-- Name: snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snapshots_id_seq', 1, false);


--
-- Name: stemcell_matches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stemcell_matches_id_seq', 1, true);


--
-- Data for Name: stemcell_uploads; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stemcell_uploads (id, name, version, cpi) FROM stdin;
1	ubuntu-stemcell	1	
\.


--
-- Data for Name: stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stemcells (id, name, version, cid, sha1, operating_system, cpi) FROM stdin;
1	ubuntu-stemcell	1	4f2d9fac-9cb1-4efb-8afd-bacdc86ae228	shawone	toronto-os	
\.


--
-- Name: stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stemcells_id_seq', 1, true);


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks (id, state, "timestamp", description, result, output, checkpoint_time, type, username, deployment_name, started_at, event_output, result_output, context_id) FROM stdin;
2	done	2018-04-10 23:11:14.015583	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-45276/sandbox/boshdir/tasks/2	2018-04-10 23:11:13.621557	update_stemcell	test	\N	2018-04-10 23:11:13.621439	{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"started","progress":0}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"finished","progress":100}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"started","progress":0}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"finished","progress":100}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"started","progress":0}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"finished","progress":100}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"started","progress":0}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"finished","progress":100}\n{"time":1523401873,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (4f2d9fac-9cb1-4efb-8afd-bacdc86ae228)","index":5,"state":"started","progress":0}\n{"time":1523401874,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (4f2d9fac-9cb1-4efb-8afd-bacdc86ae228)","index":5,"state":"finished","progress":100}\n		
3	done	2018-04-10 23:11:33.48761	create deployment	/deployments/simple	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-45276/sandbox/boshdir/tasks/3	2018-04-10 23:11:14.686012	update_deployment	test	simple	2018-04-10 23:11:14.685909	{"time":1523401874,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1523401874,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1523401874,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1523401874,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1523401874,"stage":"Compiling packages","tags":[],"total":2,"task":"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":1,"state":"started","progress":0}\n{"time":1523401877,"stage":"Compiling packages","tags":[],"total":2,"task":"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":1,"state":"finished","progress":100}\n{"time":1523401877,"stage":"Compiling packages","tags":[],"total":2,"task":"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73","index":2,"state":"started","progress":0}\n{"time":1523401880,"stage":"Compiling packages","tags":[],"total":2,"task":"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73","index":2,"state":"finished","progress":100}\n{"time":1523401881,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a (0)","index":1,"state":"started","progress":0}\n{"time":1523401881,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee (1)","index":2,"state":"started","progress":0}\n{"time":1523401881,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/9825ed61-24f9-4780-a823-a761a0f9f182 (2)","index":3,"state":"started","progress":0}\n{"time":1523401882,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a (0)","index":1,"state":"finished","progress":100}\n{"time":1523401882,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee (1)","index":2,"state":"finished","progress":100}\n{"time":1523401882,"stage":"Creating missing vms","tags":[],"total":3,"task":"foobar/9825ed61-24f9-4780-a823-a761a0f9f182 (2)","index":3,"state":"finished","progress":100}\n{"time":1523401882,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1523401889,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/6cba1794-cb07-4d7a-a90c-b289a61ed92a (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1523401889,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee (1)","index":2,"state":"started","progress":0}\n{"time":1523401891,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/7d834cdf-3ac2-4c14-bd39-e44a615f9bee (1)","index":2,"state":"finished","progress":100}\n{"time":1523401891,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/9825ed61-24f9-4780-a823-a761a0f9f182 (2)","index":3,"state":"started","progress":0}\n{"time":1523401893,"stage":"Updating instance","tags":["foobar"],"total":3,"task":"foobar/9825ed61-24f9-4780-a823-a761a0f9f182 (2)","index":3,"state":"finished","progress":100}\n		
1	done	2018-04-10 23:11:12.514621	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/workspace/bosh/src/tmp/integration-tests-workspace/pid-45276/sandbox/boshdir/tasks/1	2018-04-10 23:11:10.655398	update_release	test	\N	2018-04-10 23:11:10.655276	{"time":1523401870,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"started","progress":0}\n{"time":1523401870,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"started","progress":0}\n{"time":1523401870,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"started","progress":0}\n{"time":1523401870,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"a/821fcd0a441062473a386e9297e9cb48b5f189f4","index":1,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"a/821fcd0a441062473a386e9297e9cb48b5f189f4","index":1,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"b/ec25004a81fc656a6c39871564f352d70268c637","index":2,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"b/ec25004a81fc656a6c39871564f352d70268c637","index":2,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73","index":3,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73","index":3,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"blocking_package/2ae8315faf952e6f69da493286387803ccfad248","index":4,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"blocking_package/2ae8315faf952e6f69da493286387803ccfad248","index":4,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"c/5bc40b65cca962dcc486673c6999d3b085b4a9ab","index":5,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"c/5bc40b65cca962dcc486673c6999d3b085b4a9ab","index":5,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"errand1/7976e3d21a6d6d00885c44b0192f6daa8afc0587","index":6,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"errand1/7976e3d21a6d6d00885c44b0192f6daa8afc0587","index":6,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"fails_with_too_much_output/e505f41e8cec5608209392c06950bba5d995bdd8","index":7,"state":"started","progress":0}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"fails_with_too_much_output/e505f41e8cec5608209392c06950bba5d995bdd8","index":7,"state":"finished","progress":100}\n{"time":1523401870,"stage":"Creating new packages","tags":[],"total":18,"task":"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":8,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":8,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_1/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":9,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_1/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":9,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_10/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":10,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_10/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":10,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_2/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":11,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_2/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":11,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_3/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":12,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_3/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":12,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_4/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":13,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_4/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":13,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_5/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":14,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_5/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":14,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_6/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":15,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_6/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":15,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_7/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":16,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_7/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":16,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_8/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":17,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_8/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":17,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_9/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":18,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new packages","tags":[],"total":18,"task":"foo_9/0ee95716c58cf7aab3ef7301ff907118552c2dda","index":18,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"emoji-errand/d4a4da3c16bd12760b3fcf7c39ef5e503a639c76","index":1,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"emoji-errand/d4a4da3c16bd12760b3fcf7c39ef5e503a639c76","index":1,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"errand1/e562d0fbe75fedffd321e750eccd1511ad4ff45a","index":2,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"errand1/e562d0fbe75fedffd321e750eccd1511ad4ff45a","index":2,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"errand_without_package/1bfc81a13748dea90e82166d979efa414ea6f976","index":3,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"errand_without_package/1bfc81a13748dea90e82166d979efa414ea6f976","index":3,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"fails_with_too_much_output/a005cfa7aef65373afdd46df22c2451362b050e9","index":4,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"fails_with_too_much_output/a005cfa7aef65373afdd46df22c2451362b050e9","index":4,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar/47eeeaec61f68baf6fc94108ac32aece496fa50e","index":5,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar/47eeeaec61f68baf6fc94108ac32aece496fa50e","index":5,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_with_bad_properties/3542741effbd673a38dc6ecba33795298487640e","index":6,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_with_bad_properties/3542741effbd673a38dc6ecba33795298487640e","index":6,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_with_bad_properties_2/e275bd0a977ea784dd636545e3184961b3cfab33","index":7,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_with_bad_properties_2/e275bd0a977ea784dd636545e3184961b3cfab33","index":7,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_without_packages/2d800134e61f835c6dd1fb15d813122c81ebb69e","index":8,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"foobar_without_packages/2d800134e61f835c6dd1fb15d813122c81ebb69e","index":8,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"has_drain_script/e3d67befd3013db7c91628f9a146cc5de264cba9","index":9,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"has_drain_script/e3d67befd3013db7c91628f9a146cc5de264cba9","index":9,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"id_job/263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81","index":10,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"id_job/263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81","index":10,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_many_properties/2950ecf5d736be6a9f0290350dcf37901d8ea4f1","index":11,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_many_properties/2950ecf5d736be6a9f0290350dcf37901d8ea4f1","index":11,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_post_deploy_script/61db957436288c4c5ad3708860709f593a370869","index":12,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_post_deploy_script/61db957436288c4c5ad3708860709f593a370869","index":12,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_pre_start_script/119130db1e3716a643ea3e5770ee615907c4f260","index":13,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_1_with_pre_start_script/119130db1e3716a643ea3e5770ee615907c4f260","index":13,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_many_properties/e544d24d313484b715c45a7c19cc8a3a1757ba78","index":14,"state":"started","progress":0}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_many_properties/e544d24d313484b715c45a7c19cc8a3a1757ba78","index":14,"state":"finished","progress":100}\n{"time":1523401871,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_post_deploy_script/74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b","index":15,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_post_deploy_script/74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b","index":15,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_pre_start_script/cca21652453a1c034f93956d12f2e8e46be4435b","index":16,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_2_with_pre_start_script/cca21652453a1c034f93956d12f2e8e46be4435b","index":16,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_3_with_broken_post_deploy_script/663fca30979cafb71d7a24bf0b775ffc348363c1","index":17,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_3_with_broken_post_deploy_script/663fca30979cafb71d7a24bf0b775ffc348363c1","index":17,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_3_with_many_properties/7a09666d3555ca6be468918ff632a39d91f32684","index":18,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_3_with_many_properties/7a09666d3555ca6be468918ff632a39d91f32684","index":18,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_that_modifies_properties/e03cb3183f23fb5f004fde0bd04b518e69bdaafb","index":19,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_that_modifies_properties/e03cb3183f23fb5f004fde0bd04b518e69bdaafb","index":19,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_bad_template/c81c0f33892981a8f4bec30dcd90cfda68ab52c6","index":20,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_bad_template/c81c0f33892981a8f4bec30dcd90cfda68ab52c6","index":20,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_blocking_compilation/a76a148bd499d6e50b65b634edcdd9539c743b12","index":21,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_blocking_compilation/a76a148bd499d6e50b65b634edcdd9539c743b12","index":21,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_many_packages/8dc747d5dc774e822bbe2413e0ae1c5e8a825c74","index":22,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_many_packages/8dc747d5dc774e822bbe2413e0ae1c5e8a825c74","index":22,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_post_start_script/cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78","index":23,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_post_start_script/cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78","index":23,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_property_types/71bfdbb4bce71b1c1344d1b0b193d9246f6a6387","index":24,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"job_with_property_types/71bfdbb4bce71b1c1344d1b0b193d9246f6a6387","index":24,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"local_dns_records_json/cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd","index":25,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"local_dns_records_json/cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd","index":25,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"transitive_deps/c0bdff18a9d1859d32276daf36d0716654aea96f","index":26,"state":"started","progress":0}\n{"time":1523401872,"stage":"Creating new jobs","tags":[],"total":26,"task":"transitive_deps/c0bdff18a9d1859d32276daf36d0716654aea96f","index":26,"state":"finished","progress":100}\n{"time":1523401872,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"started","progress":0}\n{"time":1523401872,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"finished","progress":100}\n		
\.


--
-- Name: tasks_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tasks_new_id_seq', 3, true);


--
-- Data for Name: tasks_teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks_teams (task_id, team_id) FROM stdin;
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teams (id, name) FROM stdin;
\.


--
-- Name: teams_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teams_id_seq', 1, false);


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates (id, name, version, blobstore_id, sha1, package_names_json, release_id, logs_json, fingerprint, properties_json, consumes_json, provides_json, templates_json, spec_json) FROM stdin;
1	emoji-errand	d4a4da3c16bd12760b3fcf7c39ef5e503a639c76	7ad81ee2-70de-4a56-9953-a83754de4585	3e906af04767bb6b847fe18f9a85370cf662de0e	[]	1	\N	d4a4da3c16bd12760b3fcf7c39ef5e503a639c76	\N	\N	\N	\N	{"name":"emoji-errand","templates":{"run":"bin/run"},"packages":[],"properties":{}}
2	errand1	e562d0fbe75fedffd321e750eccd1511ad4ff45a	14c2f9fd-eb53-4860-9772-f2c62faec416	e4c41d349cf39d60bd34b6a82ed420a9e5fa8718	["errand1"]	1	\N	e562d0fbe75fedffd321e750eccd1511ad4ff45a	\N	\N	\N	\N	{"name":"errand1","templates":{"ctl":"bin/ctl","run":"bin/run"},"packages":["errand1"],"properties":{"errand1.stdout":{"description":"Stdout to print from the errand script","default":"errand1-stdout"},"errand1.stdout_multiplier":{"description":"Number of times stdout will be repeated in the output","default":1},"errand1.stderr":{"description":"Stderr to print from the errand script","default":"errand1-stderr"},"errand1.stderr_multiplier":{"description":"Number of times stderr will be repeated in the output","default":1},"errand1.run_package_file":{"description":"Should bin/run run script from errand1 package to show that package is present on the vm","default":false},"errand1.exit_code":{"description":"Exit code to return from the errand script","default":0},"errand1.blocking_errand":{"description":"Whether to block errand execution","default":false},"errand1.logs.stdout":{"description":"Output to place into sys/log/errand1/stdout.log","default":"errand1-stdout-log"},"errand1.logs.custom":{"description":"Output to place into sys/log/custom.log","default":"errand1-custom-log"},"errand1.gargamel_color":{"description":"Gargamels color"}}}
3	errand_without_package	1bfc81a13748dea90e82166d979efa414ea6f976	50e31707-865d-4100-b8a2-c78d63f031e4	f2012e7ad15c97a28f07baad697a0a1d078a4c86	[]	1	\N	1bfc81a13748dea90e82166d979efa414ea6f976	\N	\N	\N	\N	{"name":"errand_without_package","templates":{"run":"bin/run"},"packages":[],"properties":{}}
4	fails_with_too_much_output	a005cfa7aef65373afdd46df22c2451362b050e9	d424fd6b-cda4-4d74-b1a2-36a9857ef7ff	50a05654c3ab9e1e27a3910a423ae7d1f66fb40f	["fails_with_too_much_output"]	1	\N	a005cfa7aef65373afdd46df22c2451362b050e9	\N	\N	\N	\N	{"name":"fails_with_too_much_output","templates":{},"packages":["fails_with_too_much_output"],"properties":{}}
5	foobar	47eeeaec61f68baf6fc94108ac32aece496fa50e	0fdba5da-0871-4398-a5b4-07798d959541	57bd8b832aecb467cd4817b5f692b90ece6a8df8	["foo","bar"]	1	\N	47eeeaec61f68baf6fc94108ac32aece496fa50e	\N	\N	\N	\N	{"name":"foobar","templates":{"foobar_ctl":"bin/foobar_ctl","drain.erb":"bin/drain"},"packages":["foo","bar"],"properties":{"test_property":{"description":"A test property","default":1},"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"dynamic_drain_wait1":{"description":"Number of seconds to wait when drain script is first called","default":-3},"dynamic_drain_wait2":{"description":"Number of seconds to wait when drain script is called a second time","default":-2},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}}
6	foobar_with_bad_properties	3542741effbd673a38dc6ecba33795298487640e	81e1a533-4401-48b1-814b-58af44e6ad54	272b1d3a7cc4416f0d332d6e705390acf4bc6ab4	["foo","bar"]	1	\N	3542741effbd673a38dc6ecba33795298487640e	\N	\N	\N	\N	{"name":"foobar_with_bad_properties","templates":{"foobar_ctl":"bin/foobar_ctl","drain.erb":"bin/drain"},"packages":["foo","bar"],"properties":{"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}}
7	foobar_with_bad_properties_2	e275bd0a977ea784dd636545e3184961b3cfab33	d769b17a-cc28-4dda-8585-61eddd041f85	3b6f3586cfd62d028708f42e3100b17366021c11	["foo","bar"]	1	\N	e275bd0a977ea784dd636545e3184961b3cfab33	\N	\N	\N	\N	{"name":"foobar_with_bad_properties_2","templates":{"foobar_ctl":"bin/foobar_ctl","drain.erb":"bin/drain"},"packages":["foo","bar"],"properties":{"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"network_name":{"description":"Network name used for determining printed IP address"},"networks":{"description":"All networks"}}}
8	foobar_without_packages	2d800134e61f835c6dd1fb15d813122c81ebb69e	6e4c5bd4-a139-4756-b805-3f00d5b82c38	18c37d21b485b8553cd754cdb04a7e4363fdf096	[]	1	\N	2d800134e61f835c6dd1fb15d813122c81ebb69e	\N	\N	\N	\N	{"name":"foobar_without_packages","templates":{"foobar_ctl":"bin/foobar_ctl"},"packages":[],"properties":{}}
9	has_drain_script	e3d67befd3013db7c91628f9a146cc5de264cba9	4e2dfc41-2431-4687-b4c7-edd07fef1594	1aac4c6d7a8c470b4d6368adb57ed3a114c410a7	["foo","bar"]	1	\N	e3d67befd3013db7c91628f9a146cc5de264cba9	\N	\N	\N	\N	{"name":"has_drain_script","templates":{"has_drain_script_ctl":"bin/has_drain_script_ctl","drain.erb":"bin/drain"},"packages":["foo","bar"],"properties":{"test_property":{"description":"A test property","default":1},"drain_type":{"description":"Used in drain script to trigger dynamic vs static drain behavior","default":"static"},"dynamic_drain_wait1":{"description":"Number of seconds to wait when drain script is first called","default":-3},"dynamic_drain_wait2":{"description":"Number of seconds to wait when drain script is called a second time","default":-2},"network_name":{"description":"Network name used for determining printed IP address"}}}
10	id_job	263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81	db2e605a-a5ff-4462-87b0-3d0ed0c0e4eb	df7097b82b6b21f978bb6042c748171a76ccad96	[]	1	\N	263a7525d6eb8c4066c7cd84fa80f63d5d7f0e81	\N	\N	\N	\N	{"name":"id_job","templates":{"config.yml.erb":"config.yml"},"properties":{}}
11	job_1_with_many_properties	2950ecf5d736be6a9f0290350dcf37901d8ea4f1	14719018-8380-4b95-b769-724832601910	ec2216a26bdb9dd55d1aaaf96627f12059a3c587	[]	1	\N	2950ecf5d736be6a9f0290350dcf37901d8ea4f1	\N	\N	\N	\N	{"name":"job_1_with_many_properties","templates":{"properties_displayer.yml.erb":"properties_displayer.yml"},"packages":[],"properties":{"smurfs.color":{"description":"The color of the smurfs","default":"blue"},"gargamel.color":{"description":"The color of gargamel it is required"},"gargamel.age":{"description":"The age of gargamel it is required"},"gargamel.dob":{"description":"The DOB of gargamel it is required"}}}
12	job_1_with_post_deploy_script	61db957436288c4c5ad3708860709f593a370869	7935693c-8d24-42cb-a0ac-955f8d04e1fb	fb369983ebfb1024b0fb1c1b3b1b2ae57c37c493	[]	1	\N	61db957436288c4c5ad3708860709f593a370869	\N	\N	\N	\N	{"name":"job_1_with_post_deploy_script","templates":{"post-deploy.erb":"bin/post-deploy","job_1_ctl":"bin/job_1_ctl"},"packages":[],"properties":{"post_deploy_message_1":{"description":"A message echoed by the post-deploy script 1","default":"this is post_deploy_message_1"}}}
13	job_1_with_pre_start_script	119130db1e3716a643ea3e5770ee615907c4f260	2788697b-d027-40c2-9ded-350407d8d51e	ed9f0d641f7ea8d3d1508a07f442aad90324a7a3	[]	1	\N	119130db1e3716a643ea3e5770ee615907c4f260	\N	\N	\N	\N	{"name":"job_1_with_pre_start_script","templates":{"pre-start.erb":"bin/pre-start","job_1_ctl":"bin/job_1_ctl"},"packages":[],"properties":{"pre_start_message_1":{"description":"A message echoed by the pre-start script 1","default":"this is pre_start_message_1"}}}
14	job_2_with_many_properties	e544d24d313484b715c45a7c19cc8a3a1757ba78	88821509-f608-4608-a2a4-8db19746923a	9a7dbe833da74f77a0b9d7a56403c70c2d777311	[]	1	\N	e544d24d313484b715c45a7c19cc8a3a1757ba78	\N	\N	\N	\N	{"name":"job_2_with_many_properties","templates":{"properties_displayer.yml.erb":"properties_displayer.yml"},"packages":[],"properties":{"smurfs.color":{"description":"The color of the smurfs","default":"blue"},"gargamel.color":{"description":"The color of gargamel it is required"}}}
15	job_2_with_post_deploy_script	74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b	61da92eb-4ad4-4f36-9d7f-1247d4df225d	08d6d9aa4a6929bb9d7b79a053a1ff0e3bce369e	[]	1	\N	74e5cf7e71a4ff4cc4f5619092f3e76df48ef85b	\N	\N	\N	\N	{"name":"job_2_with_post_deploy_script","templates":{"post-deploy.erb":"bin/post-deploy","job_2_ctl":"bin/job_2_ctl"},"packages":[],"properties":{}}
16	job_2_with_pre_start_script	cca21652453a1c034f93956d12f2e8e46be4435b	ae2eb642-08d0-4e1e-9097-27a67c6bb6a0	99b48782568d783c8038c0d849ffbba0074842ac	[]	1	\N	cca21652453a1c034f93956d12f2e8e46be4435b	\N	\N	\N	\N	{"name":"job_2_with_pre_start_script","templates":{"pre-start.erb":"bin/pre-start","job_2_ctl":"bin/job_2_ctl"},"packages":[],"properties":{}}
17	job_3_with_broken_post_deploy_script	663fca30979cafb71d7a24bf0b775ffc348363c1	413c0d1b-e8d7-48f7-88a0-76769d2d991d	8716963dd0c91adf5d606d6d136bb894737cfe47	[]	1	\N	663fca30979cafb71d7a24bf0b775ffc348363c1	\N	\N	\N	\N	{"name":"job_3_with_broken_post_deploy_script","templates":{"broken-post-deploy.erb":"bin/post-deploy","job_3_ctl":"bin/job_3_ctl"},"packages":[],"properties":{}}
18	job_3_with_many_properties	7a09666d3555ca6be468918ff632a39d91f32684	8276696e-5063-4427-a58d-7494ad8db6a6	7faead97eef97d96c9897adf78a05d24a983a873	[]	1	\N	7a09666d3555ca6be468918ff632a39d91f32684	\N	\N	\N	\N	{"name":"job_3_with_many_properties","templates":{"properties_displayer.yml.erb":"properties_displayer.yml"},"packages":[],"properties":{"smurfs.color":{"description":"The color of the smurfs","default":"blue"},"gargamel.color":{"description":"The color of gargamel it is required"}}}
19	job_that_modifies_properties	e03cb3183f23fb5f004fde0bd04b518e69bdaafb	30e0ab0a-30c1-444e-8d4c-3da0c1e50ec7	516430dc796761b6142599f382af66879fbec211	["foo","bar"]	1	\N	e03cb3183f23fb5f004fde0bd04b518e69bdaafb	\N	\N	\N	\N	{"name":"job_that_modifies_properties","templates":{"job_that_modifies_properties_ctl":"bin/job_that_modifies_properties_ctl","another_script.erb":"bin/another_script"},"packages":["foo","bar"],"properties":{"some_namespace.test_property":{"description":"A test property","default":1}}}
20	job_with_bad_template	c81c0f33892981a8f4bec30dcd90cfda68ab52c6	01411c27-f123-4839-b1e4-0518555bd1a0	f00872507d3b249f32a589106673731270d33fe5	[]	1	\N	c81c0f33892981a8f4bec30dcd90cfda68ab52c6	\N	\N	\N	\N	{"name":"job_with_bad_template","templates":{"config.yml.erb":"config/config.yml","pre-start.erb":"bin/pre-start"},"packages":[],"properties":{"fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false},"gargamel.color":{"description":"gargamels color"}}}
21	job_with_blocking_compilation	a76a148bd499d6e50b65b634edcdd9539c743b12	c88650d5-edbc-4fe3-9133-4cd29d6923bf	d943b7794b4bd2476001ef0b86d41261a75fb4a9	["blocking_package"]	1	\N	a76a148bd499d6e50b65b634edcdd9539c743b12	\N	\N	\N	\N	{"name":"job_with_blocking_compilation","templates":{},"packages":["blocking_package"],"properties":{}}
22	job_with_many_packages	8dc747d5dc774e822bbe2413e0ae1c5e8a825c74	44555ad0-e3b0-4246-847d-9df47702966e	8dc04c8bd120da145342337453e33be3417ebea4	["foo_1","foo_2","foo_3","foo_4","foo_5","foo_6","foo_7","foo_8","foo_9","foo_10"]	1	\N	8dc747d5dc774e822bbe2413e0ae1c5e8a825c74	\N	\N	\N	\N	{"name":"job_with_many_packages","templates":{},"packages":["foo_1","foo_2","foo_3","foo_4","foo_5","foo_6","foo_7","foo_8","foo_9","foo_10"],"properties":{}}
23	job_with_post_start_script	cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78	9471734e-909d-4ec7-a501-49b05e29165a	e547b74c75f020c9a9ea3f22810af7d8e49b356a	[]	1	\N	cc1df6abeb7fc34acd7c154e6c8cdde8618c6f78	\N	\N	\N	\N	{"name":"job_with_post_start_script","templates":{"post-start.erb":"bin/post-start","job_ctl.erb":"bin/job_ctl"},"packages":[],"properties":{"post_start_message":{"description":"A message echoed by the post-start script","default":"this is post_start_message"},"job_pidfile":{"description":"Path to jobs pid file","default":"/var/vcap/sys/run/job_with_post_start_script.pid"},"exit_code":{"default":0}}}
24	job_with_property_types	71bfdbb4bce71b1c1344d1b0b193d9246f6a6387	7c00ec16-302d-486e-ac2f-d4919f9df9a8	452c12f7ea625d2cd05507b7a594a87452c529f5	[]	1	\N	71bfdbb4bce71b1c1344d1b0b193d9246f6a6387	\N	\N	\N	\N	{"name":"job_with_property_types","templates":{"properties_displayer.yml.erb":"properties_displayer.yml","hardcoded_cert.pem.erb":"hardcoded_cert.pem"},"packages":[],"properties":{"smurfs.phone_password":{"description":"The phone password of the smurfs village","type":"password"},"smurfs.happiness_level":{"description":"The level of the Smurfs overall happiness","type":"happy"},"gargamel.secret_recipe":{"description":"The secret recipe of gargamel to take down the smurfs","type":"password"},"gargamel.password":{"description":"The password I used for everything","default":"abc123","type":"password"},"gargamel.hard_coded_cert":{"description":"The hardcoded cert of gargamel","default":"good luck hardcoding certs and private keys","type":"certificate"}}}
25	local_dns_records_json	cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd	25ec2571-5bef-4c76-82ee-080203b85284	d0be76e4cbe3e4774ee70641bc63159113408899	[]	1	\N	cb0ffc0b94fe0f49d7655a8c1d08570c20b5f3cd	\N	\N	\N	\N	{"name":"local_dns_records_json","templates":{"pre-start.erb":"bin/pre-start"},"packages":[],"properties":{}}
26	transitive_deps	c0bdff18a9d1859d32276daf36d0716654aea96f	69af9b9c-5945-4dad-8065-515198e4c308	af005cc95ca38526509deea6092c7cb93f199e91	["a"]	1	\N	c0bdff18a9d1859d32276daf36d0716654aea96f	\N	\N	\N	\N	{"name":"transitive_deps","templates":{},"packages":["a"],"properties":{}}
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_id_seq', 26, true);


--
-- Data for Name: variable_sets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable_sets (id, deployment_id, created_at, deployed_successfully, writable) FROM stdin;
1	1	2018-04-10 23:11:14.713297	t	f
\.


--
-- Name: variable_sets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variable_sets_id_seq', 1, true);


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variables (id, variable_id, variable_name, variable_set_id, is_local, provider_deployment) FROM stdin;
\.


--
-- Name: variables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_id_seq', 1, false);


--
-- Data for Name: vms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vms (id, instance_id, agent_id, cid, trusted_certs_sha1, active, cpi, created_at) FROM stdin;
3	1	09bc16a8-79a9-49ab-84a7-38141c6c064a	45876	da39a3ee5e6b4b0d3255bfef95601890afd80709	t		2018-04-10 23:11:21.3236
4	2	4c6e18ef-653a-4bf1-9669-f404f96eff63	45886	da39a3ee5e6b4b0d3255bfef95601890afd80709	t		2018-04-10 23:11:21.503746
5	3	017676de-d4a8-4fdd-af66-ec29b5906a99	45890	da39a3ee5e6b4b0d3255bfef95601890afd80709	t		2018-04-10 23:11:21.625468
\.


--
-- Name: vms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vms_id_seq', 5, true);


--
-- Name: agent_dns_versions_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_agent_id_key UNIQUE (agent_id);


--
-- Name: agent_dns_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.agent_dns_versions
    ADD CONSTRAINT agent_dns_versions_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.cloud_configs
    ADD CONSTRAINT cloud_configs_pkey PRIMARY KEY (id);


--
-- Name: compiled_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.compiled_packages
    ADD CONSTRAINT compiled_packages_pkey PRIMARY KEY (id);


--
-- Name: configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.configs
    ADD CONSTRAINT configs_pkey PRIMARY KEY (id);


--
-- Name: cpi_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.cpi_configs
    ADD CONSTRAINT cpi_configs_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deployment_id_config_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_configs
    ADD CONSTRAINT deployment_id_config_id_unique UNIQUE (deployment_id, config_id);


--
-- Name: deployment_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployment_problems
    ADD CONSTRAINT deployment_problems_pkey PRIMARY KEY (id);


--
-- Name: deployment_properties_deployment_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_name_key UNIQUE (deployment_id, name);


--
-- Name: deployment_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployment_properties
    ADD CONSTRAINT deployment_properties_pkey PRIMARY KEY (id);


--
-- Name: deployments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments
    ADD CONSTRAINT deployments_name_key UNIQUE (name);


--
-- Name: deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments
    ADD CONSTRAINT deployments_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_pkey PRIMARY KEY (id);


--
-- Name: deployments_release_versions_release_version_id_deployment__key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_deployment__key UNIQUE (release_version_id, deployment_id);


--
-- Name: deployments_stemcells_deployment_id_stemcell_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_stemcell_id_key UNIQUE (deployment_id, stemcell_id);


--
-- Name: deployments_stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_pkey PRIMARY KEY (id);


--
-- Name: deployments_teams_deployment_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_team_id_key UNIQUE (deployment_id, team_id);


--
-- Name: director_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.director_attributes
    ADD CONSTRAINT director_attributes_pkey PRIMARY KEY (id);


--
-- Name: dns_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.dns_schema
    ADD CONSTRAINT dns_schema_pkey PRIMARY KEY (filename);


--
-- Name: domains_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.domains
    ADD CONSTRAINT domains_name_key UNIQUE (name);


--
-- Name: domains_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- Name: ephemeral_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.blobs
    ADD CONSTRAINT ephemeral_blobs_pkey PRIMARY KEY (id);


--
-- Name: errand_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.errand_runs
    ADD CONSTRAINT errand_runs_pkey PRIMARY KEY (id);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: instances_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instances_agent_id_key UNIQUE (agent_id_bak);


--
-- Name: instances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: instances_templates_instance_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances_templates
    ADD CONSTRAINT instances_templates_instance_id_template_id_key UNIQUE (instance_id, template_id);


--
-- Name: instances_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances_templates
    ADD CONSTRAINT instances_templates_pkey PRIMARY KEY (id);


--
-- Name: instances_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instances_uuid_key UNIQUE (uuid);


--
-- Name: instances_vm_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instances_vm_cid_key UNIQUE (vm_cid_bak);


--
-- Name: ip_addresses_address_temp_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.ip_addresses
    ADD CONSTRAINT ip_addresses_address_temp_key UNIQUE (address_str);


--
-- Name: ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.ip_addresses
    ADD CONSTRAINT ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: local_dns_blobs_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_pkey1 PRIMARY KEY (id);


--
-- Name: local_dns_encoded_azs_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_encoded_azs
    ADD CONSTRAINT local_dns_encoded_azs_name_key UNIQUE (name);


--
-- Name: local_dns_encoded_azs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_encoded_azs
    ADD CONSTRAINT local_dns_encoded_azs_pkey PRIMARY KEY (id);


--
-- Name: local_dns_encoded_instance_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_encoded_instance_groups
    ADD CONSTRAINT local_dns_encoded_instance_groups_pkey PRIMARY KEY (id);


--
-- Name: local_dns_encoded_networks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_encoded_networks
    ADD CONSTRAINT local_dns_encoded_networks_name_key UNIQUE (name);


--
-- Name: local_dns_encoded_networks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_encoded_networks
    ADD CONSTRAINT local_dns_encoded_networks_pkey PRIMARY KEY (id);


--
-- Name: local_dns_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.local_dns_records
    ADD CONSTRAINT local_dns_records_pkey PRIMARY KEY (id);


--
-- Name: locks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.locks
    ADD CONSTRAINT locks_name_key UNIQUE (name);


--
-- Name: locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.locks
    ADD CONSTRAINT locks_pkey PRIMARY KEY (id);


--
-- Name: locks_uid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.locks
    ADD CONSTRAINT locks_uid_key UNIQUE (uid);


--
-- Name: log_bundles_blobstore_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.log_bundles
    ADD CONSTRAINT log_bundles_blobstore_id_key UNIQUE (blobstore_id);


--
-- Name: log_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.log_bundles
    ADD CONSTRAINT log_bundles_pkey PRIMARY KEY (id);


--
-- Name: orphan_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.orphan_disks
    ADD CONSTRAINT orphan_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: orphan_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.orphan_disks
    ADD CONSTRAINT orphan_disks_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_pkey PRIMARY KEY (id);


--
-- Name: orphan_snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: packages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: packages_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: packages_release_versions_package_id_release_version_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_release_version_id_key UNIQUE (package_id, release_version_id);


--
-- Name: packages_release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.packages_release_versions
    ADD CONSTRAINT packages_release_versions_pkey PRIMARY KEY (id);


--
-- Name: persistent_disks_disk_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.persistent_disks
    ADD CONSTRAINT persistent_disks_disk_cid_key UNIQUE (disk_cid);


--
-- Name: persistent_disks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.persistent_disks
    ADD CONSTRAINT persistent_disks_pkey PRIMARY KEY (id);


--
-- Name: records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.records
    ADD CONSTRAINT records_pkey PRIMARY KEY (id);


--
-- Name: release_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.release_versions
    ADD CONSTRAINT release_versions_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.release_versions_templates
    ADD CONSTRAINT release_versions_templates_pkey PRIMARY KEY (id);


--
-- Name: release_versions_templates_release_version_id_template_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_template_id_key UNIQUE (release_version_id, template_id);


--
-- Name: releases_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_name_key UNIQUE (name);


--
-- Name: releases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: rendered_templates_archives_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_pkey PRIMARY KEY (id);


--
-- Name: runtime_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.runtime_configs
    ADD CONSTRAINT runtime_configs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.snapshots
    ADD CONSTRAINT snapshots_pkey PRIMARY KEY (id);


--
-- Name: snapshots_snapshot_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.snapshots
    ADD CONSTRAINT snapshots_snapshot_cid_key UNIQUE (snapshot_cid);


--
-- Name: stemcell_matches_name_version_cpi_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.stemcell_uploads
    ADD CONSTRAINT stemcell_matches_name_version_cpi_key UNIQUE (name, version, cpi);


--
-- Name: stemcell_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.stemcell_uploads
    ADD CONSTRAINT stemcell_matches_pkey PRIMARY KEY (id);


--
-- Name: stemcells_name_version_cpi_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.stemcells
    ADD CONSTRAINT stemcells_name_version_cpi_key UNIQUE (name, version, cpi);


--
-- Name: stemcells_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.stemcells
    ADD CONSTRAINT stemcells_pkey PRIMARY KEY (id);


--
-- Name: tasks_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_new_pkey PRIMARY KEY (id);


--
-- Name: tasks_teams_task_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_team_id_key UNIQUE (task_id, team_id);


--
-- Name: teams_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: templates_release_id_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_release_id_name_version_key UNIQUE (release_id, name, version);


--
-- Name: variable_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.variable_sets
    ADD CONSTRAINT variable_sets_pkey PRIMARY KEY (id);


--
-- Name: variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: vms_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.vms
    ADD CONSTRAINT vms_agent_id_key UNIQUE (agent_id);


--
-- Name: vms_cid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.vms
    ADD CONSTRAINT vms_cid_key UNIQUE (cid);


--
-- Name: vms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY public.vms
    ADD CONSTRAINT vms_pkey PRIMARY KEY (id);


--
-- Name: cloud_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cloud_configs_created_at_index ON public.cloud_configs USING btree (created_at);


--
-- Name: cpi_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cpi_configs_created_at_index ON public.cpi_configs USING btree (created_at);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);


--
-- Name: deployment_problems_deployment_id_state_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deployment_problems_deployment_id_state_created_at_index ON public.deployment_problems USING btree (deployment_id, state, created_at);


--
-- Name: deployment_problems_deployment_id_type_state_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deployment_problems_deployment_id_type_state_index ON public.deployment_problems USING btree (deployment_id, type, state);


--
-- Name: events_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX events_timestamp_index ON public.events USING btree ("timestamp");


--
-- Name: ip_addresses_address_str_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX ip_addresses_address_str_index ON public.ip_addresses USING btree (address_str);


--
-- Name: local_dns_encoded_instance_groups_name_deployment_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX local_dns_encoded_instance_groups_name_deployment_id_index ON public.local_dns_encoded_instance_groups USING btree (name, deployment_id);


--
-- Name: locks_name_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX locks_name_index ON public.locks USING btree (name);


--
-- Name: log_bundles_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX log_bundles_timestamp_index ON public.log_bundles USING btree ("timestamp");


--
-- Name: orphan_disks_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orphan_disks_orphaned_at_index ON public.orphan_disks USING btree (created_at);


--
-- Name: orphan_snapshots_orphaned_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orphan_snapshots_orphaned_at_index ON public.orphan_snapshots USING btree (created_at);


--
-- Name: package_stemcell_build_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX package_stemcell_build_idx ON public.compiled_packages USING btree (package_id, stemcell_os, stemcell_version, build);


--
-- Name: package_stemcell_dependency_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX package_stemcell_dependency_idx ON public.compiled_packages USING btree (package_id, stemcell_os, stemcell_version, dependency_key_sha1);


--
-- Name: packages_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX packages_fingerprint_index ON public.packages USING btree (fingerprint);


--
-- Name: packages_sha1_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX packages_sha1_index ON public.packages USING btree (sha1);


--
-- Name: records_domain_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_domain_id_index ON public.records USING btree (domain_id);


--
-- Name: records_name_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_name_index ON public.records USING btree (name);


--
-- Name: records_name_type_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX records_name_type_index ON public.records USING btree (name, type);


--
-- Name: rendered_templates_archives_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX rendered_templates_archives_created_at_index ON public.rendered_templates_archives USING btree (created_at);


--
-- Name: runtime_configs_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX runtime_configs_created_at_index ON public.runtime_configs USING btree (created_at);


--
-- Name: tasks_context_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_context_id_index ON public.tasks USING btree (context_id);


--
-- Name: tasks_description_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_description_index ON public.tasks USING btree (description);


--
-- Name: tasks_state_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_state_index ON public.tasks USING btree (state);


--
-- Name: tasks_timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tasks_timestamp_index ON public.tasks USING btree ("timestamp");


--
-- Name: templates_fingerprint_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX templates_fingerprint_index ON public.templates USING btree (fingerprint);


--
-- Name: templates_sha1_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX templates_sha1_index ON public.templates USING btree (sha1);


--
-- Name: unique_attribute_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX unique_attribute_name ON public.director_attributes USING btree (name);


--
-- Name: variable_set_name_provider_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX variable_set_name_provider_idx ON public.variables USING btree (variable_set_id, variable_name, provider_deployment);


--
-- Name: variable_sets_created_at_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX variable_sets_created_at_index ON public.variable_sets USING btree (created_at);


--
-- Name: compiled_packages_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compiled_packages
    ADD CONSTRAINT compiled_packages_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.packages(id);


--
-- Name: deployment_problems_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployment_problems
    ADD CONSTRAINT deployment_problems_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id);


--
-- Name: deployment_properties_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployment_properties
    ADD CONSTRAINT deployment_properties_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id);


--
-- Name: deployments_configs_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_configs
    ADD CONSTRAINT deployments_configs_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.configs(id) ON DELETE CASCADE;


--
-- Name: deployments_configs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_configs
    ADD CONSTRAINT deployments_configs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_release_versions_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id);


--
-- Name: deployments_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_release_versions
    ADD CONSTRAINT deployments_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES public.release_versions(id);


--
-- Name: deployments_stemcells_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id);


--
-- Name: deployments_stemcells_stemcell_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_stemcells
    ADD CONSTRAINT deployments_stemcells_stemcell_id_fkey FOREIGN KEY (stemcell_id) REFERENCES public.stemcells(id);


--
-- Name: deployments_teams_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_teams
    ADD CONSTRAINT deployments_teams_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE CASCADE;


--
-- Name: deployments_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deployments_teams
    ADD CONSTRAINT deployments_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: errand_runs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.errand_runs
    ADD CONSTRAINT errand_runs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE CASCADE;


--
-- Name: instance_table_variable_set_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instance_table_variable_set_fkey FOREIGN KEY (variable_set_id) REFERENCES public.variable_sets(id);


--
-- Name: instances_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances
    ADD CONSTRAINT instances_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id);


--
-- Name: instances_templates_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances_templates
    ADD CONSTRAINT instances_templates_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: instances_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instances_templates
    ADD CONSTRAINT instances_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(id);


--
-- Name: ip_addresses_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_addresses
    ADD CONSTRAINT ip_addresses_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: local_dns_blobs_blob_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_blobs
    ADD CONSTRAINT local_dns_blobs_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES public.blobs(id);


--
-- Name: local_dns_encoded_instance_groups_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_encoded_instance_groups
    ADD CONSTRAINT local_dns_encoded_instance_groups_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE CASCADE;


--
-- Name: local_dns_records_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_dns_records
    ADD CONSTRAINT local_dns_records_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: orphan_snapshots_orphan_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orphan_snapshots
    ADD CONSTRAINT orphan_snapshots_orphan_disk_id_fkey FOREIGN KEY (orphan_disk_id) REFERENCES public.orphan_disks(id);


--
-- Name: packages_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_release_id_fkey FOREIGN KEY (release_id) REFERENCES public.releases(id);


--
-- Name: packages_release_versions_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packages_release_versions
    ADD CONSTRAINT packages_release_versions_package_id_fkey FOREIGN KEY (package_id) REFERENCES public.packages(id);


--
-- Name: packages_release_versions_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packages_release_versions
    ADD CONSTRAINT packages_release_versions_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES public.release_versions(id);


--
-- Name: persistent_disks_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persistent_disks
    ADD CONSTRAINT persistent_disks_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: records_domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.records
    ADD CONSTRAINT records_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES public.domains(id) ON DELETE CASCADE;


--
-- Name: release_versions_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.release_versions
    ADD CONSTRAINT release_versions_release_id_fkey FOREIGN KEY (release_id) REFERENCES public.releases(id);


--
-- Name: release_versions_templates_release_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.release_versions_templates
    ADD CONSTRAINT release_versions_templates_release_version_id_fkey FOREIGN KEY (release_version_id) REFERENCES public.release_versions(id);


--
-- Name: release_versions_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.release_versions_templates
    ADD CONSTRAINT release_versions_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(id);


--
-- Name: rendered_templates_archives_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rendered_templates_archives
    ADD CONSTRAINT rendered_templates_archives_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: snapshots_persistent_disk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snapshots
    ADD CONSTRAINT snapshots_persistent_disk_id_fkey FOREIGN KEY (persistent_disk_id) REFERENCES public.persistent_disks(id);


--
-- Name: tasks_teams_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks_teams
    ADD CONSTRAINT tasks_teams_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: tasks_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks_teams
    ADD CONSTRAINT tasks_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: templates_release_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_release_id_fkey FOREIGN KEY (release_id) REFERENCES public.releases(id);


--
-- Name: variable_sets_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_sets
    ADD CONSTRAINT variable_sets_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE CASCADE;


--
-- Name: variable_table_variable_set_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variable_table_variable_set_fkey FOREIGN KEY (variable_set_id) REFERENCES public.variable_sets(id) ON DELETE CASCADE;


--
-- Name: vms_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vms
    ADD CONSTRAINT vms_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.instances(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pivotal
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pivotal;
GRANT ALL ON SCHEMA public TO pivotal;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

