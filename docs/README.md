# BOSH development docs

These docs are designed to assist BOSH developers. They contain suggestions and recommendations for development and testing BOSH components.

The contents of docs include:

* [Workstation Setup](workstation_setup.md)
* [Pull Request Workflow](pull_request_workflow.md)
* [Running Tests](running_tests.md)
* [NATS Server](nats.md)
* [Director Database Schema Diagram](director_schema/README.md)
* [Code style](code_style.md)
* [Bumping blobs](bumping_blobs.md)

## BOSH Director Database Schema

There have been
Steps to generate:

- Use RubyMine Database plugin (View » Tool Windows » Database) to connect to a BOSH database.
- Right click database connection: Diagrams » Show Visualizations. The **UML Support** plugin is required.
- Export the diagram.

Models are located in [src/bosh-director/lib/bosh/director/models/](../src/bosh-director/lib/bosh/director/models)
