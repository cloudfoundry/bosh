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
1	4eaa6802-a145-4142-7f62-9e3fb6af5f80	63f7a398490b060d30a22087504af1df31f2c25a	[]	1	2	97d170e1550eee4afc0af065b78cda302a97674c	toronto-os	1
2	492c1178-a32d-475f-7d5f-91199bbd3f06	35cc6e6ea5e0a7fda25a8e5785d0db4b479e8d33	[["pkg_2","fa48497a19f12e925b32fcb8f5ca2b42144e4444"]]	1	3	b048798b462817f4ae6a5345dd9a0c45d1a1c8ea	toronto-os	1
\.


--
-- Name: compiled_packages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('compiled_packages_id_seq', 2, true);


--
-- Data for Name: configs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY configs (id, name, type, content, created_at, deleted) FROM stdin;
1	default	cloud	azs:\n- name: z1\ncompilation:\n  az: z1\n  cloud_properties: {}\n  network: a\n  workers: 1\nnetworks:\n- name: a\n  subnets:\n  - az: z1\n    cloud_properties: {}\n    dns:\n    - 192.168.1.1\n    - 192.168.1.2\n    gateway: 192.168.1.1\n    range: 192.168.1.0/24\n    reserved: []\n    static:\n    - 192.168.1.10\n    - 192.168.1.11\n    - 192.168.1.12\n    - 192.168.1.13\n- name: dynamic-network\n  subnets:\n  - az: z1\n  type: dynamic\nvm_types:\n- cloud_properties: {}\n  name: a\n	2018-03-16 15:42:38.273117	f
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

SELECT pg_catalog.setval('delayed_jobs_id_seq', 21, true);


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
3	shared_consumer_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_consumer_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
4	implicit_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n  name: implicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: api_server\n  name: implicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: implicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
7	shared_deployment_with_errand	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n      db:\n        deployment: shared_provider_deployment\n        from: my_shared_db\n    name: api_server\n  name: shared_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_deployment_with_errand\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{"shared_provider_ig":{"database":{"my_shared_db":{"db":{"deployment_name":"shared_deployment_with_errand","domain":"bosh","default_network":"a","networks":["a"],"instance_group":"shared_provider_ig","properties":{"foo":"normal_bar"},"instances":[{"name":"shared_provider_ig","id":"b41a9abd-5711-4647-ade8-6d1eec942780","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.14","addresses":{"a":"192.168.1.14"},"dns_addresses":{"a":"192.168.1.14"}}]}}}}}
1	errand_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  name: errand_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: errand_with_links\n  lifecycle: errand\n  name: errand_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
5	explicit_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: backup_database\n    provides:\n      backup_db:\n        as: explicit_db\n  name: explicit_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - consumes:\n      backup_db:\n        from: explicit_db\n      db:\n        from: explicit_db\n    name: api_server\n  name: explicit_consumer_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: explicit_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
6	colocated_errand_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n  - name: errand_with_links\n  name: errand_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: colocated_errand_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{}
2	shared_provider_deployment	---\ndirector_uuid: deadbeef\ninstance_groups:\n- azs:\n  - z1\n  instances: 1\n  jobs:\n  - name: database\n    provides:\n      db:\n        as: my_shared_db\n        shared: true\n  name: shared_provider_ig\n  networks:\n  - name: a\n  properties: {}\n  stemcell: default\n  vm_type: a\nname: shared_provider_deployment\nreleases:\n- name: bosh-release\n  version: 0.1-dev\nstemcells:\n- alias: default\n  name: ubuntu-stemcell\n  version: '1'\nupdate:\n  canaries: 2\n  canary_watch_time: 4000\n  max_in_flight: 1\n  update_watch_time: 20\n	{"shared_provider_ig":{"database":{"my_shared_db":{"db":{"deployment_name":"shared_provider_deployment","domain":"bosh","default_network":"a","networks":["a"],"instance_group":"shared_provider_ig","properties":{"foo":"normal_bar"},"instances":[{"name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3","addresses":{"a":"192.168.1.3"},"dns_addresses":{"a":"192.168.1.3"}}]}}}}}
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
6	1
7	1
\.


--
-- Name: deployments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_id_seq', 7, true);


--
-- Data for Name: deployments_release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_release_versions (id, release_version_id, deployment_id) FROM stdin;
1	1	1
2	1	2
3	1	3
4	1	4
5	1	5
6	1	6
7	1	7
\.


--
-- Name: deployments_release_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_release_versions_id_seq', 7, true);


--
-- Data for Name: deployments_stemcells; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY deployments_stemcells (id, deployment_id, stemcell_id) FROM stdin;
1	1	1
2	2	1
3	3	1
4	4	1
5	5	1
6	6	1
7	7	1
\.


--
-- Name: deployments_stemcells_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deployments_stemcells_id_seq', 7, true);


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
1	\N	_director	2018-03-16 15:42:34.631015	start	worker	worker_0	\N	\N	\N	\N	{}
2	\N	_director	2018-03-16 15:42:34.647258	start	worker	worker_1	\N	\N	\N	\N	{}
3	\N	_director	2018-03-16 15:42:34.655069	start	director	deadbeef	\N	\N	\N	\N	{"version":"0.0.0"}
4	\N	_director	2018-03-16 15:42:34.655447	start	worker	worker_2	\N	\N	\N	\N	{}
5	\N	test	2018-03-16 15:42:35.759001	acquire	lock	lock:release:bosh-release	\N	1	\N	\N	{}
6	\N	test	2018-03-16 15:42:36.863064	release	lock	lock:release:bosh-release	\N	1	\N	\N	{}
7	\N	test	2018-03-16 15:42:38.274478	update	cloud-config	default	\N	\N	\N	\N	{}
8	\N	test	2018-03-16 15:42:38.759461	create	deployment	errand_deployment	\N	3	errand_deployment	\N	{}
9	\N	test	2018-03-16 15:42:38.770861	acquire	lock	lock:deployment:errand_deployment	\N	3	errand_deployment	\N	{}
10	\N	test	2018-03-16 15:42:38.873486	acquire	lock	lock:release:bosh-release	\N	3	\N	\N	{}
11	\N	test	2018-03-16 15:42:38.885419	release	lock	lock:release:bosh-release	\N	3	\N	\N	{}
12	\N	test	2018-03-16 15:42:39.065916	create	vm	\N	\N	3	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
13	12	test	2018-03-16 15:42:40.493518	create	vm	41838	\N	3	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
14	\N	test	2018-03-16 15:42:41.784974	create	instance	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	\N	3	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{"az":"z1"}
15	14	test	2018-03-16 15:42:47.996354	create	instance	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	\N	3	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
16	8	test	2018-03-16 15:42:48.026162	create	deployment	errand_deployment	\N	3	errand_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
17	\N	test	2018-03-16 15:42:48.031275	release	lock	lock:deployment:errand_deployment	\N	3	errand_deployment	\N	{}
18	\N	test	2018-03-16 15:42:49.113591	create	deployment	shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
19	\N	test	2018-03-16 15:42:49.125145	acquire	lock	lock:deployment:shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
20	\N	test	2018-03-16 15:42:49.201623	acquire	lock	lock:release:bosh-release	\N	4	\N	\N	{}
21	\N	test	2018-03-16 15:42:49.21254	release	lock	lock:release:bosh-release	\N	4	\N	\N	{}
22	\N	test	2018-03-16 15:42:49.364021	create	vm	\N	\N	4	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
23	22	test	2018-03-16 15:42:49.811826	create	vm	41861	\N	4	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
24	\N	test	2018-03-16 15:42:51.117298	create	instance	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	\N	4	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{"az":"z1"}
25	24	test	2018-03-16 15:42:58.342223	create	instance	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	\N	4	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
26	18	test	2018-03-16 15:42:58.368702	create	deployment	shared_provider_deployment	\N	4	shared_provider_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
27	\N	test	2018-03-16 15:42:58.374192	release	lock	lock:deployment:shared_provider_deployment	\N	4	shared_provider_deployment	\N	{}
28	\N	test	2018-03-16 15:42:59.227645	create	deployment	shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
29	\N	test	2018-03-16 15:42:59.23986	acquire	lock	lock:deployment:shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
30	\N	test	2018-03-16 15:42:59.329542	acquire	lock	lock:release:bosh-release	\N	5	\N	\N	{}
31	\N	test	2018-03-16 15:42:59.341776	release	lock	lock:release:bosh-release	\N	5	\N	\N	{}
32	\N	test	2018-03-16 15:42:59.49803	acquire	lock	lock:compile:2:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
33	\N	test	2018-03-16 15:42:59.519834	create	instance	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
34	\N	test	2018-03-16 15:42:59.554781	create	vm	\N	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
35	34	test	2018-03-16 15:42:59.823689	create	vm	41885	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
36	33	test	2018-03-16 15:43:01.067165	create	instance	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
37	\N	test	2018-03-16 15:43:02.252641	delete	instance	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
38	\N	test	2018-03-16 15:43:02.262253	delete	vm	41885	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
39	38	test	2018-03-16 15:43:02.445009	delete	vm	41885	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
40	37	test	2018-03-16 15:43:02.462901	delete	instance	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	\N	5	shared_consumer_deployment	compilation-e9f2b5f2-c7bc-4564-9cd8-29ad6f8f0b5a/210f2189-26c6-487c-a060-0d57c705b5c7	{}
41	\N	test	2018-03-16 15:43:02.483691	release	lock	lock:compile:2:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
42	\N	test	2018-03-16 15:43:02.510538	acquire	lock	lock:compile:3:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
43	\N	test	2018-03-16 15:43:02.527481	create	instance	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
44	\N	test	2018-03-16 15:43:02.561441	create	vm	\N	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
45	44	test	2018-03-16 15:43:02.935635	create	vm	41903	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
46	43	test	2018-03-16 15:43:04.153901	create	instance	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
47	\N	test	2018-03-16 15:43:05.340698	delete	instance	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
48	\N	test	2018-03-16 15:43:05.350168	delete	vm	41903	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
49	48	test	2018-03-16 15:43:05.524501	delete	vm	41903	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
50	47	test	2018-03-16 15:43:05.542011	delete	instance	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	\N	5	shared_consumer_deployment	compilation-89dc3588-fc7d-43c6-b512-d864510302ad/d1248df0-733f-4a10-b416-2c3916e695ef	{}
51	\N	test	2018-03-16 15:43:05.567836	release	lock	lock:compile:3:toronto-os/1	\N	5	shared_consumer_deployment	\N	{}
52	\N	test	2018-03-16 15:43:05.660949	create	vm	\N	\N	5	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
53	52	test	2018-03-16 15:43:06.224737	create	vm	41922	\N	5	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
54	\N	test	2018-03-16 15:43:07.556117	create	instance	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	\N	5	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{"az":"z1"}
55	54	test	2018-03-16 15:43:14.758135	create	instance	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	\N	5	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
56	28	test	2018-03-16 15:43:14.787073	create	deployment	shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
57	\N	test	2018-03-16 15:43:14.792058	release	lock	lock:deployment:shared_consumer_deployment	\N	5	shared_consumer_deployment	\N	{}
58	\N	test	2018-03-16 15:43:16.591282	create	deployment	implicit_deployment	\N	7	implicit_deployment	\N	{}
59	\N	test	2018-03-16 15:43:16.603633	acquire	lock	lock:deployment:implicit_deployment	\N	7	implicit_deployment	\N	{}
60	\N	test	2018-03-16 15:43:16.689045	acquire	lock	lock:release:bosh-release	\N	7	\N	\N	{}
61	\N	test	2018-03-16 15:43:16.700772	release	lock	lock:release:bosh-release	\N	7	\N	\N	{}
62	\N	test	2018-03-16 15:43:16.94765	create	vm	\N	\N	7	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
63	\N	test	2018-03-16 15:43:16.953339	create	vm	\N	\N	7	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
64	63	test	2018-03-16 15:43:17.394288	create	vm	41958	\N	7	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
65	62	test	2018-03-16 15:43:17.410954	create	vm	41959	\N	7	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
66	\N	test	2018-03-16 15:43:17.796501	create	instance	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	\N	7	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{"az":"z1"}
67	66	test	2018-03-16 15:43:24.04014	create	instance	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	\N	7	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
68	\N	test	2018-03-16 15:43:24.071765	create	instance	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	\N	7	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{"az":"z1"}
69	68	test	2018-03-16 15:43:30.272351	create	instance	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	\N	7	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
70	58	test	2018-03-16 15:43:30.29705	create	deployment	implicit_deployment	\N	7	implicit_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
71	\N	test	2018-03-16 15:43:30.301952	release	lock	lock:deployment:implicit_deployment	\N	7	implicit_deployment	\N	{}
72	\N	test	2018-03-16 15:43:31.680969	create	deployment	explicit_deployment	\N	9	explicit_deployment	\N	{}
73	\N	test	2018-03-16 15:43:31.69374	acquire	lock	lock:deployment:explicit_deployment	\N	9	explicit_deployment	\N	{}
74	\N	test	2018-03-16 15:43:31.790531	acquire	lock	lock:release:bosh-release	\N	9	\N	\N	{}
75	\N	test	2018-03-16 15:43:31.802104	release	lock	lock:release:bosh-release	\N	9	\N	\N	{}
76	\N	test	2018-03-16 15:43:32.05049	create	vm	\N	\N	9	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
77	\N	test	2018-03-16 15:43:32.05688	create	vm	\N	\N	9	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
78	77	test	2018-03-16 15:43:32.436208	create	vm	42003	\N	9	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
79	76	test	2018-03-16 15:43:32.678068	create	vm	42010	\N	9	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
80	\N	test	2018-03-16 15:43:33.02014	create	instance	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	\N	9	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{"az":"z1"}
81	80	test	2018-03-16 15:43:39.239405	create	instance	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	\N	9	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
82	\N	test	2018-03-16 15:43:39.272427	create	instance	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	\N	9	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{"az":"z1"}
83	82	test	2018-03-16 15:43:45.466757	create	instance	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	\N	9	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
84	72	test	2018-03-16 15:43:45.490243	create	deployment	explicit_deployment	\N	9	explicit_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
85	\N	test	2018-03-16 15:43:45.495171	release	lock	lock:deployment:explicit_deployment	\N	9	explicit_deployment	\N	{}
86	\N	test	2018-03-16 15:43:47.441295	create	deployment	colocated_errand_deployment	\N	11	colocated_errand_deployment	\N	{}
87	\N	test	2018-03-16 15:43:47.459589	acquire	lock	lock:deployment:colocated_errand_deployment	\N	11	colocated_errand_deployment	\N	{}
88	\N	test	2018-03-16 15:43:47.549688	acquire	lock	lock:release:bosh-release	\N	11	\N	\N	{}
89	\N	test	2018-03-16 15:43:47.562948	release	lock	lock:release:bosh-release	\N	11	\N	\N	{}
90	\N	test	2018-03-16 15:43:47.739879	create	vm	\N	\N	11	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
91	90	test	2018-03-16 15:43:48.340922	create	vm	42050	\N	11	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
92	\N	test	2018-03-16 15:43:49.677976	create	instance	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	\N	11	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{"az":"z1"}
93	92	test	2018-03-16 15:43:55.923095	create	instance	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	\N	11	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
94	86	test	2018-03-16 15:43:55.960488	create	deployment	colocated_errand_deployment	\N	11	colocated_errand_deployment	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
95	\N	test	2018-03-16 15:43:55.967192	release	lock	lock:deployment:colocated_errand_deployment	\N	11	colocated_errand_deployment	\N	{}
96	\N	test	2018-03-16 15:43:57.595976	create	deployment	shared_deployment_with_errand	\N	13	shared_deployment_with_errand	\N	{}
97	\N	test	2018-03-16 15:43:57.608987	acquire	lock	lock:deployment:shared_deployment_with_errand	\N	13	shared_deployment_with_errand	\N	{}
98	\N	test	2018-03-16 15:43:57.716531	acquire	lock	lock:release:bosh-release	\N	13	\N	\N	{}
99	\N	test	2018-03-16 15:43:57.728243	release	lock	lock:release:bosh-release	\N	13	\N	\N	{}
100	\N	test	2018-03-16 15:43:58.026792	create	vm	\N	\N	13	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
101	\N	test	2018-03-16 15:43:58.028834	create	vm	\N	\N	13	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
102	101	test	2018-03-16 15:43:58.273005	create	vm	42087	\N	13	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
103	100	test	2018-03-16 15:43:58.925192	create	vm	42094	\N	13	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
104	\N	test	2018-03-16 15:44:00.270486	create	instance	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	\N	13	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{"az":"z1"}
105	104	test	2018-03-16 15:44:06.474678	create	instance	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	\N	13	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
106	\N	test	2018-03-16 15:44:06.506821	create	instance	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	\N	13	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{"az":"z1"}
107	106	test	2018-03-16 15:44:12.713722	create	instance	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	\N	13	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
108	96	test	2018-03-16 15:44:12.743887	create	deployment	shared_deployment_with_errand	\N	13	shared_deployment_with_errand	\N	{"before":{},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
109	\N	test	2018-03-16 15:44:12.749222	release	lock	lock:deployment:shared_deployment_with_errand	\N	13	shared_deployment_with_errand	\N	{}
110	\N	test	2018-03-16 15:44:14.947539	update	deployment	errand_deployment	\N	15	errand_deployment	\N	{}
111	\N	test	2018-03-16 15:44:14.96025	acquire	lock	lock:deployment:errand_deployment	\N	15	errand_deployment	\N	{}
112	\N	test	2018-03-16 15:44:15.041774	acquire	lock	lock:release:bosh-release	\N	15	\N	\N	{}
113	\N	test	2018-03-16 15:44:15.049614	release	lock	lock:release:bosh-release	\N	15	\N	\N	{}
114	\N	test	2018-03-16 15:44:15.287887	stop	instance	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	\N	15	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
115	\N	test	2018-03-16 15:44:15.344789	delete	vm	41838	\N	15	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
116	115	test	2018-03-16 15:44:15.51723	delete	vm	41838	\N	15	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
117	114	test	2018-03-16 15:44:15.571808	stop	instance	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	\N	15	errand_deployment	errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988	{}
118	110	test	2018-03-16 15:44:15.5976	update	deployment	errand_deployment	\N	15	errand_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
119	\N	test	2018-03-16 15:44:15.60308	release	lock	lock:deployment:errand_deployment	\N	15	errand_deployment	\N	{}
120	\N	test	2018-03-16 15:44:16.0483	update	deployment	shared_provider_deployment	\N	16	shared_provider_deployment	\N	{}
121	\N	test	2018-03-16 15:44:16.060177	acquire	lock	lock:deployment:shared_provider_deployment	\N	16	shared_provider_deployment	\N	{}
122	\N	test	2018-03-16 15:44:16.137535	acquire	lock	lock:release:bosh-release	\N	16	\N	\N	{}
123	\N	test	2018-03-16 15:44:16.145327	release	lock	lock:release:bosh-release	\N	16	\N	\N	{}
124	\N	test	2018-03-16 15:44:16.322254	stop	instance	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	\N	16	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
125	\N	test	2018-03-16 15:44:16.376512	delete	vm	41861	\N	16	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
126	125	test	2018-03-16 15:44:16.54901	delete	vm	41861	\N	16	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
127	124	test	2018-03-16 15:44:16.611286	stop	instance	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	\N	16	shared_provider_deployment	shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1	{}
128	120	test	2018-03-16 15:44:16.6314	update	deployment	shared_provider_deployment	\N	16	shared_provider_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
129	\N	test	2018-03-16 15:44:16.636642	release	lock	lock:deployment:shared_provider_deployment	\N	16	shared_provider_deployment	\N	{}
130	\N	test	2018-03-16 15:44:17.241036	update	deployment	shared_consumer_deployment	\N	17	shared_consumer_deployment	\N	{}
131	\N	test	2018-03-16 15:44:17.252388	acquire	lock	lock:deployment:shared_consumer_deployment	\N	17	shared_consumer_deployment	\N	{}
132	\N	test	2018-03-16 15:44:17.329079	acquire	lock	lock:release:bosh-release	\N	17	\N	\N	{}
133	\N	test	2018-03-16 15:44:17.33934	release	lock	lock:release:bosh-release	\N	17	\N	\N	{}
134	\N	test	2018-03-16 15:44:17.525614	stop	instance	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	\N	17	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
135	\N	test	2018-03-16 15:44:17.575456	delete	vm	41922	\N	17	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
136	135	test	2018-03-16 15:44:17.746499	delete	vm	41922	\N	17	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
137	134	test	2018-03-16 15:44:17.800708	stop	instance	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	\N	17	shared_consumer_deployment	shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4	{}
138	130	test	2018-03-16 15:44:17.821016	update	deployment	shared_consumer_deployment	\N	17	shared_consumer_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
139	\N	test	2018-03-16 15:44:17.826348	release	lock	lock:deployment:shared_consumer_deployment	\N	17	shared_consumer_deployment	\N	{}
140	\N	test	2018-03-16 15:44:18.743128	update	deployment	implicit_deployment	\N	18	implicit_deployment	\N	{}
141	\N	test	2018-03-16 15:44:18.755832	acquire	lock	lock:deployment:implicit_deployment	\N	18	implicit_deployment	\N	{}
142	\N	test	2018-03-16 15:44:18.839426	acquire	lock	lock:release:bosh-release	\N	18	\N	\N	{}
143	\N	test	2018-03-16 15:44:18.849269	release	lock	lock:release:bosh-release	\N	18	\N	\N	{}
144	\N	test	2018-03-16 15:44:19.112824	stop	instance	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	\N	18	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
145	\N	test	2018-03-16 15:44:19.164029	delete	vm	41959	\N	18	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
146	145	test	2018-03-16 15:44:19.336133	delete	vm	41959	\N	18	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
147	144	test	2018-03-16 15:44:19.390312	stop	instance	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	\N	18	implicit_deployment	implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967	{}
148	\N	test	2018-03-16 15:44:19.426154	stop	instance	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	\N	18	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
149	\N	test	2018-03-16 15:44:19.475421	delete	vm	41958	\N	18	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
150	149	test	2018-03-16 15:44:19.64026	delete	vm	41958	\N	18	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
151	148	test	2018-03-16 15:44:19.694441	stop	instance	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	\N	18	implicit_deployment	implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498	{}
152	140	test	2018-03-16 15:44:19.715382	update	deployment	implicit_deployment	\N	18	implicit_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
153	\N	test	2018-03-16 15:44:19.721231	release	lock	lock:deployment:implicit_deployment	\N	18	implicit_deployment	\N	{}
154	\N	test	2018-03-16 15:44:19.973367	update	deployment	explicit_deployment	\N	19	explicit_deployment	\N	{}
155	\N	test	2018-03-16 15:44:19.992586	acquire	lock	lock:deployment:explicit_deployment	\N	19	explicit_deployment	\N	{}
156	\N	test	2018-03-16 15:44:20.076461	acquire	lock	lock:release:bosh-release	\N	19	\N	\N	{}
157	\N	test	2018-03-16 15:44:20.085913	release	lock	lock:release:bosh-release	\N	19	\N	\N	{}
158	\N	test	2018-03-16 15:44:20.346761	stop	instance	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	\N	19	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
159	\N	test	2018-03-16 15:44:20.397628	delete	vm	42010	\N	19	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
160	159	test	2018-03-16 15:44:20.564414	delete	vm	42010	\N	19	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
161	158	test	2018-03-16 15:44:20.628025	stop	instance	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	\N	19	explicit_deployment	explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547	{}
162	\N	test	2018-03-16 15:44:20.661523	stop	instance	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	\N	19	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
163	\N	test	2018-03-16 15:44:20.707922	delete	vm	42003	\N	19	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
164	163	test	2018-03-16 15:44:20.872515	delete	vm	42003	\N	19	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
165	162	test	2018-03-16 15:44:20.922659	stop	instance	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	\N	19	explicit_deployment	explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7	{}
166	154	test	2018-03-16 15:44:20.944341	update	deployment	explicit_deployment	\N	19	explicit_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
167	\N	test	2018-03-16 15:44:20.950351	release	lock	lock:deployment:explicit_deployment	\N	19	explicit_deployment	\N	{}
168	\N	test	2018-03-16 15:44:21.789696	update	deployment	colocated_errand_deployment	\N	20	colocated_errand_deployment	\N	{}
169	\N	test	2018-03-16 15:44:21.80198	acquire	lock	lock:deployment:colocated_errand_deployment	\N	20	colocated_errand_deployment	\N	{}
170	\N	test	2018-03-16 15:44:21.881412	acquire	lock	lock:release:bosh-release	\N	20	\N	\N	{}
171	\N	test	2018-03-16 15:44:21.889158	release	lock	lock:release:bosh-release	\N	20	\N	\N	{}
172	\N	test	2018-03-16 15:44:22.089454	stop	instance	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	\N	20	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
173	\N	test	2018-03-16 15:44:22.148387	delete	vm	42050	\N	20	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
174	173	test	2018-03-16 15:44:22.316785	delete	vm	42050	\N	20	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
175	172	test	2018-03-16 15:44:22.393853	stop	instance	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	\N	20	colocated_errand_deployment	errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	{}
176	168	test	2018-03-16 15:44:22.413814	update	deployment	colocated_errand_deployment	\N	20	colocated_errand_deployment	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
177	\N	test	2018-03-16 15:44:22.419786	release	lock	lock:deployment:colocated_errand_deployment	\N	20	colocated_errand_deployment	\N	{}
178	\N	test	2018-03-16 15:44:22.87276	update	deployment	shared_deployment_with_errand	\N	21	shared_deployment_with_errand	\N	{}
179	\N	test	2018-03-16 15:44:22.885992	acquire	lock	lock:deployment:shared_deployment_with_errand	\N	21	shared_deployment_with_errand	\N	{}
180	\N	test	2018-03-16 15:44:22.976745	acquire	lock	lock:release:bosh-release	\N	21	\N	\N	{}
181	\N	test	2018-03-16 15:44:22.98573	release	lock	lock:release:bosh-release	\N	21	\N	\N	{}
182	\N	test	2018-03-16 15:44:23.312432	stop	instance	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	\N	21	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
183	\N	test	2018-03-16 15:44:23.359509	delete	vm	42094	\N	21	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
184	183	test	2018-03-16 15:44:23.527682	delete	vm	42094	\N	21	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
188	187	test	2018-03-16 15:44:23.840177	delete	vm	42087	\N	21	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
185	182	test	2018-03-16 15:44:23.587172	stop	instance	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	\N	21	shared_deployment_with_errand	shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780	{}
187	\N	test	2018-03-16 15:44:23.675524	delete	vm	42087	\N	21	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
189	186	test	2018-03-16 15:44:23.908616	stop	instance	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	\N	21	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
186	\N	test	2018-03-16 15:44:23.624773	stop	instance	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	\N	21	shared_deployment_with_errand	shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b	{}
190	178	test	2018-03-16 15:44:23.934339	update	deployment	shared_deployment_with_errand	\N	21	shared_deployment_with_errand	\N	{"before":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]},"after":{"releases":["bosh-release/0+dev.1"],"stemcells":["ubuntu-stemcell/1"]}}
191	\N	test	2018-03-16 15:44:23.939825	release	lock	lock:deployment:shared_deployment_with_errand	\N	21	shared_deployment_with_errand	\N	{}
\.


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('events_id_seq', 191, true);


--
-- Data for Name: instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY instances (id, job, index, deployment_id, state, resurrection_paused, uuid, availability_zone, cloud_properties, compilation, bootstrap, dns_records, spec_json, vm_cid_bak, agent_id_bak, trusted_certs_sha1_bak, update_completed, ignore, variable_set_id) FROM stdin;
2	errand_consumer_ig	0	1	started	f	18ae07fe-5ae3-4baf-aee7-6fc579e8ad29	z1	\N	f	t	[]	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	f	f	1
1	errand_provider_ig	0	1	detached	f	54b8a987-ba9c-48f9-bcc8-9598b38c6988	z1	{}	f	t	["0.errand-provider-ig.a.errand-deployment.bosh","54b8a987-ba9c-48f9-bcc8-9598b38c6988.errand-provider-ig.a.errand-deployment.bosh"]	{"deployment":"errand_deployment","job":{"name":"errand_provider_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"errand_provider_ig","id":"54b8a987-ba9c-48f9-bcc8-9598b38c6988","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.2","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.2","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"3c856161-405a-4b4f-a542-68a424aa7de0","sha1":"1124d62a7cef4e6132749cd099e80524e05cea17"},"configuration_hash":"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	1
3	shared_provider_ig	0	2	detached	f	44533eb4-176a-4bbc-933d-9c7e6880ccd1	z1	{}	f	t	["0.shared-provider-ig.a.shared-provider-deployment.bosh","44533eb4-176a-4bbc-933d-9c7e6880ccd1.shared-provider-ig.a.shared-provider-deployment.bosh"]	{"deployment":"shared_provider_deployment","job":{"name":"shared_provider_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.3","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.3","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"76a6ae72-5bb1-4ca3-b8c6-5a6cb008b69e","sha1":"436492e29a4b3e7ac3e3b5d1f95d28c2c629182e"},"configuration_hash":"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	2
8	implicit_consumer_ig	0	4	detached	f	b0ed951f-e935-467b-901f-1800ff584498	z1	{}	f	t	["0.implicit-consumer-ig.a.implicit-deployment.bosh","b0ed951f-e935-467b-901f-1800ff584498.implicit-consumer-ig.a.implicit-deployment.bosh"]	{"deployment":"implicit_deployment","job":{"name":"implicit_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"implicit_consumer_ig","id":"b0ed951f-e935-467b-901f-1800ff584498","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.6","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"35cc6e6ea5e0a7fda25a8e5785d0db4b479e8d33","blobstore_id":"492c1178-a32d-475f-7d5f-91199bbd3f06"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"implicit_deployment","domain":"bosh","instance_group":"implicit_provider_ig","instances":[{"name":"implicit_provider_ig","id":"2b7400e2-ad6c-48a1-b195-70c812977967","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.5"}],"networks":["a"],"properties":{"foo":"backup_bar"}},"backup_db":{"default_network":"a","deployment_name":"implicit_deployment","domain":"bosh","instance_group":"implicit_provider_ig","instances":[{"name":"implicit_provider_ig","id":"2b7400e2-ad6c-48a1-b195-70c812977967","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.5"}],"networks":["a"],"properties":{"foo":"backup_bar"}}}},"address":"192.168.1.6","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"7e0d9aa0c28caf60849bd5b77c2b47db4a1ed16e"},"rendered_templates_archive":{"blobstore_id":"88240abc-99df-4940-9320-7726752e69a4","sha1":"6425984c14ba858707ea1f2b5f969b71680671d5"},"configuration_hash":"4a08e2e790a88be31bd6d3cc9afe3e883595194e"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	4
10	explicit_consumer_ig	0	5	detached	f	78c10b8a-19f6-4db5-a575-e0d33af9c4e7	z1	{}	f	t	["0.explicit-consumer-ig.a.explicit-deployment.bosh","78c10b8a-19f6-4db5-a575-e0d33af9c4e7.explicit-consumer-ig.a.explicit-deployment.bosh"]	{"deployment":"explicit_deployment","job":{"name":"explicit_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"explicit_consumer_ig","id":"78c10b8a-19f6-4db5-a575-e0d33af9c4e7","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.8","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"35cc6e6ea5e0a7fda25a8e5785d0db4b479e8d33","blobstore_id":"492c1178-a32d-475f-7d5f-91199bbd3f06"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"explicit_deployment","domain":"bosh","instance_group":"explicit_provider_ig","instances":[{"name":"explicit_provider_ig","id":"caedfba5-9b01-435d-b419-f58a6da89547","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.7"}],"networks":["a"],"properties":{"foo":"backup_bar"}},"backup_db":{"default_network":"a","deployment_name":"explicit_deployment","domain":"bosh","instance_group":"explicit_provider_ig","instances":[{"name":"explicit_provider_ig","id":"caedfba5-9b01-435d-b419-f58a6da89547","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.7"}],"networks":["a"],"properties":{"foo":"backup_bar"}}}},"address":"192.168.1.8","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"72ca1612e1f28ea49fa0a097ad1b6dd75a71bf55"},"rendered_templates_archive":{"blobstore_id":"b1fd14a8-c216-4db7-b513-b40d23310219","sha1":"ba7bddcfd5ca19abeabe198ed0254ce692238661"},"configuration_hash":"be9e7be2b9c06e1d807c37622fffd96d603dd213"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	5
14	errand_consumer_ig	0	7	started	f	8a19240e-f5b8-4442-b91d-6576384b5c22	z1	\N	f	t	[]	\N	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	f	f	7
12	shared_provider_ig	0	7	detached	f	b41a9abd-5711-4647-ade8-6d1eec942780	z1	{}	f	t	["0.shared-provider-ig.a.shared-deployment-with-errand.bosh","b41a9abd-5711-4647-ade8-6d1eec942780.shared-provider-ig.a.shared-deployment-with-errand.bosh"]	{"deployment":"shared_deployment_with_errand","job":{"name":"shared_provider_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_provider_ig","id":"b41a9abd-5711-4647-ade8-6d1eec942780","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.14","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.14","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"74323603-4f4b-4291-984e-a6c6b6d31abf","sha1":"2b1f3fa20b924bc9aa4ad658aaead5b65bde559b"},"configuration_hash":"6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	7
13	shared_consumer_ig	0	7	detached	f	33b1fafd-c568-4c1b-8bac-99142442cb3b	z1	{}	f	t	["0.shared-consumer-ig.a.shared-deployment-with-errand.bosh","33b1fafd-c568-4c1b-8bac-99142442cb3b.shared-consumer-ig.a.shared-deployment-with-errand.bosh"]	{"deployment":"shared_deployment_with_errand","job":{"name":"shared_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_consumer_ig","id":"33b1fafd-c568-4c1b-8bac-99142442cb3b","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.15","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"35cc6e6ea5e0a7fda25a8e5785d0db4b479e8d33","blobstore_id":"492c1178-a32d-475f-7d5f-91199bbd3f06"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}},"backup_db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}}}},"address":"192.168.1.15","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"fd92a687d8c8703d7c2ccdec2dc559ca92e65f1a"},"rendered_templates_archive":{"blobstore_id":"de1d4b48-390c-46cf-ad65-d9eb89fa59df","sha1":"9491858c70304482a572deb36fef55937a2c66ad"},"configuration_hash":"27f6c274438945a7bfd3b1af6fa46d07360866ad"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	7
4	shared_consumer_ig	0	3	detached	f	375307d5-419c-4f31-9070-aab35625e7a4	z1	{}	f	t	["0.shared-consumer-ig.a.shared-consumer-deployment.bosh","375307d5-419c-4f31-9070-aab35625e7a4.shared-consumer-ig.a.shared-consumer-deployment.bosh"]	{"deployment":"shared_consumer_deployment","job":{"name":"shared_consumer_ig","templates":[{"name":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]}],"template":"api_server","version":"fd80d6fe55e4dfec8edfe258e1ba03c24146954e","sha1":"a5715744d7b42e17269a95ac2bda96c45ece412d","blobstore_id":"7b227063-509c-47b2-9d38-1f90096b3c6b","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"shared_consumer_ig","id":"375307d5-419c-4f31-9070-aab35625e7a4","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.4","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{"pkg_3_depends_on_2":{"name":"pkg_3_depends_on_2","version":"2dfa256bc0b0750ae9952118c428b0dcd1010305.1","sha1":"35cc6e6ea5e0a7fda25a8e5785d0db4b479e8d33","blobstore_id":"492c1178-a32d-475f-7d5f-91199bbd3f06"}},"properties":{"api_server":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"api_server":{"db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}},"backup_db":{"default_network":"a","deployment_name":"shared_provider_deployment","domain":"bosh","instance_group":"shared_provider_ig","instances":[{"name":"shared_provider_ig","id":"44533eb4-176a-4bbc-933d-9c7e6880ccd1","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.3"}],"networks":["a"],"properties":{"foo":"normal_bar"}}}},"address":"192.168.1.4","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"api_server":"fd92a687d8c8703d7c2ccdec2dc559ca92e65f1a"},"rendered_templates_archive":{"blobstore_id":"c97f7687-6381-44a0-9d82-bfa2e2a980bc","sha1":"5d3445a713723c4c57e552e088d946eb820f3e49"},"configuration_hash":"27f6c274438945a7bfd3b1af6fa46d07360866ad"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	3
7	implicit_provider_ig	0	4	detached	f	2b7400e2-ad6c-48a1-b195-70c812977967	z1	{}	f	t	["0.implicit-provider-ig.a.implicit-deployment.bosh","2b7400e2-ad6c-48a1-b195-70c812977967.implicit-provider-ig.a.implicit-deployment.bosh"]	{"deployment":"implicit_deployment","job":{"name":"implicit_provider_ig","templates":[{"name":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"c8a3d0ffb2c4e58dd7022580065c863da0b71a58","blobstore_id":"8cc31c4c-f8d6-4ba8-aa1c-dc3e78c2b0d6","logs":[]}],"template":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"c8a3d0ffb2c4e58dd7022580065c863da0b71a58","blobstore_id":"8cc31c4c-f8d6-4ba8-aa1c-dc3e78c2b0d6","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"implicit_provider_ig","id":"2b7400e2-ad6c-48a1-b195-70c812977967","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.5","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"backup_database":{"foo":"backup_bar"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.5","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"backup_database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"60880ab5-e367-4968-a246-eb170033e369","sha1":"537d614d1d4c40b0452b93977a52baa9d1b48577"},"configuration_hash":"4e4c9c0b7e76b5bc955b215edbd839e427d581aa"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	4
9	explicit_provider_ig	0	5	detached	f	caedfba5-9b01-435d-b419-f58a6da89547	z1	{}	f	t	["0.explicit-provider-ig.a.explicit-deployment.bosh","caedfba5-9b01-435d-b419-f58a6da89547.explicit-provider-ig.a.explicit-deployment.bosh"]	{"deployment":"explicit_deployment","job":{"name":"explicit_provider_ig","templates":[{"name":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"c8a3d0ffb2c4e58dd7022580065c863da0b71a58","blobstore_id":"8cc31c4c-f8d6-4ba8-aa1c-dc3e78c2b0d6","logs":[]}],"template":"backup_database","version":"822933af7d854849051ca16539653158ad233e5e","sha1":"c8a3d0ffb2c4e58dd7022580065c863da0b71a58","blobstore_id":"8cc31c4c-f8d6-4ba8-aa1c-dc3e78c2b0d6","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"explicit_provider_ig","id":"caedfba5-9b01-435d-b419-f58a6da89547","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.7","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"backup_database":{"foo":"backup_bar"}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{},"address":"192.168.1.7","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"backup_database":"da39a3ee5e6b4b0d3255bfef95601890afd80709"},"rendered_templates_archive":{"blobstore_id":"0d58697f-41a5-4c13-a260-2651a43f035c","sha1":"e6ade22a37e521aaab76074bf076cc456e12cfb7"},"configuration_hash":"4e4c9c0b7e76b5bc955b215edbd839e427d581aa"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	5
11	errand_ig	0	6	detached	f	4379d91f-43a0-49bb-ac5c-6bbc5857d3e6	z1	{}	f	t	["0.errand-ig.a.colocated-errand-deployment.bosh","4379d91f-43a0-49bb-ac5c-6bbc5857d3e6.errand-ig.a.colocated-errand-deployment.bosh"]	{"deployment":"colocated_errand_deployment","job":{"name":"errand_ig","templates":[{"name":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]},{"name":"errand_with_links","version":"9a52f02643a46dda217689182e5fa3b57822ced5","sha1":"e1c3a81ebfc98ec80e6fb2ec710d51830060eeab","blobstore_id":"d210d6c8-f56c-492f-abc0-43058979a98c","logs":[]}],"template":"database","version":"b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","sha1":"e08456054e6ac81fb782c62808dc68dccfec3c07","blobstore_id":"c583e140-423c-4120-a472-c16de058c264","logs":[]},"index":0,"bootstrap":true,"lifecycle":"service","name":"errand_ig","id":"4379d91f-43a0-49bb-ac5c-6bbc5857d3e6","az":"z1","networks":{"a":{"type":"manual","ip":"192.168.1.9","netmask":"255.255.255.0","cloud_properties":{},"default":["dns","gateway"],"dns":["192.168.1.1","192.168.1.2"],"gateway":"192.168.1.1"}},"vm_type":{"name":"a","cloud_properties":{}},"vm_resources":null,"stemcell":{"name":"ubuntu-stemcell","version":"1"},"env":{},"packages":{},"properties":{"database":{"foo":"normal_bar","test":"default test property"},"errand_with_links":{}},"properties_need_filtering":true,"dns_domain_name":"bosh","links":{"errand_with_links":{"db":{"default_network":"a","deployment_name":"colocated_errand_deployment","domain":"bosh","instance_group":"errand_ig","instances":[{"name":"errand_ig","id":"4379d91f-43a0-49bb-ac5c-6bbc5857d3e6","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.9"}],"networks":["a"],"properties":{"foo":"normal_bar"}},"backup_db":{"default_network":"a","deployment_name":"colocated_errand_deployment","domain":"bosh","instance_group":"errand_ig","instances":[{"name":"errand_ig","id":"4379d91f-43a0-49bb-ac5c-6bbc5857d3e6","index":0,"bootstrap":true,"az":"z1","address":"192.168.1.9"}],"networks":["a"],"properties":{"foo":"normal_bar"}}}},"address":"192.168.1.9","update":{"canaries":"2","max_in_flight":"1","canary_watch_time":"4000-4000","update_watch_time":"20-20","serial":true,"strategy":"legacy"},"persistent_disk":0,"template_hashes":{"database":"da39a3ee5e6b4b0d3255bfef95601890afd80709","errand_with_links":"f784720a6b701bc13681ad4f3dd10a8e5bec8749"},"rendered_templates_archive":{"blobstore_id":"a7d505cd-c5d1-4e20-8bbe-0be7a4b26e1a","sha1":"6511d5c880f98e81da5652a28d6ab08147f36272"},"configuration_hash":"c25668841bbee02e2ac89f3488d336846844235f"}	\N	\N	da39a3ee5e6b4b0d3255bfef95601890afd80709	t	f	6
\.


--
-- Name: instances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_id_seq', 14, true);


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
8	11	11
9	11	13
10	12	11
11	13	2
\.


--
-- Name: instances_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('instances_templates_id_seq', 11, true);


--
-- Data for Name: ip_addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ip_addresses (id, network_name, static, instance_id, created_at, task_id, address_str) FROM stdin;
1	a	f	1	2018-03-16 15:42:38.930457	3	3232235778
2	a	f	3	2018-03-16 15:42:49.241987	4	3232235779
3	a	f	4	2018-03-16 15:42:59.37392	5	3232235780
6	a	f	7	2018-03-16 15:43:16.747286	7	3232235781
7	a	f	8	2018-03-16 15:43:16.753844	7	3232235782
8	a	f	9	2018-03-16 15:43:31.850548	9	3232235783
9	a	f	10	2018-03-16 15:43:31.856981	9	3232235784
10	a	f	11	2018-03-16 15:43:47.596873	11	3232235785
11	a	f	12	2018-03-16 15:43:57.798198	13	3232235790
12	a	f	13	2018-03-16 15:43:57.805225	13	3232235791
\.


--
-- Name: ip_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ip_addresses_id_seq', 12, true);


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
9	errand_ig	6
10	shared_provider_ig	7
11	shared_consumer_ig	7
12	errand_consumer_ig	7
\.


--
-- Name: local_dns_encoded_instance_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_encoded_instance_groups_id_seq', 12, true);


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
11	192.168.1.2	z1	errand_provider_ig	a	errand_deployment	1	\N	bosh
12	192.168.1.3	z1	shared_provider_ig	a	shared_provider_deployment	3	\N	bosh
13	192.168.1.4	z1	shared_consumer_ig	a	shared_consumer_deployment	4	\N	bosh
14	192.168.1.5	z1	implicit_provider_ig	a	implicit_deployment	7	\N	bosh
15	192.168.1.6	z1	implicit_consumer_ig	a	implicit_deployment	8	\N	bosh
16	192.168.1.7	z1	explicit_provider_ig	a	explicit_deployment	9	\N	bosh
17	192.168.1.8	z1	explicit_consumer_ig	a	explicit_deployment	10	\N	bosh
18	192.168.1.9	z1	errand_ig	a	colocated_errand_deployment	11	\N	bosh
19	192.168.1.14	z1	shared_provider_ig	a	shared_deployment_with_errand	12	\N	bosh
20	192.168.1.15	z1	shared_consumer_ig	a	shared_deployment_with_errand	13	\N	bosh
\.


--
-- Name: local_dns_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('local_dns_records_id_seq', 20, true);


--
-- Data for Name: locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY locks (id, expired_at, name, uid, task_id) FROM stdin;
\.


--
-- Name: locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locks_id_seq', 31, true);


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
1	pkg_1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b	c65b32fe-888c-4e02-9947-c33d444780cb	d7288384b9cf0b82b4cc1eac7bab44d61ec1ec19	[]	1	7a4094dc99aa72d2d156d99e022d3baa37fb7c4b
2	pkg_2	fa48497a19f12e925b32fcb8f5ca2b42144e4444	c8fc603e-368b-42dd-815c-6ab9fe8703c0	f986f1c3151bfe134c2f9ba31ab5eae924c933ec	[]	1	fa48497a19f12e925b32fcb8f5ca2b42144e4444
3	pkg_3_depends_on_2	2dfa256bc0b0750ae9952118c428b0dcd1010305	fb81063d-d5fc-41d9-8723-3e6402031621	c86fafeccce0836ee111aacc905ec9d1ba4371af	["pkg_2"]	1	2dfa256bc0b0750ae9952118c428b0dcd1010305
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
9	2.1.168.192.in-addr.arpa	PTR	54b8a987-ba9c-48f9-bcc8-9598b38c6988.errand-provider-ig.a.errand-deployment.bosh	300	\N	1521215055	2
16	375307d5-419c-4f31-9070-aab35625e7a4.shared-consumer-ig.a.shared-consumer-deployment.bosh	A	192.168.1.4	300	\N	1521215057	1
17	4.1.168.192.in-addr.arpa	PTR	375307d5-419c-4f31-9070-aab35625e7a4.shared-consumer-ig.a.shared-consumer-deployment.bosh	300	\N	1521215057	2
32	78c10b8a-19f6-4db5-a575-e0d33af9c4e7.explicit-consumer-ig.a.explicit-deployment.bosh	A	192.168.1.8	300	\N	1521215060	1
10	0.shared-provider-ig.a.shared-provider-deployment.bosh	A	192.168.1.3	300	\N	1521215056	1
11	3.1.168.192.in-addr.arpa	PTR	0.shared-provider-ig.a.shared-provider-deployment.bosh	300	\N	1521215056	2
33	8.1.168.192.in-addr.arpa	PTR	78c10b8a-19f6-4db5-a575-e0d33af9c4e7.explicit-consumer-ig.a.explicit-deployment.bosh	300	\N	1521215060	2
3	ns.bosh	A	\N	18000	\N	1521215063	1
18	0.implicit-provider-ig.a.implicit-deployment.bosh	A	192.168.1.5	300	\N	1521215059	1
4	0.errand-provider-ig.a.errand-deployment.bosh	A	192.168.1.2	300	\N	1521215055	1
7	2.1.168.192.in-addr.arpa	PTR	0.errand-provider-ig.a.errand-deployment.bosh	300	\N	1521215055	2
8	54b8a987-ba9c-48f9-bcc8-9598b38c6988.errand-provider-ig.a.errand-deployment.bosh	A	192.168.1.2	300	\N	1521215055	1
12	44533eb4-176a-4bbc-933d-9c7e6880ccd1.shared-provider-ig.a.shared-provider-deployment.bosh	A	192.168.1.3	300	\N	1521215056	1
13	3.1.168.192.in-addr.arpa	PTR	44533eb4-176a-4bbc-933d-9c7e6880ccd1.shared-provider-ig.a.shared-provider-deployment.bosh	300	\N	1521215056	2
24	b0ed951f-e935-467b-901f-1800ff584498.implicit-consumer-ig.a.implicit-deployment.bosh	A	192.168.1.6	300	\N	1521215059	1
25	6.1.168.192.in-addr.arpa	PTR	b0ed951f-e935-467b-901f-1800ff584498.implicit-consumer-ig.a.implicit-deployment.bosh	300	\N	1521215059	2
38	0.shared-provider-ig.a.shared-deployment-with-errand.bosh	A	192.168.1.14	300	\N	1521215063	1
14	0.shared-consumer-ig.a.shared-consumer-deployment.bosh	A	192.168.1.4	300	\N	1521215057	1
15	4.1.168.192.in-addr.arpa	PTR	0.shared-consumer-ig.a.shared-consumer-deployment.bosh	300	\N	1521215057	2
19	5.1.168.192.in-addr.arpa	PTR	0.implicit-provider-ig.a.implicit-deployment.bosh	300	\N	1521215059	2
20	2b7400e2-ad6c-48a1-b195-70c812977967.implicit-provider-ig.a.implicit-deployment.bosh	A	192.168.1.5	300	\N	1521215059	1
21	5.1.168.192.in-addr.arpa	PTR	2b7400e2-ad6c-48a1-b195-70c812977967.implicit-provider-ig.a.implicit-deployment.bosh	300	\N	1521215059	2
22	0.implicit-consumer-ig.a.implicit-deployment.bosh	A	192.168.1.6	300	\N	1521215059	1
23	6.1.168.192.in-addr.arpa	PTR	0.implicit-consumer-ig.a.implicit-deployment.bosh	300	\N	1521215059	2
39	14.1.168.192.in-addr.arpa	PTR	0.shared-provider-ig.a.shared-deployment-with-errand.bosh	300	\N	1521215063	2
40	b41a9abd-5711-4647-ade8-6d1eec942780.shared-provider-ig.a.shared-deployment-with-errand.bosh	A	192.168.1.14	300	\N	1521215063	1
26	0.explicit-provider-ig.a.explicit-deployment.bosh	A	192.168.1.7	300	\N	1521215060	1
27	7.1.168.192.in-addr.arpa	PTR	0.explicit-provider-ig.a.explicit-deployment.bosh	300	\N	1521215060	2
28	caedfba5-9b01-435d-b419-f58a6da89547.explicit-provider-ig.a.explicit-deployment.bosh	A	192.168.1.7	300	\N	1521215060	1
29	7.1.168.192.in-addr.arpa	PTR	caedfba5-9b01-435d-b419-f58a6da89547.explicit-provider-ig.a.explicit-deployment.bosh	300	\N	1521215060	2
30	0.explicit-consumer-ig.a.explicit-deployment.bosh	A	192.168.1.8	300	\N	1521215060	1
31	8.1.168.192.in-addr.arpa	PTR	0.explicit-consumer-ig.a.explicit-deployment.bosh	300	\N	1521215060	2
41	14.1.168.192.in-addr.arpa	PTR	b41a9abd-5711-4647-ade8-6d1eec942780.shared-provider-ig.a.shared-deployment-with-errand.bosh	300	\N	1521215063	2
34	0.errand-ig.a.colocated-errand-deployment.bosh	A	192.168.1.9	300	\N	1521215062	1
35	9.1.168.192.in-addr.arpa	PTR	0.errand-ig.a.colocated-errand-deployment.bosh	300	\N	1521215062	2
36	4379d91f-43a0-49bb-ac5c-6bbc5857d3e6.errand-ig.a.colocated-errand-deployment.bosh	A	192.168.1.9	300	\N	1521215062	1
37	9.1.168.192.in-addr.arpa	PTR	4379d91f-43a0-49bb-ac5c-6bbc5857d3e6.errand-ig.a.colocated-errand-deployment.bosh	300	\N	1521215062	2
1	bosh	SOA	localhost hostmaster@localhost 0 10800 604800 30	300	\N	1521215063	1
2	bosh	NS	ns.bosh	14400	\N	1521215063	1
42	0.shared-consumer-ig.a.shared-deployment-with-errand.bosh	A	192.168.1.15	300	\N	1521215063	1
43	15.1.168.192.in-addr.arpa	PTR	0.shared-consumer-ig.a.shared-deployment-with-errand.bosh	300	\N	1521215063	2
44	33b1fafd-c568-4c1b-8bac-99142442cb3b.shared-consumer-ig.a.shared-deployment-with-errand.bosh	A	192.168.1.15	300	\N	1521215063	1
45	15.1.168.192.in-addr.arpa	PTR	33b1fafd-c568-4c1b-8bac-99142442cb3b.shared-consumer-ig.a.shared-deployment-with-errand.bosh	300	\N	1521215063	2
\.


--
-- Name: records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('records_id_seq', 45, true);


--
-- Data for Name: release_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY release_versions (id, version, release_id, commit_hash, uncommitted_changes) FROM stdin;
1	0+dev.1	1	c2b5bf268	t
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
1	1	3c856161-405a-4b4f-a542-68a424aa7de0	1124d62a7cef4e6132749cd099e80524e05cea17	6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf	2018-03-16 15:42:41.800665
2	3	76a6ae72-5bb1-4ca3-b8c6-5a6cb008b69e	436492e29a4b3e7ac3e3b5d1f95d28c2c629182e	6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf	2018-03-16 15:42:51.132752
3	4	c97f7687-6381-44a0-9d82-bfa2e2a980bc	5d3445a713723c4c57e552e088d946eb820f3e49	27f6c274438945a7bfd3b1af6fa46d07360866ad	2018-03-16 15:43:07.571731
4	7	60880ab5-e367-4968-a246-eb170033e369	537d614d1d4c40b0452b93977a52baa9d1b48577	4e4c9c0b7e76b5bc955b215edbd839e427d581aa	2018-03-16 15:43:17.812055
5	8	88240abc-99df-4940-9320-7726752e69a4	6425984c14ba858707ea1f2b5f969b71680671d5	4a08e2e790a88be31bd6d3cc9afe3e883595194e	2018-03-16 15:43:24.086373
6	9	0d58697f-41a5-4c13-a260-2651a43f035c	e6ade22a37e521aaab76074bf076cc456e12cfb7	4e4c9c0b7e76b5bc955b215edbd839e427d581aa	2018-03-16 15:43:33.036506
7	10	b1fd14a8-c216-4db7-b513-b40d23310219	ba7bddcfd5ca19abeabe198ed0254ce692238661	be9e7be2b9c06e1d807c37622fffd96d603dd213	2018-03-16 15:43:39.287065
8	11	a7d505cd-c5d1-4e20-8bbe-0be7a4b26e1a	6511d5c880f98e81da5652a28d6ab08147f36272	c25668841bbee02e2ac89f3488d336846844235f	2018-03-16 15:43:49.694396
9	12	74323603-4f4b-4291-984e-a6c6b6d31abf	2b1f3fa20b924bc9aa4ad658aaead5b65bde559b	6d613a1ee01eec4c0f8ca66df0db71dca0c6e1cf	2018-03-16 15:44:00.284896
10	13	de1d4b48-390c-46cf-ad65-d9eb89fa59df	9491858c70304482a572deb36fef55937a2c66ad	27f6c274438945a7bfd3b1af6fa46d07360866ad	2018-03-16 15:44:06.521974
\.


--
-- Name: rendered_templates_archives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rendered_templates_archives_id_seq', 10, true);


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
2	done	2018-03-16 15:42:38.125599	create stemcell	/stemcells/ubuntu-stemcell/1	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/2	2018-03-16 15:42:37.728545	update_stemcell	test	\N	2018-03-16 15:42:37.728346	{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"started","progress":0}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Extracting stemcell archive","index":1,"state":"finished","progress":100}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"started","progress":0}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Verifying stemcell manifest","index":2,"state":"finished","progress":100}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"started","progress":0}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Checking if this stemcell already exists","index":3,"state":"finished","progress":100}\n{"time":1521214957,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"started","progress":0}\n{"time":1521214958,"stage":"Update stemcell","tags":[],"total":5,"task":"Uploading stemcell ubuntu-stemcell/1 to the cloud","index":4,"state":"finished","progress":100}\n{"time":1521214958,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"started","progress":0}\n{"time":1521214958,"stage":"Update stemcell","tags":[],"total":5,"task":"Save stemcell ubuntu-stemcell/1 (68aab7c44c857217641784806e2eeac4a3a99d1c)","index":5,"state":"finished","progress":100}\n		
4	done	2018-03-16 15:42:58.386384	create deployment	/deployments/shared_provider_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/4	2018-03-16 15:42:49.093806	update_deployment	test	shared_provider_deployment	2018-03-16 15:42:49.093621	{"time":1521214969,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521214969,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521214969,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521214969,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521214969,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0)","index":1,"state":"started","progress":0}\n{"time":1521214971,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0)","index":1,"state":"finished","progress":100}\n{"time":1521214971,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521214978,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0) (canary)","index":1,"state":"finished","progress":100}\n		
6	done	2018-03-16 15:43:15.471636	retrieve vm-stats		/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/6	2018-03-16 15:43:15.428941	vms	test	shared_consumer_deployment	2018-03-16 15:43:15.428739		{"vm_cid":"41922","vm_created_at":"2018-03-16T15:43:06Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.4"],"dns":["375307d5-419c-4f31-9070-aab35625e7a4.shared-consumer-ig.a.shared-consumer-deployment.bosh","0.shared-consumer-ig.a.shared-consumer-deployment.bosh"],"agent_id":"52a66a3c-5679-4b0d-926c-b4f206f5f8ab","job_name":"shared_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"1.3","user":"2.3","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.81","2.55","2.44"],"mem":{"kb":"20184524","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":173989}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"375307d5-419c-4f31-9070-aab35625e7a4","bootstrap":true,"ignore":false}\n	
8	done	2018-03-16 15:43:31.064683	retrieve vm-stats		/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/8	2018-03-16 15:43:31.00526	vms	test	implicit_deployment	2018-03-16 15:43:31.005008		{"vm_cid":"41959","vm_created_at":"2018-03-16T15:43:17Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.5"],"dns":["2b7400e2-ad6c-48a1-b195-70c812977967.implicit-provider-ig.a.implicit-deployment.bosh","0.implicit-provider-ig.a.implicit-deployment.bosh"],"agent_id":"326a1dd7-d7da-4fd4-a1c4-dc3cd3c657a9","job_name":"implicit_provider_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.9","user":"6.7","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.78","2.56","2.45"],"mem":{"kb":"20198492","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174005}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"2b7400e2-ad6c-48a1-b195-70c812977967","bootstrap":true,"ignore":false}\n{"vm_cid":"41958","vm_created_at":"2018-03-16T15:43:17Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.6"],"dns":["b0ed951f-e935-467b-901f-1800ff584498.implicit-consumer-ig.a.implicit-deployment.bosh","0.implicit-consumer-ig.a.implicit-deployment.bosh"],"agent_id":"22e8a821-3a58-4987-a356-e91a59533e79","job_name":"implicit_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.9","user":"6.8","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.78","2.56","2.45"],"mem":{"kb":"20198492","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174005}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"b0ed951f-e935-467b-901f-1800ff584498","bootstrap":true,"ignore":false}\n	
3	done	2018-03-16 15:42:48.044752	create deployment	/deployments/errand_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/3	2018-03-16 15:42:38.74124	update_deployment	test	errand_deployment	2018-03-16 15:42:38.741014	{"time":1521214958,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521214958,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521214959,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521214959,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521214959,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0)","index":1,"state":"started","progress":0}\n{"time":1521214961,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0)","index":1,"state":"finished","progress":100}\n{"time":1521214961,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521214967,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0) (canary)","index":1,"state":"finished","progress":100}\n		
21	done	2018-03-16 15:44:23.947121	create deployment	/deployments/shared_deployment_with_errand	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/21	2018-03-16 15:44:22.850318	update_deployment	test	shared_deployment_with_errand	2018-03-16 15:44:22.850055	{"time":1521215062,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215063,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215063,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215063,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215063,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215063,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215063,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215063,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0) (canary)","index":1,"state":"finished","progress":100}\n		
1	done	2018-03-16 15:42:36.889796	create release	Created release 'bosh-release/0+dev.1'	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/1	2018-03-16 15:42:35.70116	update_release	test	\N	2018-03-16 15:42:35.700965	{"time":1521214955,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"started","progress":0}\n{"time":1521214955,"stage":"Extracting release","tags":[],"total":1,"task":"Extracting release","index":1,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"started","progress":0}\n{"time":1521214955,"stage":"Verifying manifest","tags":[],"total":1,"task":"Verifying manifest","index":1,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"started","progress":0}\n{"time":1521214955,"stage":"Resolving package dependencies","tags":[],"total":1,"task":"Resolving package dependencies","index":1,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"started","progress":0}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_1/7a4094dc99aa72d2d156d99e022d3baa37fb7c4b","index":1,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"started","progress":0}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":2,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"started","progress":0}\n{"time":1521214955,"stage":"Creating new packages","tags":[],"total":3,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":3,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"started","progress":0}\n{"time":1521214955,"stage":"Creating new jobs","tags":[],"total":23,"task":"addon/1c5442ca2a20c46a3404e89d16b47c4757b1f0ca","index":1,"state":"finished","progress":100}\n{"time":1521214955,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e","index":2,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server/fd80d6fe55e4dfec8edfe258e1ba03c24146954e","index":2,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_link_types/058b26819bd6561a75c2fed45ec49e671c9fbc6a","index":3,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_bad_optional_links/8a2485f1de3d99657e101fd269202c39cf3b5d73","index":4,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_db_link/00831c288b4a42454543ff69f71360634bd06b7b","index":5,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_1/0efc908dd04d84858e3cf8b75c326f35af5a5a98","index":6,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"api_server_with_optional_links_2/15f815868a057180e21dbac61629f73ad3558fec","index":7,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"app_server/58e364fb74a01a1358475fc1da2ad905b78b4487","index":8,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"backup_database/822933af7d854849051ca16539653158ad233e5e","index":9,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c","index":10,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"consumer/9bed4913876cf51ae1a0ee4b561083711c19bf5c","index":10,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"database/b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65","index":11,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"database_with_two_provided_link_of_same_type/7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda","index":12,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5","index":13,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"errand_with_links/9a52f02643a46dda217689182e5fa3b57822ced5","index":13,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_endpoint_provider_with_property_types/30978e9fd0d29e52fe0369262e11fbcea1283889","index":14,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_proxy_with_requires/760680c4a796a2ffca24026c561c06dd5bdef6b3","index":15,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"http_server_with_provides/64244f12f2db2e7d93ccfbc13be744df87013389","index":16,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"kv_http_server/044ec02730e6d068ecf88a0d37fe48937687bdba","index":17,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"mongo_db/58529a6cd5775fa1f7ef89ab4165e0331cdb0c59","index":18,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/bade0800183844ade5a58a26ecfb4f22e4255d98","index":19,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"node/bade0800183844ade5a58a26ecfb4f22e4255d98","index":19,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider/e1ff4ff9a6304e1222484570a400788c55154b1c","index":20,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"provider_fail/314c385e96711cb5d56dd909a086563dae61bc37","index":21,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_proxy_with_requires/e60ea353cdd24b6997efdedab144431c0180645b","index":22,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"started","progress":0}\n{"time":1521214956,"stage":"Creating new jobs","tags":[],"total":23,"task":"tcp_server_with_provides/6c9ab3bde161668d1d1ea60f3611c3b19a3b3267","index":23,"state":"finished","progress":100}\n{"time":1521214956,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"started","progress":0}\n{"time":1521214956,"stage":"Release has been created","tags":[],"total":1,"task":"bosh-release/0+dev.1","index":1,"state":"finished","progress":100}\n		
11	done	2018-03-16 15:43:55.984122	create deployment	/deployments/colocated_errand_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/11	2018-03-16 15:43:47.419753	update_deployment	test	colocated_errand_deployment	2018-03-16 15:43:47.419356	{"time":1521215027,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215027,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215027,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215027,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215027,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0)","index":1,"state":"started","progress":0}\n{"time":1521215029,"stage":"Creating missing vms","tags":[],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0)","index":1,"state":"finished","progress":100}\n{"time":1521215029,"stage":"Updating instance","tags":["errand_ig"],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215035,"stage":"Updating instance","tags":["errand_ig"],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0) (canary)","index":1,"state":"finished","progress":100}\n		
19	done	2018-03-16 15:44:20.958016	create deployment	/deployments/explicit_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/19	2018-03-16 15:44:19.951705	update_deployment	test	explicit_deployment	2018-03-16 15:44:19.951513	{"time":1521215060,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215060,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215060,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215060,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215060,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215060,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215060,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215060,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0) (canary)","index":1,"state":"finished","progress":100}\n		
5	done	2018-03-16 15:43:14.80378	create deployment	/deployments/shared_consumer_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/5	2018-03-16 15:42:59.206914	update_deployment	test	shared_consumer_deployment	2018-03-16 15:42:59.206717	{"time":1521214979,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521214979,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521214979,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521214979,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521214979,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":1,"state":"started","progress":0}\n{"time":1521214982,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_2/fa48497a19f12e925b32fcb8f5ca2b42144e4444","index":1,"state":"finished","progress":100}\n{"time":1521214982,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":2,"state":"started","progress":0}\n{"time":1521214985,"stage":"Compiling packages","tags":[],"total":2,"task":"pkg_3_depends_on_2/2dfa256bc0b0750ae9952118c428b0dcd1010305","index":2,"state":"finished","progress":100}\n{"time":1521214985,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0)","index":1,"state":"started","progress":0}\n{"time":1521214987,"stage":"Creating missing vms","tags":[],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0)","index":1,"state":"finished","progress":100}\n{"time":1521214987,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521214994,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0) (canary)","index":1,"state":"finished","progress":100}\n		
7	done	2018-03-16 15:43:30.31325	create deployment	/deployments/implicit_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/7	2018-03-16 15:43:16.572291	update_deployment	test	implicit_deployment	2018-03-16 15:43:16.572107	{"time":1521214996,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521214996,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521214996,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521214996,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521214996,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0)","index":1,"state":"started","progress":0}\n{"time":1521214996,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0)","index":2,"state":"started","progress":0}\n{"time":1521214997,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0)","index":2,"state":"finished","progress":100}\n{"time":1521214997,"stage":"Creating missing vms","tags":[],"total":2,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0)","index":1,"state":"finished","progress":100}\n{"time":1521214997,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215004,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215004,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215010,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0) (canary)","index":1,"state":"finished","progress":100}\n		
10	done	2018-03-16 15:43:46.311652	retrieve vm-stats		/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/10	2018-03-16 15:43:46.250103	vms	test	explicit_deployment	2018-03-16 15:43:46.249904		{"vm_cid":"42003","vm_created_at":"2018-03-16T15:43:32Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.8"],"dns":["78c10b8a-19f6-4db5-a575-e0d33af9c4e7.explicit-consumer-ig.a.explicit-deployment.bosh","0.explicit-consumer-ig.a.explicit-deployment.bosh"],"agent_id":"5370740e-4f66-485d-ba2d-3053c7480c36","job_name":"explicit_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.4","user":"6.3","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.82","2.58","2.46"],"mem":{"kb":"20213124","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174020}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"78c10b8a-19f6-4db5-a575-e0d33af9c4e7","bootstrap":true,"ignore":false}\n{"vm_cid":"42010","vm_created_at":"2018-03-16T15:43:32Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.7"],"dns":["caedfba5-9b01-435d-b419-f58a6da89547.explicit-provider-ig.a.explicit-deployment.bosh","0.explicit-provider-ig.a.explicit-deployment.bosh"],"agent_id":"eca96a53-1a0e-46ff-a2c5-366a91de8f7c","job_name":"explicit_provider_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"3.2","user":"5.8","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.82","2.58","2.46"],"mem":{"kb":"20213124","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174020}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"caedfba5-9b01-435d-b419-f58a6da89547","bootstrap":true,"ignore":false}\n	
9	done	2018-03-16 15:43:45.507297	create deployment	/deployments/explicit_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/9	2018-03-16 15:43:31.660779	update_deployment	test	explicit_deployment	2018-03-16 15:43:31.660588	{"time":1521215011,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215011,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215011,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215011,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215012,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0)","index":1,"state":"started","progress":0}\n{"time":1521215012,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0)","index":2,"state":"started","progress":0}\n{"time":1521215012,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0)","index":2,"state":"finished","progress":100}\n{"time":1521215012,"stage":"Creating missing vms","tags":[],"total":2,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0)","index":1,"state":"finished","progress":100}\n{"time":1521215013,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215019,"stage":"Updating instance","tags":["explicit_provider_ig"],"total":1,"task":"explicit_provider_ig/caedfba5-9b01-435d-b419-f58a6da89547 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215019,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215025,"stage":"Updating instance","tags":["explicit_consumer_ig"],"total":1,"task":"explicit_consumer_ig/78c10b8a-19f6-4db5-a575-e0d33af9c4e7 (0) (canary)","index":1,"state":"finished","progress":100}\n		
14	done	2018-03-16 15:44:13.923408	retrieve vm-stats		/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/14	2018-03-16 15:44:13.857254	vms	test	shared_deployment_with_errand	2018-03-16 15:44:13.857069		{"vm_cid":null,"vm_created_at":null,"disk_cid":null,"disk_cids":[],"ips":[],"dns":[],"agent_id":null,"job_name":"errand_consumer_ig","index":0,"job_state":null,"state":"started","resource_pool":null,"vm_type":null,"vitals":null,"processes":[],"resurrection_paused":false,"az":"z1","id":"8a19240e-f5b8-4442-b91d-6576384b5c22","bootstrap":true,"ignore":false}\n{"vm_cid":"42094","vm_created_at":"2018-03-16T15:43:58Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.14"],"dns":["b41a9abd-5711-4647-ade8-6d1eec942780.shared-provider-ig.a.shared-deployment-with-errand.bosh","0.shared-provider-ig.a.shared-deployment-with-errand.bosh"],"agent_id":"58c30949-858a-4335-a0cb-93e2eaa75fcd","job_name":"shared_provider_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"5.0","user":"9.2","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.97","2.63","2.48"],"mem":{"kb":"20196480","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174047}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"b41a9abd-5711-4647-ade8-6d1eec942780","bootstrap":true,"ignore":false}\n{"vm_cid":"42087","vm_created_at":"2018-03-16T15:43:58Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.15"],"dns":["33b1fafd-c568-4c1b-8bac-99142442cb3b.shared-consumer-ig.a.shared-deployment-with-errand.bosh","0.shared-consumer-ig.a.shared-deployment-with-errand.bosh"],"agent_id":"f2ce0672-8c8a-40c6-9851-d6cabd886a05","job_name":"shared_consumer_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"5.0","user":"9.9","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.97","2.63","2.48"],"mem":{"kb":"20196480","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174047}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"33b1fafd-c568-4c1b-8bac-99142442cb3b","bootstrap":true,"ignore":false}\n	
12	done	2018-03-16 15:43:56.717184	retrieve vm-stats		/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/12	2018-03-16 15:43:56.671021	vms	test	colocated_errand_deployment	2018-03-16 15:43:56.670785		{"vm_cid":"42050","vm_created_at":"2018-03-16T15:43:48Z","disk_cid":null,"disk_cids":[],"ips":["192.168.1.9"],"dns":["4379d91f-43a0-49bb-ac5c-6bbc5857d3e6.errand-ig.a.colocated-errand-deployment.bosh","0.errand-ig.a.colocated-errand-deployment.bosh"],"agent_id":"978a897b-4738-48af-be67-483302666a48","job_name":"errand_ig","index":0,"job_state":"running","state":"started","resource_pool":"a","vm_type":"a","vitals":{"cpu":{"sys":"1.3","user":"2.3","wait":"0.0"},"disk":{"ephemeral":{"inode_percent":"0","percent":"82"},"system":{"inode_percent":"0","percent":"82"}},"load":["2.77","2.58","2.46"],"mem":{"kb":"20230600","percent":"60"},"swap":{"kb":"0","percent":"0"},"uptime":{"secs":174030}},"processes":[{"name":"process-1","state":"running","uptime":{"secs":144987},"mem":{"kb":100,"percent":0.1},"cpu":{"total":0.1}},{"name":"process-2","state":"running","uptime":{"secs":144988},"mem":{"kb":200,"percent":0.2},"cpu":{"total":0.2}},{"name":"process-3","state":"failing","uptime":{"secs":144989},"mem":{"kb":300,"percent":0.3},"cpu":{"total":0.3}}],"resurrection_paused":false,"az":"z1","id":"4379d91f-43a0-49bb-ac5c-6bbc5857d3e6","bootstrap":true,"ignore":false}\n	
16	done	2018-03-16 15:44:16.64447	create deployment	/deployments/shared_provider_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/16	2018-03-16 15:44:16.027624	update_deployment	test	shared_provider_deployment	2018-03-16 15:44:16.027433	{"time":1521215056,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215056,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215056,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215056,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215056,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215056,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/44533eb4-176a-4bbc-933d-9c7e6880ccd1 (0) (canary)","index":1,"state":"finished","progress":100}\n		
18	done	2018-03-16 15:44:19.728824	create deployment	/deployments/implicit_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/18	2018-03-16 15:44:18.721196	update_deployment	test	implicit_deployment	2018-03-16 15:44:18.720896	{"time":1521215058,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215058,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215059,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215059,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215059,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215059,"stage":"Updating instance","tags":["implicit_provider_ig"],"total":1,"task":"implicit_provider_ig/2b7400e2-ad6c-48a1-b195-70c812977967 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215059,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215059,"stage":"Updating instance","tags":["implicit_consumer_ig"],"total":1,"task":"implicit_consumer_ig/b0ed951f-e935-467b-901f-1800ff584498 (0) (canary)","index":1,"state":"finished","progress":100}\n		
13	done	2018-03-16 15:44:12.761048	create deployment	/deployments/shared_deployment_with_errand	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/13	2018-03-16 15:43:57.573607	update_deployment	test	shared_deployment_with_errand	2018-03-16 15:43:57.573402	{"time":1521215037,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215037,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215037,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215037,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215037,"stage":"Creating missing vms","tags":[],"total":2,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0)","index":1,"state":"started","progress":0}\n{"time":1521215037,"stage":"Creating missing vms","tags":[],"total":2,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0)","index":2,"state":"started","progress":0}\n{"time":1521215039,"stage":"Creating missing vms","tags":[],"total":2,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0)","index":2,"state":"finished","progress":100}\n{"time":1521215040,"stage":"Creating missing vms","tags":[],"total":2,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0)","index":1,"state":"finished","progress":100}\n{"time":1521215040,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215046,"stage":"Updating instance","tags":["shared_provider_ig"],"total":1,"task":"shared_provider_ig/b41a9abd-5711-4647-ade8-6d1eec942780 (0) (canary)","index":1,"state":"finished","progress":100}\n{"time":1521215046,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215052,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/33b1fafd-c568-4c1b-8bac-99142442cb3b (0) (canary)","index":1,"state":"finished","progress":100}\n		
15	done	2018-03-16 15:44:15.610584	create deployment	/deployments/errand_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/15	2018-03-16 15:44:14.923832	update_deployment	test	errand_deployment	2018-03-16 15:44:14.923513	{"time":1521215054,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215055,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215055,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215055,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215055,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215055,"stage":"Updating instance","tags":["errand_provider_ig"],"total":1,"task":"errand_provider_ig/54b8a987-ba9c-48f9-bcc8-9598b38c6988 (0) (canary)","index":1,"state":"finished","progress":100}\n		
17	done	2018-03-16 15:44:17.835549	create deployment	/deployments/shared_consumer_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/17	2018-03-16 15:44:17.218383	update_deployment	test	shared_consumer_deployment	2018-03-16 15:44:17.218095	{"time":1521215057,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215057,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215057,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215057,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215057,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215057,"stage":"Updating instance","tags":["shared_consumer_ig"],"total":1,"task":"shared_consumer_ig/375307d5-419c-4f31-9070-aab35625e7a4 (0) (canary)","index":1,"state":"finished","progress":100}\n		
20	done	2018-03-16 15:44:22.427879	create deployment	/deployments/colocated_errand_deployment	/Users/pivotal/workspace/bosh_master/src/tmp/integration-tests-workspace/pid-41603/sandbox/boshdir/tasks/20	2018-03-16 15:44:21.769054	update_deployment	test	colocated_errand_deployment	2018-03-16 15:44:21.768869	{"time":1521215061,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"started","progress":0}\n{"time":1521215061,"stage":"Preparing deployment","tags":[],"total":1,"task":"Preparing deployment","index":1,"state":"finished","progress":100}\n{"time":1521215062,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"started","progress":0}\n{"time":1521215062,"stage":"Preparing package compilation","tags":[],"total":1,"task":"Finding packages to compile","index":1,"state":"finished","progress":100}\n{"time":1521215062,"stage":"Updating instance","tags":["errand_ig"],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0) (canary)","index":1,"state":"started","progress":0}\n{"time":1521215062,"stage":"Updating instance","tags":["errand_ig"],"total":1,"task":"errand_ig/4379d91f-43a0-49bb-ac5c-6bbc5857d3e6 (0) (canary)","index":1,"state":"finished","progress":100}\n		
\.


--
-- Name: tasks_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tasks_new_id_seq', 21, true);


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
1	addon	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	7c1db682-ed1b-4c0c-9749-8d72f15e89a3	084782a8b1b4596114a6ed2a9b19b651a241cad7	[]	1	\N	1c5442ca2a20c46a3404e89d16b47c4757b1f0ca	\N	\N	\N	\N	{"name":"addon","templates":{"config.yml.erb":"config.yml"},"packages":[],"consumes":[{"name":"db","type":"db"}],"properties":{}}
2	api_server	fd80d6fe55e4dfec8edfe258e1ba03c24146954e	7b227063-509c-47b2-9d38-1f90096b3c6b	a5715744d7b42e17269a95ac2bda96c45ece412d	["pkg_3_depends_on_2"]	1	\N	fd80d6fe55e4dfec8edfe258e1ba03c24146954e	\N	\N	\N	\N	{"name":"api_server","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}],"properties":{}}
3	api_server_with_bad_link_types	058b26819bd6561a75c2fed45ec49e671c9fbc6a	5df7db3a-5863-47f7-ae9f-89439dd70073	a0e58ba37c77583549299d054d4c3b56b7c83c6a	["pkg_3_depends_on_2"]	1	\N	058b26819bd6561a75c2fed45ec49e671c9fbc6a	\N	\N	\N	\N	{"name":"api_server_with_bad_link_types","templates":{"config.yml.erb":"config.yml","somethingelse.yml.erb":"somethingelse.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"bad_link"},{"name":"backup_db","type":"bad_link_2"},{"name":"some_link_name","type":"bad_link_3"}],"properties":{}}
4	api_server_with_bad_optional_links	8a2485f1de3d99657e101fd269202c39cf3b5d73	fa106bc8-fe35-4116-9254-ba64b189b3cf	e0a54394672238b63ab87b1410b7e2162d7b80d1	["pkg_3_depends_on_2"]	1	\N	8a2485f1de3d99657e101fd269202c39cf3b5d73	\N	\N	\N	\N	{"name":"api_server_with_bad_optional_links","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"optional_link_name","type":"optional_link_type","optional":true}],"properties":{}}
5	api_server_with_optional_db_link	00831c288b4a42454543ff69f71360634bd06b7b	6fac86ff-82ef-4b10-b5a9-875a072e7cbd	dfed1fec45d36dd84f1b00d5a7c70225718987a1	["pkg_3_depends_on_2"]	1	\N	00831c288b4a42454543ff69f71360634bd06b7b	\N	\N	\N	\N	{"name":"api_server_with_optional_db_link","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db","optional":true}],"properties":{}}
6	api_server_with_optional_links_1	0efc908dd04d84858e3cf8b75c326f35af5a5a98	18314cbe-9731-4b2f-b934-e17abd19c904	5fe3c63ec24ff9a644944c5f171d674f00e9aa30	["pkg_3_depends_on_2"]	1	\N	0efc908dd04d84858e3cf8b75c326f35af5a5a98	\N	\N	\N	\N	{"name":"api_server_with_optional_links_1","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"},{"name":"optional_link_name","type":"optional_link_type","optional":true}],"properties":{}}
7	api_server_with_optional_links_2	15f815868a057180e21dbac61629f73ad3558fec	9a32b916-e179-416c-bcd1-2e26faf4fe54	3636588be6f2669fd28ab0993fed38ef465a3fe4	["pkg_3_depends_on_2"]	1	\N	15f815868a057180e21dbac61629f73ad3558fec	\N	\N	\N	\N	{"name":"api_server_with_optional_links_2","templates":{"config.yml.erb":"config.yml"},"packages":["pkg_3_depends_on_2"],"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db","optional":true}],"properties":{}}
8	app_server	58e364fb74a01a1358475fc1da2ad905b78b4487	5c6945cf-46ba-4864-bd63-e9994913dfe6	70c6e7f3e648ee6ca01c6bbb743937439b7b274c	[]	1	\N	58e364fb74a01a1358475fc1da2ad905b78b4487	\N	\N	\N	\N	{"name":"app_server","description":null,"templates":{"config.yml.erb":"config.yml"},"properties":{}}
9	backup_database	822933af7d854849051ca16539653158ad233e5e	8cc31c4c-f8d6-4ba8-aa1c-dc3e78c2b0d6	c8a3d0ffb2c4e58dd7022580065c863da0b71a58	[]	1	\N	822933af7d854849051ca16539653158ad233e5e	\N	\N	\N	\N	{"name":"backup_database","templates":{},"packages":[],"provides":[{"name":"backup_db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"backup_bar"}}}
10	consumer	9bed4913876cf51ae1a0ee4b561083711c19bf5c	b1f84b30-7100-444a-98f0-3526fad8e3ca	5da15fd4cd0226f083675eca84d11d2f5de5ea07	[]	1	\N	9bed4913876cf51ae1a0ee4b561083711c19bf5c	\N	\N	\N	\N	{"name":"consumer","templates":{"config.yml.erb":"config.yml"},"consumes":[{"name":"provider","type":"provider"}],"properties":{}}
11	database	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	c583e140-423c-4120-a472-c16de058c264	e08456054e6ac81fb782c62808dc68dccfec3c07	[]	1	\N	b69ff9ddfe7fc106f0d0ba07a9f98730d6dc0b65	\N	\N	\N	\N	{"name":"database","templates":{},"packages":[],"provides":[{"name":"db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"normal_bar"},"test":{"description":"test property","default":"default test property"}}}
12	database_with_two_provided_link_of_same_type	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	0171ed4f-bab7-47e5-a413-b016f0258f8d	200f1d57965525418cd31b0af1e8eb7180296a69	[]	1	\N	7f4c5700b68fe4f59588c5ca09c3d4a9f8a93dda	\N	\N	\N	\N	{"name":"database_with_two_provided_link_of_same_type","templates":{},"packages":[],"provides":[{"name":"db1","type":"db"},{"name":"db2","type":"db"}],"properties":{"test":{"description":"test property","default":"default test property"}}}
13	errand_with_links	9a52f02643a46dda217689182e5fa3b57822ced5	d210d6c8-f56c-492f-abc0-43058979a98c	e1c3a81ebfc98ec80e6fb2ec710d51830060eeab	[]	1	\N	9a52f02643a46dda217689182e5fa3b57822ced5	\N	\N	\N	\N	{"name":"errand_with_links","templates":{"config.yml.erb":"config.yml","run.erb":"bin/run"},"consumes":[{"name":"db","type":"db"},{"name":"backup_db","type":"db"}],"properties":{}}
14	http_endpoint_provider_with_property_types	30978e9fd0d29e52fe0369262e11fbcea1283889	7a20daf4-c0d2-45ee-afe2-b17a9cb27bc3	79a31391f302834714698f832a1662aaf47dd283	[]	1	\N	30978e9fd0d29e52fe0369262e11fbcea1283889	\N	\N	\N	\N	{"name":"http_endpoint_provider_with_property_types","description":"This job runs an HTTP server and with a provides link directive. It has properties with types.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"Has a type password and no default value","type":"password"}}}
15	http_proxy_with_requires	760680c4a796a2ffca24026c561c06dd5bdef6b3	13c421f7-f737-419e-af1a-87b58b8a7caf	8904f405f0b50fb39eab1639255c5722804f9557	[]	1	\N	760680c4a796a2ffca24026c561c06dd5bdef6b3	\N	\N	\N	\N	{"name":"http_proxy_with_requires","description":"This job runs an HTTP proxy and uses a link to find its backend.","templates":{"ctl.sh":"bin/ctl","config.yml.erb":"config/config.yml","props.json":"config/props.json","pre-start.erb":"bin/pre-start"},"consumes":[{"name":"proxied_http_endpoint","type":"http_endpoint"},{"name":"logs_http_endpoint","type":"http_endpoint2","optional":true}],"properties":{"http_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"http_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"http_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"http_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"http_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}}
16	http_server_with_provides	64244f12f2db2e7d93ccfbc13be744df87013389	c2571a31-5fbe-4a0f-a22e-971c90f06f82	7ff4f039f5360a626af42a39eb8ef5e01b1679aa	[]	1	\N	64244f12f2db2e7d93ccfbc13be744df87013389	\N	\N	\N	\N	{"name":"http_server_with_provides","description":"This job runs an HTTP server and with a provides link directive.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}}
17	kv_http_server	044ec02730e6d068ecf88a0d37fe48937687bdba	90c4be5b-87c5-4657-9cee-8d1befedb83c	37b60555ea5952298c392c20d86dab22cc01ad2f	[]	1	\N	044ec02730e6d068ecf88a0d37fe48937687bdba	\N	\N	\N	\N	{"name":"kv_http_server","description":"This job can run as a cluster.","templates":{"ctl.sh":"bin/ctl"},"consumes":[{"name":"kv_http_server","type":"kv_http_server"}],"provides":[{"name":"kv_http_server","type":"kv_http_server"}],"properties":{"kv_http_server.listen_port":{"description":"Port to listen on","default":8080}}}
18	mongo_db	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	66911897-9256-4aa8-9680-1d99330ac435	e1fbdca4d1f4ec45e85e45ec785c837d69374f94	["pkg_1"]	1	\N	58529a6cd5775fa1f7ef89ab4165e0331cdb0c59	\N	\N	\N	\N	{"name":"mongo_db","templates":{},"packages":["pkg_1"],"provides":[{"name":"read_only_db","type":"db","properties":["foo"]}],"properties":{"foo":{"default":"mongo_foo_db"}}}
19	node	bade0800183844ade5a58a26ecfb4f22e4255d98	b4130d0c-a110-4401-98be-f8c250d9801b	0cc30176d9069193a3add07dd1f711c538a06bab	[]	1	\N	bade0800183844ade5a58a26ecfb4f22e4255d98	\N	\N	\N	\N	{"name":"node","templates":{"config.yml.erb":"config.yml"},"packages":[],"provides":[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}],"consumes":[{"name":"node1","type":"node1"},{"name":"node2","type":"node2"}],"properties":{}}
20	provider	e1ff4ff9a6304e1222484570a400788c55154b1c	56be3171-746e-4e7a-a523-c21438ee852e	9031d08827b2062ac8f891db4a76d514df0a1781	[]	1	\N	e1ff4ff9a6304e1222484570a400788c55154b1c	\N	\N	\N	\N	{"name":"provider","templates":{},"provides":[{"name":"provider","type":"provider","properties":["a","b","c"]}],"properties":{"a":{"description":"description for a","default":"default_a"},"b":{"description":"description for b"},"c":{"description":"description for c","default":"default_c"}}}
21	provider_fail	314c385e96711cb5d56dd909a086563dae61bc37	9f12e8b7-88a8-4bf4-9f72-118d467346f8	e0f91a8765d3f3214a2b079d685e760f661660d0	[]	1	\N	314c385e96711cb5d56dd909a086563dae61bc37	\N	\N	\N	\N	{"name":"provider_fail","templates":{},"provides":[{"name":"provider_fail","type":"provider","properties":["a","b","c"]}],"properties":{"a":{"description":"description for a","default":"default_a"},"c":{"description":"description for c","default":"default_c"}}}
22	tcp_proxy_with_requires	e60ea353cdd24b6997efdedab144431c0180645b	87103e71-f90e-47e2-a69a-aa437dd98f7c	e3c32c88d7d9a3b30b753d0c638dc442cad42d28	[]	1	\N	e60ea353cdd24b6997efdedab144431c0180645b	\N	\N	\N	\N	{"name":"tcp_proxy_with_requires","description":"This job runs an HTTP proxy and uses a link to find its backend.","templates":{"ctl.sh":"bin/ctl","config.yml.erb":"config/config.yml","props.json":"config/props.json","pre-start.erb":"bin/pre-start"},"consumes":[{"name":"proxied_http_endpoint","type":"http_endpoint"}],"properties":{"tcp_proxy_with_requires.listen_port":{"description":"Listen port","default":8080},"tcp_proxy_with_requires.require_logs_in_template":{"description":"Require logs in template","default":false},"someProp":{"default":null},"tcp_proxy_with_requires.fail_instance_index":{"description":"Fail for instance #. Failure type must be set for failure","default":-1},"tcp_proxy_with_requires.fail_on_template_rendering":{"description":"Fail for instance <fail_instance_index> during template rendering","default":false},"tcp_proxy_with_requires.fail_on_job_start":{"description":"Fail for instance <fail_instance_index> on job start","default":false}}}
23	tcp_server_with_provides	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	2e08e733-c0ea-457b-8fb6-d3a71f403c15	4085793ad5f801bd6da82aeed34bf4a1b203ff83	[]	1	\N	6c9ab3bde161668d1d1ea60f3611c3b19a3b3267	\N	\N	\N	\N	{"name":"tcp_server_with_provides","description":"This job runs an HTTP server and with a provides link directive.","templates":{"ctl.sh":"bin/ctl"},"provides":[{"name":"http_endpoint","type":"http_endpoint","properties":["listen_port","name_space.prop_a","name_space.fibonacci"]}],"properties":{"listen_port":{"description":"Port to listen on","default":8080},"name_space.prop_a":{"description":"a name spaced property","default":"default"},"name_space.fibonacci":{"description":"has no default value"}}}
\.


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('templates_id_seq', 23, true);


--
-- Data for Name: variable_sets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY variable_sets (id, deployment_id, created_at, deployed_successfully, writable) FROM stdin;
1	1	2018-03-16 15:42:38.775468	t	f
2	2	2018-03-16 15:42:49.129506	t	f
3	3	2018-03-16 15:42:59.244376	t	f
4	4	2018-03-16 15:43:16.608192	t	f
5	5	2018-03-16 15:43:31.698967	t	f
6	6	2018-03-16 15:43:47.463859	t	f
7	7	2018-03-16 15:43:57.614127	t	f
\.


--
-- Name: variable_sets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('variable_sets_id_seq', 7, true);


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

SELECT pg_catalog.setval('vms_id_seq', 12, true);


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

