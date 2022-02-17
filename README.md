# Overview
SQLive is a general-purpose SQL database that lets you subscribe to changes to your queries. Through a new construction called "virtual views", you can ask the database to keep a particular view up-to-date at all times, to notify you when that view has changed, or to produce a "diff" between now and any time in the past.

## Streaming
SQLive can also process ephemeral streams of data which can be used to receive alerts or to compute real-time analytics. Those ephemeral streams can then be mixed with SQL tables through joins or other constructions.

## Concurrent
As its name suggests, SQLive is inspired by SQLite and supports a robust subset of SQL (including transactions). What sets it apart is that it is also highly concurrent. SQLive supports processing complex queries from multiple simultaneous readers/writers without stalling other database users.
