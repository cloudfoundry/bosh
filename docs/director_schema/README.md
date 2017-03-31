# BOSH Director Database Schema

Here is an ER diagram of the schema that the BOSH director uses for
storing its state. The schema is accessed through a Ruby ORM called
Sequel. The Ruby classes that this schema maps to are located in the
[director's Models module](../../bosh-director/lib/bosh/director/models).

![ER diagram of BOSH director schema](bosh-db-diagram.png)

**Warning: This digram can become stale quickly; generate when necessary**

The above PNG file was generated using RubyMine Database Plugin.
Steps to generate:
- Using RubyMine Database plugin connect to a BOSH database. Quick trick would be to connect to a database created by an integration test.
- Right click database connection: Diagrams --> Show Visualizations . Make sure **UML Support** plugin is enabled.
- Export the diagram.
