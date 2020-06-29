## Background
 - Differential privacy
 - Duet
 - SGX

## Overview
 - Problem setting
 - Threat model
 - Architecture overview of the system
 - Security & Privacy properties guaranteed

## The DuetSGX Server
 - API
 - Example workflow
   - Submitting data
   - Submitting query
 - Ensuring differential privacy: use of Duet
 - Ensuring confidentiality of data: properties of the "protocol" (what gets encrypted, with what keys, etc)
 - Ensuring confidentiality & integrity of computation: use of SGX
 - Limitations (e.g. issues with graphene)

## Case studies
 - Web-based frontend
 - Python-based frontend
 - PEAndroid integration for processing data from mobile devices
   - Location example
   - App data example

## Performance evaluation?
 - List of benchmarks (as Duet programs)
 - Performance comparison: Duet running in SGX vs Duet running outside of SGX
