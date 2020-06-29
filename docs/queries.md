# Issuing Queries

Queries in DuetSGX are written as Duet programs. Duet is a programming
language and type system for verifying differential privacy; DuetSGX
uses this format to ensure that all queries satisfy differential
privacy. For more on Duet, see the [project
homepage](https://github.com/uvm-plaid/duet).

## API

The DuetSGX server accepts queries encoded as Duet programs at the
`/query` endpoint. To run a query, use a POST request with JSON of the
following form:

```
{'query': '<Duet query text here>'}
```

The response will be a string containing the query's output, taken
directly from the output of the Duet interpreter.

## Web Interface

A simple web interface for inserting data and running queries is
provided by the DuetSGX server. After setting up the server, navigate
to `http://localhost:5000/` to use this interface. You can copy and
paste a Duet program into the query text box and use the interface to
submit the query to the `/query` endpoint and view the response.

## Writing Duet Programs

Here's an example of a simple Duet program that counts the number of
rows in the database:

```
let main = pλ .
              df : 𝕄 [L∞ , U | ★ , 𝐝 ℝ ∷ 𝐝 ℝ ∷ [] ]
              ⇒
  let ε = ℝ⁺[1.0] in
  let δ = ℝ⁺[0.000001] in
  gauss[ℝ⁺[1.0], ε, δ] <df> { 
    real (rows df)
  }
in main
```

This program defines a function of a single argument (`df`) which is a
matrix of two columns of real numbers (`𝐝 ℝ ∷ 𝐝 ℝ ∷ []`)—for example,
location expressed as latitude, longitude pairs. The two `let`
expressions define constant values for the privacy parameters `ε` and
`δ`. Finally, the `gauss` expression counts the number of rows (`real
(rows df)`) and adds Gaussian noise sufficient to provide (ε,
δ)-differential privacy. The first part of the expression
(`gauss[ℝ⁺[1.0], ε, δ] <df>`) specifies the expected sensitivity of
the body (1.0, in this case) and desired privacy parameters, plus a
list of variables for which privacy should be tracked (`<df>` in this
case).

Duet can be used to write both standard database-style queries and
more complicated algorithms, including iterative differentially
private algorithms and machine learning algorithms. For more
information on writing Duet programs, see the [project
homepage](https://github.com/uvm-plaid/duet).

For DuetSGX, submitted programs must define a function of a single
argument, and the argument's type must match the schema of the
submitted data in the encrypted database. The program must satisfy
(ε,δ)-differential privacy for constant values of ε and δ, which the
Duet typechecker will derive when the program is submitted. These
values of ε and δ will be subtracted from the total privacy budget
when the program runs.
