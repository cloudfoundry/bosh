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
-- Name: configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE configs (
    id integer NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deleted boolean DEFAULT false
);


ALTER TABLE configs OWNER TO postgres;

--
-- Name: configs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE configs_id_seq OWNER TO postgres;

--
-- Name: configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE configs_id_seq OWNED BY configs.id;


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
    link_spec_json text
);


ALTER TABLE deployments OWNER TO postgres;

--
-- Name: deployments_configs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE deployments_configs (
    deployment_id integer NOT NULL,
    config_id integer NOT NULL
);


ALTER TABLE deployments_configs OWNER TO postgres;

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
    deployment_id integer DEFAULT (-1) NOT NULL,
    errand_name text,
    successful_state_hash character varying(512)
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
    trusted_certs_sha1_bak text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    update_completed boolean DEFAULT false,
    ignore boolean DEFAULT false,
    variable_set_id bigint NOT NULL
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
    static boolean,
    instance_id integer,
    created_at timestamp without time zone,
    task_id text,
    address_str text NOT NULL
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
-- Name: local_dns_encoded_azs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE local_dns_encoded_azs (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE local_dns_encoded_azs OWNER TO postgres;

--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_encoded_azs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_encoded_azs_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_encoded_azs_id_seq OWNED BY local_dns_encoded_azs.id;


--
-- Name: local_dns_encoded_instance_groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE local_dns_encoded_instance_groups (
    id integer NOT NULL,
    name text NOT NULL,
    deployment_id integer NOT NULL
);


ALTER TABLE local_dns_encoded_instance_groups OWNER TO postgres;

--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_encoded_instance_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_encoded_instance_groups_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_encoded_instance_groups_id_seq OWNED BY local_dns_encoded_instance_groups.id;


--
-- Name: local_dns_encoded_networks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE local_dns_encoded_networks (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE local_dns_encoded_networks OWNER TO postgres;

--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE local_dns_encoded_networks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE local_dns_encoded_networks_id_seq OWNER TO postgres;

--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE local_dns_encoded_networks_id_seq OWNED BY local_dns_encoded_networks.id;


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
    uid text NOT NULL,
    task_id text DEFAULT ''::text NOT NULL
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
    created_at timestamp without time zone NOT NULL,
    cpi text DEFAULT ''::text
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
    name text DEFAULT ''::text,
    cpi text DEFAULT ''::text
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
    provides_json text,
    templates_json text,
    spec_json text
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
-- Name: variable_sets; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE variable_sets (
    id bigint NOT NULL,
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
    id bigint NOT NULL,
    variable_id text NOT NULL,
    variable_name text NOT NULL,
    variable_set_id bigint NOT NULL,
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
    trusted_certs_sha1 text DEFAULT 'da39a3ee5e6b4b0d3255bfef95601890afd80709'::text,
    active boolean DEFAULT false,
    cpi text DEFAULT ''::text,
    created_at timestamp without time zone
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

ALTER TABLE ONLY configs ALTER COLUMN id SET DEFAULT nextval('configs_id_seq'::regclass);


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

ALTER TABLE ONLY local_dns_encoded_azs ALTER COLUMN id SET DEFAULT nextval('local_dns_encoded_azs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_encoded_instance_groups ALTER COLUMN id SET DEFAULT nextval('local_dns_encoded_instance_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_encoded_networks ALTER COLUMN id SET DEFAULT nextval('local_dns_encoded_networks_id_seq'::regclass);


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
\.


--
-- Name: agent_dns_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('agent_dns_versions_id_seq', 1, false);


--
-- Data for Name: blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY blobs (id, blobstore_id, sha1, created_at, type) FROM stdin;
\.


--
-- Data for Name: cloud_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY cloud_configs (id, properties, created_at) FROM stdin;
\.


--
-- Name: cloud_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cloud_configs_id_seq', 1, false);


--
-- Data for Name: compiled_packages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY compiled_packages (id, blobstore_id, sha1, dependency_key, build, package_id, dependency_key_sha1, stemcell_os, stemcell_version) FROM stdin;
1	c78d98f3-6b0b-4ac0-5a2f-efed9d15a0a2	7bbc36917f2739370f376716619de471bf7aedd0	[]	1	2	97d170e1550eee4afc0af065b78cda302a97674c	toronto-os	1
2	f2fbcb79-11b7-459f-403a-566b371f103f	c3d179c034764727ccba3393a5d8020e9caf3e9a	[["pkg_2","fa48497a19f12e925b32fcb8f5ca2b42144e4444"]]	1	3	b048798b462817f4ae6a5345dd9a0c45d1a1c8ea	toronto-os	1
\.


--
-- Name: compiled_packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('compiled_packages_id_seq', 2, true);


--
-- Data for Name: configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY configs (id, name, type, content, created_at, deleted) FROM stdin;
1	default	cloud	azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n- name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nvm_types:\n- cloud_properties: {}\n  name: a\n	2018-03-01 22:59:21.256506	f
\.


--
-- Name: configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('configs_id_seq', 1, true);


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

SELECT pg_catalog.setval('delayed_jobs_id_seq', 15, true);


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

COPY deployments (id, name, manifest, link_spec_json) FROM stdin;
5	explicit_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: explicit_db\n  name: explicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        from: explicit_db\n      db:\n        from: explicit_db\n    name: api_server\n  name: explicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: explicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
1	errand_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  name: errand_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
2	shared_provider_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_provider_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{"shared_provider_ig":{"database":{"my_shared_db":{"db":{"deployment_name":"shared_provider_deployment","domain":"bosh","default_network":"a","networks":["a"],"instance_group":"shared_provider_ig","properties":{"foo":"normal_bar"},"instances":[{"name":"shared_provider_ig","id":"47ade923-b976-416c-851a-41e5860fc1ad","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3","addresses":{"a":"192.168.1.3"},"dns_addresses":{"a":"192.168.1.3"}}]}}}}}
3	shared_consumer_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_consumer_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
4	implicit_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n  name: implicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: api_server\n  name: implicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: implicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
\.


--
-- Data for Name: deployments_configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_configs (deployment_id, config_id) FROM stdin;
1	1
2	1
3	1
4	1
5	1
\.


--
-- Name: deployments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_id_seq', 5, true);


--
-- Data for Name: deployments_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_release_versions (id, release_version_id, deployment_id) FROM stdin;
1	1	1
2	1	2
3	1	3
4	1	4
5	1	5
\.


--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_release_versions_id_seq', 5, true);


--
-- Data for Name: deployments_stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_stemcells (id, deployment_id, stemcell_id) FROM stdin;
1	1	1
2	2	1
3	3	1
4	4	1
5	5	1
\.


--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_stemcells_id_seq', 5, true);


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
2	1.168.192.in-addr.arpa	\N	\N	NATIVE	\N	\N
\.


--
-- Name: domains_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('domains_id_seq', 2, true);


--
-- Name: ephemeral_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ephemeral_blobs_id_seq', 1, false);


--
-- Data for Name: errand_runs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY errand_runs (id, deployment_id, errand_name, successful_state_hash) FROM stdin;
\.


--
-- Name: errand_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('errand_runs_id_seq', 1, false);


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY events (id, parent_id, "user", "timestamp", action, object_type, object_name, error, task, deployment, instance, context_json) FROM stdin;
1	\N	_director	2018-03-01 22:59:17.230504	start	worker	worker_0	\N	\N	\N	\N	{}
2	\N	_director	2018-03-01 22:59:17.264832	start	worker	worker_1	\N	\N	\N	\N	{}
3	\N	_director	2018-03-01 22:59:17.282208	start	worker	worker_2	\N	\N	\N	\N	{}
4	\N	_director	2018-03-01 22:59:17.309288	start	director	deadbeef	\N	\N	\N	\N	{"version":"0.0.0"}
5	\N	test	2018-03-01 22:59:18.399619	acquire	lock	lock:release:bosh-release	\N	1	\N	\N	{}
6	\N	test	2018-03-01 22:59:19.657169	release	lock	lock:release:bosh-release	\N	1	\N	\N	{}
7	\N	test	2018-03-01 22:59:21.258921	update	cloud-config	default	\N	\N	\N	\N	{}
8	\N	test	2018-03-01 22:59:21.864255	create	deployment	errand_deployment	\N	3	errand_deployment	\N	{}
9	\N	test	2018-03-01 22:59:21.881097	acquire	lock	lock:deployment:errand_deployment	\N	3	errand_deployment	\N	{}
10	\N	test	2018-03-01 22:59:22.099886	acquire	lock	lock:release:bosh-release	\N	3	\N	\N	{}
11	\N	test	2018-03-01 22:59:22.129545	release	lock	lock:release:bosh-release	\N	3	\N	\N	{}
12	\N	test	2018-03-01 22:59:22.455662	create	vm	\N	\N	3	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
13	12	test	2018-03-01 22:59:22.907937	create	vm	58249	\N	3	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
14	\N	test	2018-03-01 22:59:23.251575	create	instance	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	\N	3	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{"az":"z1"}
15	14	test	2018-03-01 22:59:29.571898	create	instance	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	\N	3	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
16	8	test	2018-03-01 22:59:29.61747	create	deployment	errand_deployment	\N	3	errand_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
17	\N	test	2018-03-01 22:59:29.625671	release	lock	lock:deployment:errand_deployment	\N	3	errand_deployment	\N	{}
18	\N	test	2018-03-01 22:59:30.473378	create	deployment	shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
19	\N	test	2018-03-01 22:59:30.489724	acquire	lock	lock:deployment:shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
20	\N	test	2018-03-01 22:59:30.636365	acquire	lock	lock:release:bosh-release	\N	4	\N	\N	{}
21	\N	test	2018-03-01 22:59:30.655391	release	lock	lock:release:bosh-release	\N	4	\N	\N	{}
22	\N	test	2018-03-01 22:59:30.898816	create	vm	\N	\N	4	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
23	22	test	2018-03-01 22:59:31.127874	create	vm	58428	\N	4	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
24	\N	test	2018-03-01 22:59:31.489944	create	instance	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	\N	4	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{"az":"z1"}
25	24	test	2018-03-01 22:59:37.800878	create	instance	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	\N	4	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
26	18	test	2018-03-01 22:59:37.840036	create	deployment	shared_provider_deployment	\N	4	shared_provider_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
27	\N	test	2018-03-01 22:59:37.849488	release	lock	lock:deployment:shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
28	\N	test	2018-03-01 22:59:38.862808	create	deployment	shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
29	\N	test	2018-03-01 22:59:38.880204	acquire	lock	lock:deployment:shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
30	\N	test	2018-03-01 22:59:39.026728	acquire	lock	lock:release:bosh-release	\N	5	\N	\N	{}
31	\N	test	2018-03-01 22:59:39.045962	release	lock	lock:release:bosh-release	\N	5	\N	\N	{}
32	\N	test	2018-03-01 22:59:39.250928	acquire	lock	lock:compile:2:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
33	\N	test	2018-03-01 22:59:39.2774	create	instance	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
34	\N	test	2018-03-01 22:59:39.330798	create	vm	\N	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
35	34	test	2018-03-01 22:59:39.915446	create	vm	58530	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
36	33	test	2018-03-01 22:59:40.169716	create	instance	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
37	\N	test	2018-03-01 22:59:41.365816	delete	instance	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
38	\N	test	2018-03-01 22:59:41.383495	delete	vm	58530	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
39	38	test	2018-03-01 22:59:41.55945	delete	vm	58530	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
40	37	test	2018-03-01 22:59:41.583756	delete	instance	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	\N	5	shared_consumer_deployment	compilation-4635c09d-4cde-4b0f-980d-a368a93af157/ccebf061-ab32-4204-b640-3e1c637798cd	{}
41	\N	test	2018-03-01 22:59:41.613139	release	lock	lock:compile:2:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
42	\N	test	2018-03-01 22:59:41.740123	acquire	lock	lock:compile:3:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
43	\N	test	2018-03-01 22:59:41.76724	create	instance	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
44	\N	test	2018-03-01 22:59:41.820064	create	vm	\N	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
45	44	test	2018-03-01 22:59:43.324059	create	vm	58547	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
46	43	test	2018-03-01 22:59:43.561193	create	instance	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
47	\N	test	2018-03-01 22:59:44.747476	delete	instance	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
48	\N	test	2018-03-01 22:59:44.767834	delete	vm	58547	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
49	48	test	2018-03-01 22:59:44.930752	delete	vm	58547	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
50	47	test	2018-03-01 22:59:44.952963	delete	instance	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	\N	5	shared_consumer_deployment	compilation-fe73294e-609f-480c-bbed-6734e37cfc5c/f35028e2-8d93-4d1f-b02c-ade5eec42f96	{}
51	\N	test	2018-03-01 22:59:44.979864	release	lock	lock:compile:3:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
52	\N	test	2018-03-01 22:59:45.094033	create	vm	\N	\N	5	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
53	52	test	2018-03-01 22:59:45.690184	create	vm	58564	\N	5	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
54	\N	test	2018-03-01 22:59:46.078581	create	instance	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	\N	5	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{"az":"z1"}
55	54	test	2018-03-01 22:59:52.405822	create	instance	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	\N	5	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
56	28	test	2018-03-01 22:59:52.444868	create	deployment	shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
57	\N	test	2018-03-01 22:59:52.453127	release	lock	lock:deployment:shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
58	\N	test	2018-03-01 22:59:54.785887	create	deployment	implicit_deployment	\N	7	implicit_deployment	\N	{}
59	\N	test	2018-03-01 22:59:54.802951	acquire	lock	lock:deployment:implicit_deployment	\N	7	implicit_deployment	\N	{}
60	\N	test	2018-03-01 22:59:54.961346	acquire	lock	lock:release:bosh-release	\N	7	\N	\N	{}
61	\N	test	2018-03-01 22:59:54.980968	release	lock	lock:release:bosh-release	\N	7	\N	\N	{}
62	\N	test	2018-03-01 22:59:55.3915	create	vm	\N	\N	7	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
63	\N	test	2018-03-01 22:59:55.401841	create	vm	\N	\N	7	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
64	63	test	2018-03-01 22:59:55.68787	create	vm	58663	\N	7	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
65	62	test	2018-03-01 22:59:55.856474	create	vm	58670	\N	7	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
66	\N	test	2018-03-01 22:59:57.249381	create	instance	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	\N	7	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{"az":"z1"}
67	66	test	2018-03-01 23:00:03.613925	create	instance	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	\N	7	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
68	\N	test	2018-03-01 23:00:03.662392	create	instance	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	\N	7	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{"az":"z1"}
69	68	test	2018-03-01 23:00:09.983985	create	instance	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	\N	7	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
70	58	test	2018-03-01 23:00:10.029	create	deployment	implicit_deployment	\N	7	implicit_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
71	\N	test	2018-03-01 23:00:10.036872	release	lock	lock:deployment:implicit_deployment	\N	7	implicit_deployment	\N	{}
72	\N	test	2018-03-01 23:00:12.213844	create	deployment	explicit_deployment	\N	9	explicit_deployment	\N	{}
73	\N	test	2018-03-01 23:00:12.230122	acquire	lock	lock:deployment:explicit_deployment	\N	9	explicit_deployment	\N	{}
74	\N	test	2018-03-01 23:00:12.391192	acquire	lock	lock:release:bosh-release	\N	9	\N	\N	{}
75	\N	test	2018-03-01 23:00:12.409543	release	lock	lock:release:bosh-release	\N	9	\N	\N	{}
76	\N	test	2018-03-01 23:00:12.826109	create	vm	\N	\N	9	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
77	\N	test	2018-03-01 23:00:12.829956	create	vm	\N	\N	9	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
78	76	test	2018-03-01 23:00:13.170277	create	vm	58708	\N	9	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
79	77	test	2018-03-01 23:00:13.534871	create	vm	58717	\N	9	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
80	\N	test	2018-03-01 23:00:13.911262	create	instance	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	\N	9	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{"az":"z1"}
81	80	test	2018-03-01 23:00:21.248582	create	instance	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	\N	9	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
82	\N	test	2018-03-01 23:00:21.297485	create	instance	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	\N	9	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{"az":"z1"}
83	82	test	2018-03-01 23:00:27.618419	create	instance	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	\N	9	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
84	72	test	2018-03-01 23:00:27.663229	create	deployment	explicit_deployment	\N	9	explicit_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
85	\N	test	2018-03-01 23:00:27.671718	release	lock	lock:deployment:explicit_deployment	\N	9	explicit_deployment	\N	{}
86	\N	test	2018-03-01 23:00:28.832896	update	deployment	errand_deployment	\N	11	errand_deployment	\N	{}
87	\N	test	2018-03-01 23:00:28.849566	acquire	lock	lock:deployment:errand_deployment	\N	11	errand_deployment	\N	{}
88	\N	test	2018-03-01 23:00:29.000679	acquire	lock	lock:release:bosh-release	\N	11	\N	\N	{}
89	\N	test	2018-03-01 23:00:29.015942	release	lock	lock:release:bosh-release	\N	11	\N	\N	{}
90	\N	test	2018-03-01 23:00:29.378675	stop	instance	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	\N	11	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
91	\N	test	2018-03-01 23:00:29.475421	delete	vm	58249	\N	11	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
92	91	test	2018-03-01 23:00:29.64975	delete	vm	58249	\N	11	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
93	90	test	2018-03-01 23:00:29.741208	stop	instance	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	\N	11	errand_deployment	errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0	{}
94	86	test	2018-03-01 23:00:29.780925	update	deployment	errand_deployment	\N	11	errand_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
95	\N	test	2018-03-01 23:00:29.789342	release	lock	lock:deployment:errand_deployment	\N	11	errand_deployment	\N	{}
96	\N	test	2018-03-01 23:00:30.4853	update	deployment	shared_provider_deployment	\N	12	shared_provider_deployment	\N	{}
97	\N	test	2018-03-01 23:00:30.503463	acquire	lock	lock:deployment:shared_provider_deployment	\N	12	shared_provider_deployment	\N	{}
98	\N	test	2018-03-01 23:00:30.645831	acquire	lock	lock:release:bosh-release	\N	12	\N	\N	{}
99	\N	test	2018-03-01 23:00:30.661789	release	lock	lock:release:bosh-release	\N	12	\N	\N	{}
100	\N	test	2018-03-01 23:00:30.937832	stop	instance	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	\N	12	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
101	\N	test	2018-03-01 23:00:31.022526	delete	vm	58428	\N	12	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
102	101	test	2018-03-01 23:00:31.185122	delete	vm	58428	\N	12	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
103	100	test	2018-03-01 23:00:31.283098	stop	instance	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	\N	12	shared_provider_deployment	shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad	{}
104	96	test	2018-03-01 23:00:31.313988	update	deployment	shared_provider_deployment	\N	12	shared_provider_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
105	\N	test	2018-03-01 23:00:31.321782	release	lock	lock:deployment:shared_provider_deployment	\N	12	shared_provider_deployment	\N	{}
106	\N	test	2018-03-01 23:00:31.950184	update	deployment	shared_consumer_deployment	\N	13	shared_consumer_deployment	\N	{}
107	\N	test	2018-03-01 23:00:31.966656	acquire	lock	lock:deployment:shared_consumer_deployment	\N	13	shared_consumer_deployment	\N	{}
108	\N	test	2018-03-01 23:00:32.10879	acquire	lock	lock:release:bosh-release	\N	13	\N	\N	{}
109	\N	test	2018-03-01 23:00:32.124403	release	lock	lock:release:bosh-release	\N	13	\N	\N	{}
110	\N	test	2018-03-01 23:00:32.414712	stop	instance	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	\N	13	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
111	\N	test	2018-03-01 23:00:32.500134	delete	vm	58564	\N	13	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
112	111	test	2018-03-01 23:00:32.669731	delete	vm	58564	\N	13	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
113	110	test	2018-03-01 23:00:32.762238	stop	instance	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	\N	13	shared_consumer_deployment	shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	{}
114	106	test	2018-03-01 23:00:32.794698	update	deployment	shared_consumer_deployment	\N	13	shared_consumer_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
115	\N	test	2018-03-01 23:00:32.802107	release	lock	lock:deployment:shared_consumer_deployment	\N	13	shared_consumer_deployment	\N	{}
116	\N	test	2018-03-01 23:00:33.484599	update	deployment	implicit_deployment	\N	14	implicit_deployment	\N	{}
117	\N	test	2018-03-01 23:00:33.501266	acquire	lock	lock:deployment:implicit_deployment	\N	14	implicit_deployment	\N	{}
118	\N	test	2018-03-01 23:00:33.652591	acquire	lock	lock:release:bosh-release	\N	14	\N	\N	{}
119	\N	test	2018-03-01 23:00:33.668601	release	lock	lock:release:bosh-release	\N	14	\N	\N	{}
120	\N	test	2018-03-01 23:00:34.106342	stop	instance	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	\N	14	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
121	\N	test	2018-03-01 23:00:34.195667	delete	vm	58670	\N	14	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
122	121	test	2018-03-01 23:00:34.361778	delete	vm	58670	\N	14	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
123	120	test	2018-03-01 23:00:34.457923	stop	instance	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	\N	14	implicit_deployment	implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04	{}
124	\N	test	2018-03-01 23:00:34.512748	stop	instance	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	\N	14	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
125	\N	test	2018-03-01 23:00:34.597053	delete	vm	58663	\N	14	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
126	125	test	2018-03-01 23:00:34.767254	delete	vm	58663	\N	14	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
127	124	test	2018-03-01 23:00:34.861387	stop	instance	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	\N	14	implicit_deployment	implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047	{}
128	116	test	2018-03-01 23:00:34.895692	update	deployment	implicit_deployment	\N	14	implicit_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
129	\N	test	2018-03-01 23:00:34.904717	release	lock	lock:deployment:implicit_deployment	\N	14	implicit_deployment	\N	{}
130	\N	test	2018-03-01 23:00:35.532932	update	deployment	explicit_deployment	\N	15	explicit_deployment	\N	{}
131	\N	test	2018-03-01 23:00:35.549438	acquire	lock	lock:deployment:explicit_deployment	\N	15	explicit_deployment	\N	{}
132	\N	test	2018-03-01 23:00:35.702239	acquire	lock	lock:release:bosh-release	\N	15	\N	\N	{}
133	\N	test	2018-03-01 23:00:35.718334	release	lock	lock:release:bosh-release	\N	15	\N	\N	{}
134	\N	test	2018-03-01 23:00:36.1473	stop	instance	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	\N	15	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
135	\N	test	2018-03-01 23:00:36.237911	delete	vm	58708	\N	15	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
136	135	test	2018-03-01 23:00:36.40055	delete	vm	58708	\N	15	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
137	134	test	2018-03-01 23:00:36.495726	stop	instance	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	\N	15	explicit_deployment	explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a	{}
138	\N	test	2018-03-01 23:00:36.546642	stop	instance	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	\N	15	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
139	\N	test	2018-03-01 23:00:36.6307	delete	vm	58717	\N	15	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
140	139	test	2018-03-01 23:00:36.795041	delete	vm	58717	\N	15	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
141	138	test	2018-03-01 23:00:36.890164	stop	instance	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	\N	15	explicit_deployment	explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983	{}
142	130	test	2018-03-01 23:00:36.92446	update	deployment	explicit_deployment	\N	15	explicit_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
143	\N	test	2018-03-01 23:00:36.933189	release	lock	lock:deployment:explicit_deployment	\N	15	explicit_deployment	\N	{}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 143, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid_bak, agent_id_bak, trusted_certs_sha1_bak, update_completed, ignore, variable_set_id) FROM stdin;
2	errand_consumer_ig	0	1	started	f	422bcc8f-30a2-48af-b0e4-7ae6ba9f0698	z1	\N	f	t	[]	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	f	f	1
1	errand_provider_ig	0	1	detached	f	2b4b770e-6151-4b0d-b33d-90283bf893d0	z1	{}	f	t	["0.errand-provider-ig.a.errand-deployment.bosh","2b4b770e-6151-4b0d-b33d-90283bf893d0.errand-provider-ig.a.errand-deployment.bosh"]	{"deployment":"errand_deployment","job":{"name":"errand_provider_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"bc67ab94a59685e6145e0ed8df557af10f1eab03","blobstore_id":"0944bdef-94bd-4898-8d58-8ebdb9c2b6a4","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"bc67ab94a59685e6145e0ed8df557af10f1eab03","blobstore_id":"0944bdef-94bd-4898-8d58-8ebdb9c2b6a4","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"errand_provider_ig","id":"2b4b770e-6151-4b0d-b33d-90283bf893d0","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"64290aad-8250-43af-a2f1-e8c9e787d0c0","sha1":"5e6da92f2f3b8a8382aa11931ada14a9f90b476b"},"configuration_hash":"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
3	shared_provider_ig	0	2	detached	f	47ade923-b976-416c-851a-41e5860fc1ad	z1	{}	f	t	["0.shared-provider-ig.a.shared-provider-deployment.bosh","47ade923-b976-416c-851a-41e5860fc1ad.shared-provider-ig.a.shared-provider-deployment.bosh"]	{"deployment":"shared_provider_deployment","job":{"name":"shared_provider_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"bc67ab94a59685e6145e0ed8df557af10f1eab03","blobstore_id":"0944bdef-94bd-4898-8d58-8ebdb9c2b6a4","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"bc67ab94a59685e6145e0ed8df557af10f1eab03","blobstore_id":"0944bdef-94bd-4898-8d58-8ebdb9c2b6a4","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_provider_ig","id":"47ade923-b976-416c-851a-41e5860fc1ad","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.3","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.3","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"45d0db7e-62a1-4c5c-8acd-da34e1c15b76","sha1":"a7b7734b43eeb0e54441c1f5b35397a322ff3416"},"configuration_hash":"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	2
8	implicit_consumer_ig	0	4	detached	f	dee7701e-fdfb-4d41-b52c-f387acf6d047	z1	{}	f	t	["0.implicit-consumer-ig.a.implicit-deployment.bosh","dee7701e-fdfb-4d41-b52c-f387acf6d047.implicit-consumer-ig.a.implicit-deployment.bosh"]	{"deployment":"implicit_deployment","job":{"name":"implicit_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"implicit_consumer_ig","id":"dee7701e-fdfb-4d41-b52c-f387acf6d047","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.6","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"c3d179c034764727ccba3393a5d8020e9caf3e9a","blobstore_id":"f2fbcb79-11b7-459f-403a-566b371f103f"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"implicit_deployment","domain":"bosh","instance_group":"implicit_provider_ig","instances":[{"name":"implicit_provider_ig","id":"198d94db-e373-4f04-ba41-d0165461ce04","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.5"}],"networks":["a"],"properties":{"foo":"backup_bar"}},"backup_db":{"default_network":"a","deployment_name":"implicit_deployment","domain":"bosh","instance_group":"implicit_provider_ig","instances":[{"name":"implicit_provider_ig","id":"198d94db-e373-4f04-ba41-d0165461ce04","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.5"}],"networks":["a"],"properties":{"foo":"backup_bar"}}}},"address":"192.168.1.6","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"ecabe6abd51fc81ed7242d34bac9eaf24bcd3fcf"},"rendered_templates_archive":{"blobstore_id":"68588d0c-07e8-4fee-af4f-cb6c55b27613","sha1":"e8da02081eced19620bef6b28694e40047c4d231"},"configuration_hash":"80ae90da9c976dc3302478944ac835c55f14e8d3"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	4
10	explicit_consumer_ig	0	5	detached	f	fc0cca03-efbe-4bbd-95d6-4932cbf48983	z1	{}	f	t	["0.explicit-consumer-ig.a.explicit-deployment.bosh","fc0cca03-efbe-4bbd-95d6-4932cbf48983.explicit-consumer-ig.a.explicit-deployment.bosh"]	{"deployment":"explicit_deployment","job":{"name":"explicit_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"explicit_consumer_ig","id":"fc0cca03-efbe-4bbd-95d6-4932cbf48983","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.8","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"c3d179c034764727ccba3393a5d8020e9caf3e9a","blobstore_id":"f2fbcb79-11b7-459f-403a-566b371f103f"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"explicit_deployment","domain":"bosh","instance_group":"explicit_provider_ig","instances":[{"name":"explicit_provider_ig","id":"f70d45cb-7605-4900-b1c3-43f0d7e08d7a","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.7"}],"networks":["a"],"properties":{"foo":"backup_bar"}},"backup_db":{"default_network":"a","deployment_name":"explicit_deployment","domain":"bosh","instance_group":"explicit_provider_ig","instances":[{"name":"explicit_provider_ig","id":"f70d45cb-7605-4900-b1c3-43f0d7e08d7a","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.7"}],"networks":["a"],"properties":{"foo":"backup_bar"}}}},"address":"192.168.1.8","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"f03578b7c6d05c720756172cdb714b31acfa6ba1"},"rendered_templates_archive":{"blobstore_id":"8d513a1c-b505-4b15-9c81-9f3e3aa53ee6","sha1":"f3cd85bbb16025d4394344c93d02bf762b371f88"},"configuration_hash":"df5ba6ce96f8c938997fb83a86a4b198dce54375"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	5
4	shared_consumer_ig	0	3	detached	f	5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f	z1	{}	f	t	["0.shared-consumer-ig.a.shared-consumer-deployment.bosh","5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f.shared-consumer-ig.a.shared-consumer-deployment.bosh"]	{"deployment":"shared_consumer_deployment","job":{"name":"shared_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"79ca2b04742e191b7e2d833a1dfa8cb66863598d","blobstore_id":"7eea5c00-dbb8-44ac-9985-64f10f1797ef","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_consumer_ig","id":"5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.4","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"c3d179c034764727ccba3393a5d8020e9caf3e9a","blobstore_id":"f2fbcb79-11b7-459f-403a-566b371f103f"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"47ade923-b976-416c-851a-41e5860fc1ad","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}},"backup_db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"47ade923-b976-416c-851a-41e5860fc1ad","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}}}},"address":"192.168.1.4","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"5848bd1151233b96041fa0271b2b2cc9e4d83ea3"},"rendered_templates_archive":{"blobstore_id":"0c9abff1-c87f-40b1-b422-4da70699c5fb","sha1":"a9364e70959369f648ca1e35e26e376718efe5cd"},"configuration_hash":"85ac518bf333f17cde1a44e36ba8f701cfcf3503"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	3
7	implicit_provider_ig	0	4	detached	f	198d94db-e373-4f04-ba41-d0165461ce04	z1	{}	f	t	["0.implicit-provider-ig.a.implicit-deployment.bosh","198d94db-e373-4f04-ba41-d0165461ce04.implicit-provider-ig.a.implicit-deployment.bosh"]	{"deployment":"implicit_deployment","job":{"name":"implicit_provider_ig","templates":[{"name":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"8cd5454cbdc8b58da126b3ac65c2d1509f0ba749","blobstore_id":"5929d149-1993-48c2-acf9-6e88cf853cfa","logs":[]}],"template":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"8cd5454cbdc8b58da126b3ac65c2d1509f0ba749","blobstore_id":"5929d149-1993-48c2-acf9-6e88cf853cfa","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"implicit_provider_ig","id":"198d94db-e373-4f04-ba41-d0165461ce04","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.5","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"backup_database":{"foo":"backup_bar"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.5","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"backup_database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"cd3f9b99-8e60-4711-89e5-5d9bfae61a25","sha1":"fe94838d3a1d028483007eef20bbec027257da6f"},"configuration_hash":"4e4c9c0b7e76b5bc955b215edbd839e427d581aa"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	4
9	explicit_provider_ig	0	5	detached	f	f70d45cb-7605-4900-b1c3-43f0d7e08d7a	z1	{}	f	t	["0.explicit-provider-ig.a.explicit-deployment.bosh","f70d45cb-7605-4900-b1c3-43f0d7e08d7a.explicit-provider-ig.a.explicit-deployment.bosh"]	{"deployment":"explicit_deployment","job":{"name":"explicit_provider_ig","templates":[{"name":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"8cd5454cbdc8b58da126b3ac65c2d1509f0ba749","blobstore_id":"5929d149-1993-48c2-acf9-6e88cf853cfa","logs":[]}],"template":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"8cd5454cbdc8b58da126b3ac65c2d1509f0ba749","blobstore_id":"5929d149-1993-48c2-acf9-6e88cf853cfa","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"explicit_provider_ig","id":"f70d45cb-7605-4900-b1c3-43f0d7e08d7a","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.7","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"backup_database":{"foo":"backup_bar"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.7","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"backup_database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"fc85e39c-181d-4811-911d-dd279945a591","sha1":"66540468ca4bf52dc6c4e62b5afc579c1188683c"},"configuration_hash":"4e4c9c0b7e76b5bc955b215edbd839e427d581aa"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	5
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_id_seq', 10, true);


--
-- Data for Name: instances_templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances_templates (id, instance_id, template_id) FROM stdin;
1	1	11
2	3	11
3	4	2
4	7	9
5	8	2
6	9	9
7	10	2
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_templates_id_seq', 7, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ip_addresses (id, network_name, static, instance_id, created_at, task_id, address_str) FROM stdin;
1	a	f	1	2018-03-01 22:59:22.214023	3	3232235778
2	a	f	3	2018-03-01 22:59:30.707751	4	3232235779
3	a	f	4	2018-03-01 22:59:39.104029	5	3232235780
6	a	f	7	2018-03-01 22:59:55.065531	7	3232235781
7	a	f	8	2018-03-01 22:59:55.075828	7	3232235782
8	a	f	9	2018-03-01 23:00:12.49314	9	3232235783
9	a	f	10	2018-03-01 23:00:12.502923	9	3232235784
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 9, true);


--
-- Data for Name: local_dns_blobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_blobs (id, blob_id, version, created_at) FROM stdin;
\.


--
-- Name: local_dns_blobs_id_seq1; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_blobs_id_seq1', 1, false);


--
-- Data for Name: local_dns_encoded_azs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_encoded_azs (id, name) FROM stdin;
1	z1
\.


--
-- Name: local_dns_encoded_azs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_encoded_azs_id_seq', 1, true);


--
-- Data for Name: local_dns_encoded_instance_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_encoded_instance_groups (id, name, deployment_id) FROM stdin;
1	errand_provider_ig	1
2	errand_consumer_ig	1
3	shared_provider_ig	2
4	shared_consumer_ig	3
5	implicit_provider_ig	4
6	implicit_consumer_ig	4
7	explicit_provider_ig	5
8	explicit_consumer_ig	5
\.


--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_encoded_instance_groups_id_seq', 8, true);


--
-- Data for Name: local_dns_encoded_networks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_encoded_networks (id, name) FROM stdin;
1	a
2	dynamic-network
\.


--
-- Name: local_dns_encoded_networks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_encoded_networks_id_seq', 2, true);


--
-- Data for Name: local_dns_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY local_dns_records (id, ip, az, instance_group, network, deployment, instance_id, agent_id, domain) FROM stdin;
8	192.168.1.2	z1	errand_provider_ig	a	errand_deployment	1	\N	bosh
9	192.168.1.3	z1	shared_provider_ig	a	shared_provider_deployment	3	\N	bosh
10	192.168.1.4	z1	shared_consumer_ig	a	shared_consumer_deployment	4	\N	bosh
11	192.168.1.5	z1	implicit_provider_ig	a	implicit_deployment	7	\N	bosh
12	192.168.1.6	z1	implicit_consumer_ig	a	implicit_deployment	8	\N	bosh
13	192.168.1.7	z1	explicit_provider_ig	a	explicit_deployment	9	\N	bosh
14	192.168.1.8	z1	explicit_consumer_ig	a	explicit_deployment	10	\N	bosh
\.


--
-- Name: local_dns_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_records_id_seq', 14, true);


--
-- Data for Name: locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locks (id, expired_at, name, uid, task_id) FROM stdin;
\.


--
-- Name: locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locks_id_seq', 23, true);


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

COPY orphan_disks (id, disk_cid, size, availability_zone, deployment_name, instance_name, cloud_properties_json, created_at, cpi) FROM stdin;
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
1	pkg_1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b	81cbb943-8e05-44f9-a66a-d7a48f86f647	4f19e494e6281d6dda6ac64aebeceba072abd387	[]	1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b
2	pkg_2	fa48497a19f12e925b32fcb8f5ca2b42144e4444	7a982b01-6ac3-40a7-8395-b73785c00ea6	5fc17067565f49773ee427db3232b634b5a2bd5b	[]	1	fa48497a19f12e925b32fcb8f5ca2b42144e4444
3	pkg_3_depends_on_2	2dfa256bc0b0750ae9952118c428b0dcd1010305	99c61984-aab4-46da-8b60-da67f8b02d54	79bc98cf60f35a24d9dc94ed20e3483a1cfb7a4a	["pkg_2"]	1	2dfa256bc0b0750ae9952118c428b0dcd1010305
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

COPY persistent_disks (id, instance_id, disk_cid, size, active, cloud_properties_json, name, cpi) FROM stdin;
\.


--
-- Name: persistent_disks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('persistent_disks_id_seq', 1, false);


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY records (id, name, type, content, ttl, prio, change_date, domain_id) FROM stdin;
5	1.168.192.in-addr.arpa	SOA	localhost hostmaster@localhost 0 10800 604800 30	14400	\N	\N	2
6	1.168.192.in-addr.arpa	NS	ns.bosh	14400	\N	\N	2
3	ns.bosh	A	\N	18000	\N	1519945235	1
26	0.explicit-provider-ig.a.explicit-deployment.bosh	A	192.168.1.7	300	\N	1519945236	1
27	7.1.168.192.in-addr.arpa	PTR	0.explicit-provider-ig.a.explicit-deployment.bosh	300	\N	1519945236	2
10	0.shared-provider-ig.a.shared-provider-deployment.bosh	A	192.168.1.3	300	\N	1519945231	1
11	3.1.168.192.in-addr.arpa	PTR	0.shared-provider-ig.a.shared-provider-deployment.bosh	300	\N	1519945231	2
12	47ade923-b976-416c-851a-41e5860fc1ad.shared-provider-ig.a.shared-provider-deployment.bosh	A	192.168.1.3	300	\N	1519945231	1
13	3.1.168.192.in-addr.arpa	PTR	47ade923-b976-416c-851a-41e5860fc1ad.shared-provider-ig.a.shared-provider-deployment.bosh	300	\N	1519945231	2
28	f70d45cb-7605-4900-b1c3-43f0d7e08d7a.explicit-provider-ig.a.explicit-deployment.bosh	A	192.168.1.7	300	\N	1519945236	1
29	7.1.168.192.in-addr.arpa	PTR	f70d45cb-7605-4900-b1c3-43f0d7e08d7a.explicit-provider-ig.a.explicit-deployment.bosh	300	\N	1519945236	2
30	0.explicit-consumer-ig.a.explicit-deployment.bosh	A	192.168.1.8	300	\N	1519945236	1
14	0.shared-consumer-ig.a.shared-consumer-deployment.bosh	A	192.168.1.4	300	\N	1519945232	1
15	4.1.168.192.in-addr.arpa	PTR	0.shared-consumer-ig.a.shared-consumer-deployment.bosh	300	\N	1519945232	2
31	8.1.168.192.in-addr.arpa	PTR	0.explicit-consumer-ig.a.explicit-deployment.bosh	300	\N	1519945236	2
32	fc0cca03-efbe-4bbd-95d6-4932cbf48983.explicit-consumer-ig.a.explicit-deployment.bosh	A	192.168.1.8	300	\N	1519945236	1
33	8.1.168.192.in-addr.arpa	PTR	fc0cca03-efbe-4bbd-95d6-4932cbf48983.explicit-consumer-ig.a.explicit-deployment.bosh	300	\N	1519945236	2
4	0.errand-provider-ig.a.errand-deployment.bosh	A	192.168.1.2	300	\N	1519945229	1
7	2.1.168.192.in-addr.arpa	PTR	0.errand-provider-ig.a.errand-deployment.bosh	300	\N	1519945229	2
8	2b4b770e-6151-4b0d-b33d-90283bf893d0.errand-provider-ig.a.errand-deployment.bosh	A	192.168.1.2	300	\N	1519945229	1
9	2.1.168.192.in-addr.arpa	PTR	2b4b770e-6151-4b0d-b33d-90283bf893d0.errand-provider-ig.a.errand-deployment.bosh	300	\N	1519945229	2
16	5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f.shared-consumer-ig.a.shared-consumer-deployment.bosh	A	192.168.1.4	300	\N	1519945232	1
17	4.1.168.192.in-addr.arpa	PTR	5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f.shared-consumer-ig.a.shared-consumer-deployment.bosh	300	\N	1519945232	2
18	0.implicit-provider-ig.a.implicit-deployment.bosh	A	192.168.1.5	300	\N	1519945234	1
19	5.1.168.192.in-addr.arpa	PTR	0.implicit-provider-ig.a.implicit-deployment.bosh	300	\N	1519945234	2
20	198d94db-e373-4f04-ba41-d0165461ce04.implicit-provider-ig.a.implicit-deployment.bosh	A	192.168.1.5	300	\N	1519945234	1
21	5.1.168.192.in-addr.arpa	PTR	198d94db-e373-4f04-ba41-d0165461ce04.implicit-provider-ig.a.implicit-deployment.bosh	300	\N	1519945234	2
22	0.implicit-consumer-ig.a.implicit-deployment.bosh	A	192.168.1.6	300	\N	1519945234	1
23	6.1.168.192.in-addr.arpa	PTR	0.implicit-consumer-ig.a.implicit-deployment.bosh	300	\N	1519945234	2
24	dee7701e-fdfb-4d41-b52c-f387acf6d047.implicit-consumer-ig.a.implicit-deployment.bosh	A	192.168.1.6	300	\N	1519945234	1
25	6.1.168.192.in-addr.arpa	PTR	dee7701e-fdfb-4d41-b52c-f387acf6d047.implicit-consumer-ig.a.implicit-deployment.bosh	300	\N	1519945234	2
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1519945235	1
2	bosh	NS	ns.bosh	14400	\N	1519945235	1
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('records_id_seq', 33, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	9021e8bf3	t
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
1	1	64290aad-8250-43af-a2f1-e8c9e787d0c0	5e6da92f2f3b8a8382aa11931ada14a9f90b476b	6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf	2018-03-01 22:59:23.269463
2	3	45d0db7e-62a1-4c5c-8acd-da34e1c15b76	a7b7734b43eeb0e54441c1f5b35397a322ff3416	6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf	2018-03-01 22:59:31.507303
3	4	0c9abff1-c87f-40b1-b422-4da70699c5fb	a9364e70959369f648ca1e35e26e376718efe5cd	85ac518bf333f17cde1a44e36ba8f701cfcf3503	2018-03-01 22:59:46.097723
4	7	cd3f9b99-8e60-4711-89e5-5d9bfae61a25	fe94838d3a1d028483007eef20bbec027257da6f	4e4c9c0b7e76b5bc955b215edbd839e427d581aa	2018-03-01 22:59:57.266983
5	8	68588d0c-07e8-4fee-af4f-cb6c55b27613	e8da02081eced19620bef6b28694e40047c4d231	80ae90da9c976dc3302478944ac835c55f14e8d3	2018-03-01 23:00:03.679285
6	9	fc85e39c-181d-4811-911d-dd279945a591	66540468ca4bf52dc6c4e62b5afc579c1188683c	4e4c9c0b7e76b5bc955b215edbd839e427d581aa	2018-03-01 23:00:13.928492
7	10	8d513a1c-b505-4b15-9c81-9f3e3aa53ee6	f3cd85bbb16025d4394344c93d02bf762b371f88	df5ba6ce96f8c938997fb83a86a4b198dce54375	2018-03-01 23:00:21.314113
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rendered_templates_archives_id_seq', 7, true);


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
3	done	2018-03-01 22:59:29.642861	create deployment	/deployments/errand_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/3	2018-03-01 22:59:21.831204	update_deployment	test	errand_deployment	2018-03-01 22:59:21.830955	{"time":1519945161,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945162,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945162,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945162,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945162,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0)","index":1,"state":"started","progress":0}\n{"time":1519945163,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0)","index":1,"state":"finished","progress":100}\n{"time":1519945163,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945169,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0) (canary)","index":1,"state":"finished","progress":100}\n		
5	done	2018-03-01 22:59:52.46929	create deployment	/deployments/shared_consumer_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/5	2018-03-01 22:59:38.833001	update_deployment	test	shared_consumer_deployment	2018-03-01 22:59:38.832755	{"time":1519945178,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945179,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945179,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945179,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945179,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":1,"state":"started","progress":0}\n{"time":1519945181,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":1,"state":"finished","progress":100}\n{"time":1519945181,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":2,"state":"started","progress":0}\n{"time":1519945184,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":2,"state":"finished","progress":100}\n{"time":1519945185,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0)","index":1,"state":"started","progress":0}\n{"time":1519945186,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0)","index":1,"state":"finished","progress":100}\n{"time":1519945186,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945192,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0) (canary)","index":1,"state":"finished","progress":100}\n		
8	done	2018-03-01 23:00:11.241355	retrieve vm-stats		/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/8	2018-03-01 23:00:11.163941	vms	test	implicit_deployment	2018-03-01 23:00:11.1637		{"vm_cid":"58670","vm_created_at":"2018-03-01T22:59:55Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.5"],"dns":["198d94db-e373-4f04-ba41-d0165461ce04.implicit-provider-ig.a.implicit-deployment.bosh","0.implicit-provider-ig.a.implicit-deployment.bosh"],"agent_id":"889b82f3-7aea-4255-9ec9-dbf779d4f377","job_name":"implicit_provider_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.1","user":"8.6","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"7"},"system":{"inode_percent":"0","percent":"7"}},"load":["2.38","2.35","2.14"],"mem":{"kb":"9646996","percent":"58"},"swap":{"kb":"133120","percent":"13"},"uptime":{"secs":289459}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"198d94db-e373-4f04-ba41-d0165461ce04","bootstrap":true,"ignore":false}\n{"vm_cid":"58663","vm_created_at":"2018-03-01T22:59:55Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.6"],"dns":["dee7701e-fdfb-4d41-b52c-f387acf6d047.implicit-consumer-ig.a.implicit-deployment.bosh","0.implicit-consumer-ig.a.implicit-deployment.bosh"],"agent_id":"e9598a5f-5853-4216-87a4-15add056e5e9","job_name":"implicit_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.2","user":"9.0","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"7"},"system":{"inode_percent":"0","percent":"7"}},"load":["2.38","2.35","2.14"],"mem":{"kb":"9646992","percent":"58"},"swap":{"kb":"133120","percent":"13"},"uptime":{"secs":289459}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"dee7701e-fdfb-4d41-b52c-f387acf6d047","bootstrap":true,"ignore":false}\n	
6	done	2018-03-01 22:59:53.638062	retrieve vm-stats		/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/6	2018-03-01 22:59:53.585888	vms	test	shared_consumer_deployment	2018-03-01 22:59:53.585607		{"vm_cid":"58564","vm_created_at":"2018-03-01T22:59:45Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.4"],"dns":["5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f.shared-consumer-ig.a.shared-consumer-deployment.bosh","0.shared-consumer-ig.a.shared-consumer-deployment.bosh"],"agent_id":"0d210e67-e21b-45de-b9b8-790126519bf5","job_name":"shared_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"2.5","user":"6.1","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"7"},"system":{"inode_percent":"0","percent":"7"}},"load":["2.38","2.35","2.14"],"mem":{"kb":"9641828","percent":"57"},"swap":{"kb":"133120","percent":"13"},"uptime":{"secs":289441}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f","bootstrap":true,"ignore":false}\n	
11	done	2018-03-01 23:00:29.799639	create deployment	/deployments/errand_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/11	2018-03-01 23:00:28.79749	update_deployment	test	errand_deployment	2018-03-01 23:00:28.797233	{"time":1519945228,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945229,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945229,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945229,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945229,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945229,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/2b4b770e-6151-4b0d-b33d-90283bf893d0 (0) (canary)","index":1,"state":"finished","progress":100}\n		
13	done	2018-03-01 23:00:32.811827	create deployment	/deployments/shared_consumer_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/13	2018-03-01 23:00:31.917401	update_deployment	test	shared_consumer_deployment	2018-03-01 23:00:31.917153	{"time":1519945231,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945232,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945232,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945232,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945232,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945232,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/5b80ba4d-6ea1-42c1-96ff-fe2b1da60e9f (0) (canary)","index":1,"state":"finished","progress":100}\n		
10	done	2018-03-01 23:00:28.352658	retrieve vm-stats		/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/10	2018-03-01 23:00:28.280265	vms	test	explicit_deployment	2018-03-01 23:00:28.280027		{"vm_cid":"58717","vm_created_at":"2018-03-01T23:00:13Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.8"],"dns":["fc0cca03-efbe-4bbd-95d6-4932cbf48983.explicit-consumer-ig.a.explicit-deployment.bosh","0.explicit-consumer-ig.a.explicit-deployment.bosh"],"agent_id":"50fe7119-5a9f-47f5-8a83-78a0bd477b51","job_name":"explicit_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.6","user":"5.9","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"7"},"system":{"inode_percent":"0","percent":"7"}},"load":["2.19","2.31","2.13"],"mem":{"kb":"9621456","percent":"57"},"swap":{"kb":"133120","percent":"13"},"uptime":{"secs":289476}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"fc0cca03-efbe-4bbd-95d6-4932cbf48983","bootstrap":true,"ignore":false}\n{"vm_cid":"58708","vm_created_at":"2018-03-01T23:00:13Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.7"],"dns":["f70d45cb-7605-4900-b1c3-43f0d7e08d7a.explicit-provider-ig.a.explicit-deployment.bosh","0.explicit-provider-ig.a.explicit-deployment.bosh"],"agent_id":"d5c3890d-4622-43e5-a764-201d57a794a3","job_name":"explicit_provider_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.7","user":"6.7","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"7"},"system":{"inode_percent":"0","percent":"7"}},"load":["2.19","2.31","2.13"],"mem":{"kb":"9621456","percent":"57"},"swap":{"kb":"133120","percent":"13"},"uptime":{"secs":289476}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"f70d45cb-7605-4900-b1c3-43f0d7e08d7a","bootstrap":true,"ignore":false}\n	
12	done	2018-03-01 23:00:31.331506	create deployment	/deployments/shared_provider_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/12	2018-03-01 23:00:30.452413	update_deployment	test	shared_provider_deployment	2018-03-01 23:00:30.452134	{"time":1519945230,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945230,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945230,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945230,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945230,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945231,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0) (canary)","index":1,"state":"finished","progress":100}\n		
1	done	2018-03-01 22:59:19.687503	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/1	2018-03-01 22:59:18.316752	update_release	test	\N	2018-03-01 22:59:18.316191	{"time":1519945158,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"started","progress":0}\n{"time":1519945158,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"started","progress":0}\n{"time":1519945158,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"started","progress":0}\n{"time":1519945158,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e","index":2,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e","index":2,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"finished","progress":100}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"started","progress":0}\n{"time":1519945158,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c","index":10,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c","index":10,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5","index":13,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5","index":13,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/bade0800183844ade5a58a26ecfb4f22e4255d98","index":19,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/bade0800183844ade5a58a26ecfb4f22e4255d98","index":19,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"started","progress":0}\n{"time":1519945159,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"finished","progress":100}\n{"time":1519945159,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"started","progress":0}\n{"time":1519945159,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"finished","progress":100}\n		
2	done	2018-03-01 22:59:20.743423	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/2	2018-03-01 22:59:20.35936	update_stemcell	test	\N	2018-03-01 22:59:20.359094	{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"started","progress":0}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"finished","progress":100}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"started","progress":0}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"finished","progress":100}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"started","progress":0}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"finished","progress":100}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"started","progress":0}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"finished","progress":100}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"started","progress":0}\n{"time":1519945160,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"finished","progress":100}\n		
4	done	2018-03-01 22:59:37.866781	create deployment	/deployments/shared_provider_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/4	2018-03-01 22:59:30.442967	update_deployment	test	shared_provider_deployment	2018-03-01 22:59:30.442718	{"time":1519945170,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945170,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945170,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945170,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945170,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0)","index":1,"state":"started","progress":0}\n{"time":1519945171,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0)","index":1,"state":"finished","progress":100}\n{"time":1519945171,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945177,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/47ade923-b976-416c-851a-41e5860fc1ad (0) (canary)","index":1,"state":"finished","progress":100}\n		
7	done	2018-03-01 23:00:10.053125	create deployment	/deployments/implicit_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/7	2018-03-01 22:59:54.754939	update_deployment	test	implicit_deployment	2018-03-01 22:59:54.754692	{"time":1519945194,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945195,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945195,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945195,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945195,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0)","index":1,"state":"started","progress":0}\n{"time":1519945195,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0)","index":2,"state":"started","progress":0}\n{"time":1519945196,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0)","index":2,"state":"finished","progress":100}\n{"time":1519945197,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0)","index":1,"state":"finished","progress":100}\n{"time":1519945197,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945203,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1519945203,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945209,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0) (canary)","index":1,"state":"finished","progress":100}\n		
9	done	2018-03-01 23:00:27.690008	create deployment	/deployments/explicit_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/9	2018-03-01 23:00:12.183174	update_deployment	test	explicit_deployment	2018-03-01 23:00:12.182928	{"time":1519945212,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945212,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945212,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945212,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945212,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0)","index":1,"state":"started","progress":0}\n{"time":1519945212,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0)","index":2,"state":"started","progress":0}\n{"time":1519945213,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0)","index":1,"state":"finished","progress":100}\n{"time":1519945213,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0)","index":2,"state":"finished","progress":100}\n{"time":1519945213,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945221,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1519945221,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945227,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0) (canary)","index":1,"state":"finished","progress":100}\n		
14	done	2018-03-01 23:00:34.915139	create deployment	/deployments/implicit_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/14	2018-03-01 23:00:33.451915	update_deployment	test	implicit_deployment	2018-03-01 23:00:33.451674	{"time":1519945233,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945233,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945233,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945234,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945234,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945234,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/198d94db-e373-4f04-ba41-d0165461ce04 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1519945234,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945234,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/dee7701e-fdfb-4d41-b52c-f387acf6d047 (0) (canary)","index":1,"state":"finished","progress":100}\n		
15	done	2018-03-01 23:00:36.9447	create deployment	/deployments/explicit_deployment	/Users/pivotal/workspace/src/github.com/cloudfoundry/bosh/src/tmp/integration-tests-workspace/pid-57579/sandbox/boshdir/tasks/15	2018-03-01 23:00:35.498636	update_deployment	test	explicit_deployment	2018-03-01 23:00:35.498393	{"time":1519945235,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1519945235,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1519945236,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1519945236,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1519945236,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945236,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/f70d45cb-7605-4900-b1c3-43f0d7e08d7a (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1519945236,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1519945236,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/fc0cca03-efbe-4bbd-95d6-4932cbf48983 (0) (canary)","index":1,"state":"finished","progress":100}\n		
\.


--
-- Name: tasks_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tasks_new_id_seq', 15, true);


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

COPY templates (id, name, version, blobstore_id, sha1, package_names_json, release_id, logs_json, fingerprint, properties_json, consumes_json, provides_json, templates_json, spec_json) FROM stdin;
1	addon	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	9dd95240-144f-48ee-899e-12a061368560	d8b17f9597e0d95022d893548b084f0d8c2551c8	[]	1	\N	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	\N	\N	\N	\N	{"name":"addon","templates":{"config.yml.erb":"config.yml"},"packages":[],"consumes":[{"name":"db","type":"db"}],"properties":{}}
2	api_server	fd80d6fe55e4dfec8edfe258e1ba03c24146954e	7eea5c00-dbb8-44ac-9985-64f10f1797ef	79ca2b04742e191b7e2d833a1dfa8cb66863598d	["pkg_3_depends_on_2"]	1	\N	fd80d6fe55e4dfec8edfe258e1ba03c24146954e	\N	\N	\N	\N	{"name":"api_server","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}],"properties":{}}
3	api_server_with_bad_link_types	058b26819bd6561a75c2fed45ec49e671c9fbc6a	a3878896-c7b5-41c4-9671-7669319ec96b	3e42e652b8c5bd15c6058974bcb72f129917849c	["pkg_3_depends_on_2"]	1	\N	058b26819bd6561a75c2fed45ec49e671c9fbc6a	\N	\N	\N	\N	{"name":"api_server_with_bad_link_types","templates":{"config.yml.erb":"config.yml","somethingelse.yml.erb":"somethingelse.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"bad_link"},{"name":"backup_db","type":"bad_link_2"},{"name":"some_link_name","type":"bad_link_3"}],"properties":{}}
4	api_server_with_bad_optional_links	8a2485f1de3d99657e101fd269202c39cf3b5d73	3cb014a4-fcbc-4603-8200-cc0a5f67a7d0	7cc043bc437d397d9c5e6016a730998a7ed4fc8f	["pkg_3_depends_on_2"]	1	\N	8a2485f1de3d99657e101fd269202c39cf3b5d73	\N	\N	\N	\N	{"name":"api_server_with_bad_optional_links","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"optional_link_name","type":"optional_link_type","optional":true}],"properties":{}}
5	api_server_with_optional_db_link	00831c288b4a42454543ff69f71360634bd06b7b	36a96c2d-1f5f-424f-a974-780b04354e0d	df65510790c5e1676edda66d499ff3fbec729c6d	["pkg_3_depends_on_2"]	1	\N	00831c288b4a42454543ff69f71360634bd06b7b	\N	\N	\N	\N	{"name":"api_server_with_optional_db_link","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db","optional":true}],"properties":{}}
6	api_server_with_optional_links_1	0efc908dd04d84858e3cf8b75c326f35af5a5a98	5f0ddc9f-ed97-4f4d-8529-7199bf096a25	ad304e473e3adfcdd866f213d3b546d104325773	["pkg_3_depends_on_2"]	1	\N	0efc908dd04d84858e3cf8b75c326f35af5a5a98	\N	\N	\N	\N	{"name":"api_server_with_optional_links_1","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"},{"name":"optional_link_name","type":"optional_link_type","optional":true}],"properties":{}}
7	api_server_with_optional_links_2	15f815868a057180e21dbac61629f73ad3558fec	62beb954-eaca-4aae-8ff8-fe601fdfdd2a	f6a807ede43e1bf3c7fd92616a7dd76e7e60cd5a	["pkg_3_depends_on_2"]	1	\N	15f815868a057180e21dbac61629f73ad3558fec	\N	\N	\N	\N	{"name":"api_server_with_optional_links_2","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db","optional":true}],"properties":{}}
8	app_server	58e364fb74a01a1358475fc1da2ad905b78b4487	664c2637-b002-441a-a1d8-e9efd567b8fb	0c52b03a6897437c1360f33bbb8b817500ea1a8b	[]	1	\N	58e364fb74a01a1358475fc1da2ad905b78b4487	\N	\N	\N	\N	{"name":"app_server","description":null,"templates":{"config.yml.erb":"config.yml"},"properties":{}}
9	backup_database	822933af7d854849051ca16539653158ad233e5e	5929d149-1993-48c2-acf9-6e88cf853cfa	8cd5454cbdc8b58da126b3ac65c2d1509f0ba749	[]	1	\N	822933af7d854849051ca16539653158ad233e5e	\N	\N	\N	\N	{"name":"backup_database","templates":{},"packages":[],"provides":[{"name":"backup_db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"backup_bar"}}}
10	consumer	9bed4913876cf51ae1a0ee4b561083711c19bf5c	80e82620-9d96-4500-bbc0-ffb8a49f54b0	a090beb200afae6f43bc144b775b0f3f1777e94b	[]	1	\N	9bed4913876cf51ae1a0ee4b561083711c19bf5c	\N	\N	\N	\N	{"name":"consumer","templates":{"config.yml.erb":"config.yml"},"consumes":[{"name":"provider","type":"provider"}],"properties":{}}
11	database	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	0944bdef-94bd-4898-8d58-8ebdb9c2b6a4	bc67ab94a59685e6145e0ed8df557af10f1eab03	[]	1	\N	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	\N	\N	\N	\N	{"name":"database","templates":{},"packages":[],"provides":[{"name":"db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"normal_bar"},"test":{"description":"test property","default":"default test property"}}}
12	database_with_two_provided_link_of_same_type	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	af2eccf6-a8c3-4bbd-8623-ae2a4167348e	7d6aee3b37f3fea23c5a93bec584663e2b4939dc	[]	1	\N	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	\N	\N	\N	\N	{"name":"database_with_two_provided_link_of_same_type","templates":{},"packages":[],"provides":[{"name":"db1","type":"db"},{"name":"db2","type":"db"}],"properties":{"test":{"description":"test property","default":"default test property"}}}
13	errand_with_links	9a52f02643a46dda217689182e5fa3b57822ced5	88f11bf8-ead2-410e-bdf9-38e30f2d59b7	d64a1192d321db3c05751ecb896afebab71ee3fa	[]	1	\N	9a52f02643a46dda217689182e5fa3b57822ced5	\N	\N	\N	\N	{"name":"errand_with_links","templates":{"config.yml.erb":"config.yml","run.erb":"bin/run"},"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}],"properties":{}}
14	http_endpoint_provider_with_property_types	30978e9fd0d29e52fe0369262e11fbcea1283889	e58e0c1a-af14-46d4-9abe-7bdcf5da8fb2	f02067fcd15c02d5ab519a6300955808319ce996	[]	1	\N	30978e9fd0d29e52fe0369262e11fbcea1283889	\N	\N	\N	\N	{"name":"http_endpoint_provider_with_property_types","description":"This job runs an HTTP server and with a provides link directive. It has properties with types.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"Has a type password and no default value","type":"password"}}}
15	http_proxy_with_requires	760680c4a796a2ffca24026c561c06dd5bdef6b3	5bee7924-460e-43b0-9363-2dd5ced1ae42	0008b7901cc5b06a93b6bb97b8b42742863aaae3	[]	1	\N	760680c4a796a2ffca24026c561c06dd5bdef6b3	\N	\N	\N	\N	{"name":"http_proxy_with_requires","description":"This job runs an HTTP proxy and uses a link to find its backend.","templates":{"ctl.sh":"bin/ctl","config.yml.erb":"config/config.yml","props.json":"config/props.json","pre-start.erb":"bin/pre-start"},"consumes":[{"name":"proxied_http_endpoint","type":"http_endpoint"},{"name":"logs_http_endpoint","type":"http_endpoint2","optional":true}],"properties":{"http_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"http_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"http_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"http_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"http_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}}
16	http_server_with_provides	64244f12f2db2e7d93ccfbc13be744df87013389	f78efeec-34f3-4e30-a6c2-0c48f485443a	74336842d690701845fc81adeb666f3fe71e6351	[]	1	\N	64244f12f2db2e7d93ccfbc13be744df87013389	\N	\N	\N	\N	{"name":"http_server_with_provides","description":"This job runs an HTTP server and with a provides link directive.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}}
17	kv_http_server	044ec02730e6d068ecf88a0d37fe48937687bdba	6c5a9beb-da38-4419-bfe9-0578c7cf9206	d3070cafb780e06c3d10bdfd649d3abfcd4c4e90	[]	1	\N	044ec02730e6d068ecf88a0d37fe48937687bdba	\N	\N	\N	\N	{"name":"kv_http_server","description":"This job can run as a cluster.","templates":{"ctl.sh":"bin/ctl"},"consumes":[{"name":"kv_http_server","type":"kv_http_server"}],"provides":[{"name":"kv_http_server","type":"kv_http_server"}],"properties":{"kv_http_server.listen_port":{"description":"Port to listen on","default":8080}}}
18	mongo_db	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	da3355da-aa7d-456e-a5d0-ad91b2a53636	5c40f85b572e65424599ec1889cb3b2dc7acdf1a	["pkg_1"]	1	\N	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	\N	\N	\N	\N	{"name":"mongo_db","templates":{},"packages":["pkg_1"],"provides":[{"name":"read_only_db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"mongo_foo_db"}}}
19	node	bade0800183844ade5a58a26ecfb4f22e4255d98	864798aa-b419-4f8e-be26-5a451fbee630	0fe80c6b74483291e9bfa873a7eb4e6d17b54e38	[]	1	\N	bade0800183844ade5a58a26ecfb4f22e4255d98	\N	\N	\N	\N	{"name":"node","templates":{"config.yml.erb":"config.yml"},"packages":[],"provides":[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}],"consumes":[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}],"properties":{}}
20	provider	e1ff4ff9a6304e1222484570a400788c55154b1c	581c8599-cee0-45cf-8842-0c3ad3830b3a	17010b2542712398e4fbb0da44dca70220f3a097	[]	1	\N	e1ff4ff9a6304e1222484570a400788c55154b1c	\N	\N	\N	\N	{"name":"provider","templates":{},"provides":[{"name":"provider","type":"provider","properties":["a","b","c"]}],"properties":{"a":{"description":"description for a","default":"default_a"},"b":{"description":"description for b"},"c":{"description":"description for c","default":"default_c"}}}
21	provider_fail	314c385e96711cb5d56dd909a086563dae61bc37	18dd53c7-f40e-475c-bd58-ac8f1d7b1ba4	4b097c349353641603cfa570e157a9a7977c3333	[]	1	\N	314c385e96711cb5d56dd909a086563dae61bc37	\N	\N	\N	\N	{"name":"provider_fail","templates":{},"provides":[{"name":"provider_fail","type":"provider","properties":["a","b","c"]}],"properties":{"a":{"description":"description for a","default":"default_a"},"c":{"description":"description for c","default":"default_c"}}}
22	tcp_proxy_with_requires	e60ea353cdd24b6997efdedab144431c0180645b	6f25b35a-b730-41fe-bcd5-082c63c2e180	5107a845ebf4dfb8788a16d86b32537ee58c5450	[]	1	\N	e60ea353cdd24b6997efdedab144431c0180645b	\N	\N	\N	\N	{"name":"tcp_proxy_with_requires","description":"This job runs an HTTP proxy and uses a link to find its backend.","templates":{"ctl.sh":"bin/ctl","config.yml.erb":"config/config.yml","props.json":"config/props.json","pre-start.erb":"bin/pre-start"},"consumes":[{"name":"proxied_http_endpoint","type":"http_endpoint"}],"properties":{"tcp_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"tcp_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"tcp_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"tcp_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"tcp_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}}
23	tcp_server_with_provides	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	b50032d1-c4e6-4728-8ce1-91f23780e55b	df743013a6a58a8816871ef08435c9c76d5385b9	[]	1	\N	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	\N	\N	\N	\N	{"name":"tcp_server_with_provides","description":"This job runs an HTTP server and with a provides link directive.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}}
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('templates_id_seq', 23, true);


--
-- Data for Name: variable_sets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY variable_sets (id, deployment_id, created_at, deployed_successfully, writable) FROM stdin;
1	1	2018-03-01 22:59:21.888166	t	f
2	2	2018-03-01 22:59:30.497013	t	f
3	3	2018-03-01 22:59:38.887593	t	f
4	4	2018-03-01 22:59:54.809877	t	f
5	5	2018-03-01 23:00:12.23703	t	f
\.


--
-- Name: variable_sets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('variable_sets_id_seq', 5, true);


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

COPY vms (id, instance_id, agent_id, cid, trusted_certs_sha1, active, cpi, created_at) FROM stdin;
\.


--
-- Name: vms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vms_id_seq', 9, true);


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
-- Name: configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY configs
    ADD CONSTRAINT configs_pkey PRIMARY KEY (id);


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
-- Name: deployment_id_config_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deployments_configs
    ADD CONSTRAINT deployment_id_config_id_unique UNIQUE (deployment_id, config_id);


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
-- Name: ip_addresses_address_temp_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_address_temp_key UNIQUE (address_str);


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
-- Name: local_dns_encoded_azs_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_encoded_azs
    ADD CONSTRAINT local_dns_encoded_azs_name_key UNIQUE (name);


--
-- Name: local_dns_encoded_azs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_encoded_azs
    ADD CONSTRAINT local_dns_encoded_azs_pkey PRIMARY KEY (id);


--
-- Name: local_dns_encoded_instance_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_encoded_instance_groups
    ADD CONSTRAINT local_dns_encoded_instance_groups_pkey PRIMARY KEY (id);


--
-- Name: local_dns_encoded_networks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_encoded_networks
    ADD CONSTRAINT local_dns_encoded_networks_name_key UNIQUE (name);


--
-- Name: local_dns_encoded_networks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY local_dns_encoded_networks
    ADD CONSTRAINT local_dns_encoded_networks_pkey PRIMARY KEY (id);


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
-- Name: ip_addresses_address_str_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX ip_addresses_address_str_index ON ip_addresses USING btree (address_str);


--
-- Name: local_dns_encoded_instance_groups_name_deployment_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX local_dns_encoded_instance_groups_name_deployment_id_index ON local_dns_encoded_instance_groups USING btree (name, deployment_id);


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
-- Name: deployments_configs_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_configs
    ADD CONSTRAINT deployments_configs_config_id_fkey FOREIGN KEY (config_id) REFERENCES configs(id) ON DELETE CASCADE;


--
-- Name: deployments_configs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deployments_configs
    ADD CONSTRAINT deployments_configs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


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
-- Name: errand_runs_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY errand_runs
    ADD CONSTRAINT errand_runs_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


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
-- Name: local_dns_encoded_instance_groups_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY local_dns_encoded_instance_groups
    ADD CONSTRAINT local_dns_encoded_instance_groups_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES deployments(id) ON DELETE CASCADE;


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
-- Name: variable_table_variable_set_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY variables
    ADD CONSTRAINT variable_table_variable_set_fkey FOREIGN KEY (variable_set_id) REFERENCES variable_sets(id) ON DELETE CASCADE;


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

