# DuetSGX: A Platform for Collecting and Analyzing Data with Differential Privacy

DuetSGX is a platform for collecting sensitive data and performing
differentially private queries on that data.

The data submitted to a DuetSGX server is encrypted, and integrity and
confidentiality are protected via an Intel SGX [Trusted Execution
Environment
(TEE)](https://en.wikipedia.org/wiki/Trusted_execution_environment).

DuetSGX requires that *all* queries satisfy differential
privacy. Raw data can *never* be extracted *by any party* from a
DuetSGX server.

To ensure that queries satisfy differential privacy, DuetSGX performs
static analysis on the query using the [Duet
system](https://github.com/uvm-plaid/duet) before running the query.

## Team

The team primarily responsible for the DuetSGX system consists of:

- [Phillip Nguyen](https://github.com/pnguyen4)
- [Alex Silence](https://github.com/asilenceuvm) (asilence14@gmail.com)
- [Chike Abuah](https://github.com/chikeabuah)
- [Joe Near](http://www.uvm.edu/~jnear/)
- [David Darais](http://david.darais.com/)

The underlying [Duet system](https://github.com/uvm-plaid/duet) was
developed by a larger team for a variety of applications. For more
information on Duet, view the [project
webpage](https://github.com/uvm-plaid/duet) or read our [OOPSLA 2019
paper](https://dl.acm.org/doi/10.1145/3360598).

## Documentation

The DuetSGX platform includes client and server components, which are
described in the documents linked below.

- [Overview of DuetSGX](docs/README.md)
- [Developing an Android app to collect DuetSGX data](docs/client_setup.md)
- [Setting up a DuetSGX server](docs/server_setup.md)
- [Issuing queries](docs/queries.md)

## Security Warning

DuetSGX is a research prototype system, and should not be used in
production to provide strong security and privacy.

In particular, DuetSGX uses the [Graphene
system](https://github.com/oscarlab/graphene) to launch SGX enclaves,
and remote attestation is not completely secure as a result. The
DuetSGX server generates its public/private keypair inside the SGX
enclave, and asks the client to encrypt data using the public key from
this keypair; due to the lack of finalized remote attestation, a
maliciously-modified DuetSGX server could generate a second public key
*outside* of the enclave and ask the client to encrypt the data using
this compromised key. We expect Graphene's remote attestation support
to improve in the next few months, which should allow a solution to
this limitation.

## Acknowledgements

We would like to thank the [Privacy Enhancements for
Android](https://android-privacy.org/) team and the DARPA Brandeis
program for the exciting collaborative effort that enabled
DuetSGX. This work was supported by DARPA \& SPAWAR under contract
N66001-15-C-4066. The U.S. Government is authorized to reproduce and
distribute reprints for Governmental purposes not withstanding any
copyright notation thereon. The views, opinions, and/or findings
expressed are those of the author(s) and should not be interpreted as
representing the official views or policies of the Department of
Defense or the U.S. Government.
