# OpenStack BOSH Cloud Provider Interface

## Bringing the world’s most popular open source platform-as-a-service to the world’s most popular open source infrastructure-as-a-service platform

This repo contains software designed to manage the deployment of Cloud Foundry on top of OpenStack, using Cloud Foundry BOSH. Say what?

## OpenStack

OpenStack is a collection of interrelated open source projects that, together, form a pluggable framework for building massively-scalable infrastructure as a service clouds. OpenStack represents the world's largest and fastest-growing open cloud community, a global collaboration of over 150 leading companies.

## Cloud Foundry

Cloud Foundry is the leading open source platform-as-a-service (PaaS) offering with a fast growing ecosystem and strong enterprise demand.

## BOSH

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services. In this manual we describe the architecture, topology, configuration, and use of BOSH, as well as the structure and conventions used in packaging and deployment.

## OpenStack and Cloud Foundry, Together using BOSH

Cloud Foundry BOSH defines a Cloud Provider Interface API that enables platform-as-a-service deployment across multiple cloud providers - initially VMWare's vSphere and AWS. Piston Cloud has partnered with VMWare to provide a CPI for OpenStack, opening up Cloud Foundry deployment to an entire ecosystem of public and private OpenStack deployments.

Using a popular cloud-services client written in Ruby, the OpenStack CPI manages the deployment of a set of virtual machines and enables applications to be deployed dynamically using Cloud Foundry. A common image, called a stem-cell, allows Cloud Foundry BOSH to rapidly build new virtual machines enabling rapid scale-out.

We've partnered with VMWare to deliver this project, because the leading open-source platform-as-a-service offering should work seamlessly with deployments of the leading open-source infrastructure-as-a-service project. The work being done to develop this CPI, will enable customers of any OpenStack cloud to use Cloud Foundry to accelerate development of cloud applications and drive value by working against a common service API.

## Piston Cloud Computing, Inc.

Piston Cloud Computing, Inc. is the enterprise OpenStack™ company. Founded in early 2011 by technical team leads from NASA and Rackspace®, Piston Cloud is built around OpenStack, the fastest-growing, massively scalable cloud framework. Piston Enterprise OS™ (pentOS™) is the first fully- automated bare-metal cloud operating system built on OpenStack and the first OpenStack distribution specifically focused on security and easy operation of enterprise private clouds for the enterprise.  

## Legal Stuff

This project, as well as OpenStack and Cloud Foundry, are Apache2-licensed Open Source.

VMware and Cloud Foundry are registered trademarks or trademarks of VMware, Inc. in the United States and/or other jurisdictions.

OpenStack is a registered trademark of OpenStack, LLC.
