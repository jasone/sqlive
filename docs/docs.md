# 

## Download

A free version of sqlive is available for non-commercial use ([license](https://github.com/SkipLabs/sqlive/blob/main/LICENSE.md)).
You can download it here:
[https://github.com/SkipLabs/sqlive/raw/main/bin/sqlive-linux-x64-0.9.bin](https://github.com/SkipLabs/sqlive/raw/main/bin/sqlive-linux-x64-0.9.bin)

For commercial use, please contact us at [contact@skiplabs.io](mailto:contact@skiplabs.io).

## Linux

SQLive is only available for x64-Linux.
If you don't have linux on your machine, you can install [WSL](https://docs.microsoft.com/en-us/windows/wsl/install) on windows or
[docker](https://docs.docker.com/desktop/mac/install/) for mac.
Although SQLive runs on most versions of Linux, SkipLabs will only maintain a version running on the latest [ubuntu LTS](https://wiki.ubuntu.com/Releases).
We highly recommend you use that version,
but if you need to run sqlive on a different platform, please contact us at [contact@skiplabs.io](mailto:contact@skiplabs.io).

## SQL

This documentations is not a good place to learn SQL. If you need to get started you can find a good introduction here: [https://www.w3schools.com/sql/](https://www.w3schools.com/sql/).
The subset of SQL implemented by SQLive is the same as SQLite, you can find it here: [https://www.sqlite.org/lang.html](https://www.sqlite.org/lang.html).

## Install

First, install the binary file (preferably in /usr/local/bin). Make sure you don't rename the original binary, because
some SQLive updates will require you to export your data to a newer version of the database. So it is safer to keep all
the different versions of SQLive around in case you need them.

```$ wget https://github.com/SkipLabs/sqlive/raw/main/bin/sqlive-linux-x64-0.9.bin
$ chmod 755 sqlive-linux-x64-0.9.bin
$ sudo mv sqlive-linux-x64-0.9.bin /usr/local/bin
$ sudo ln -s /usr/local/bin/sqlive-linux-x64-0.9.bin /usr/local/bin/sqlive
```

## Initialization

SQLive stores all of its data in a file specified by the user.
To initialize a database file, use the option --init.

```$ sqlive --init /tmp/test.db
```

Make sure you do not manipulate this file (copy, rename etc ...) while other processes are accessing the database.
By default, the maximum capacity of the database is 16GB. Meaning, the database will only be accessible in read-only
mode once that limit is reached. If you need a larger capacity, you can use the option --capacity at initialization time.

```$ sqlive --init /tmp/test.db --capacity $YOUR_CHOICE_IN_BYTES
```

## Loading data

Let's first load some mock data to play with the database.

```$ wget https://github.com/SkipLabs/sqlive/raw/main/example/tiny_TPCH.sql
$ cat tiny_TPCH.sql | sqlive --data /tmp/test.db
```

This created two tables. One named customer the other named orders.
Here are their schema:

```$ sqlive --dump-tables --data /tmp/test.db
CREATE TABLE customer (
  c_custkey INTEGER PRIMARY KEY,
  c_name TEXT,
  c_address TEXT,
  c_nationkey INTEGER,
  c_phone TEXT,
  c_acctbal FLOAT,
  c_mktsegment TEXT,
  c_comment TEXT
);
CREATE TABLE orders (
  o_orderkey INTEGER PRIMARY KEY,
  o_custkey INTEGER,
  o_orderstatus TEXT,
  o_totalprice FLOAT,
  o_orderdate TEXT,
  o_orderpriority TEXT,
  o_clerk TEXT,
  o_shippriority INTEGER,
  o_comment TEXT
);
```

Note that SQLive only supports 3 types:
64 bits integers (INTEGER),
64 bits floating point numbers (FLOAT)
and UTF-8 strings (TEXT).

By looking at the schema, we can see that the two tables are related through the columns c\_custkey and o\_custkey.
Each order identifies the customer that passed the order through a unique identifier (as it is often the case in
relational databases). But what happens when a query needs to both process an order and lookup the data associated to the
user that passed the order? This requires the use of a join, which you will see, work a bit differently in SQLive.

## Joins

Let's try to run a basic join:

```$ echo "select * from customer, orders where c_custkey = o_custkey;" | sqlive --data /tmp/test.db
```

Surprisingly, this leads to an error (the error can be ignored with the option --always-allow-join):

```$ echo "select * from customer, orders where c_custkey = o_custkey;" | sqlive --data /tmp/test.db
select * from customer, orders where c_custkey = o_custkey;
^
|
 ----- ERROR
Error: line 1, characters 0-0:
Joins outside of virtual views are considered bad practice in sqlive.
You should first create a virtual view joining customer and orders with a query of the form:
create virtual view customer_orders as select * from customer, orders where c_custkey = o_custkey;
And then use customer_orders directly.
PS: You can ignore this error message with --always-allow-join (not recommended).
PS2: don't forget you can add indexes to virtual views.
```

The error message is pretty explicit. Joins outside of a virtual view are considered bad practice. But why is that?
The reason is that a join is an expensive operation. When you run it outside of a virtual view, you will have
to repeat that operation every single time the query is run.
A better approach is to create a virtual view once and for all and have all the subsequent queries
share the same virtual view. Let's follow the advice given in the error message:

```$ echo "create virtual view customer_orders as select * from customer, orders where c_custkey = o_custkey;" | sqlive --data /tmp/test.db
```

This command created the virtual view "customer_orders", which can now be used like any other table.
The differnce between a virtual view and a normal view is that the database will maintain that view up-to-date
at all times. In this case that means that any change in the customer or order table will be reflected in the virtual view "customer_orders".
This also implies that reading from a virtual view is very fast, because the data is already there.
Let's find the orders from customer number 889.

```$ echo "select * from customer_orders where c_custkey = 889;" | sqlive --data /tmp/test.db
889|Customer#000000889|pLvfd7drswfAcH8oh2seEct|13|23-625-369-6714|3635.3499999989999|FURNITURE|inal ideas. slowly pending frays are. fluff|931|889|F|155527.98000000001|1992-12-07|1-URGENT|Clerk#000000881|0|ss packages haggle furiously express, regular deposits. even, e
```

And that works for any query involving customers and orders. Instead of recomputing expensive joins every single time orders and customers are
involved, you can run those queries directly on the virtual view customer_orders.
To speed things up, we recommend you add indexes to your virtual views:

```$ echo "create index customer_orders_c_custkey ON customer_orders(c_custkey);" | sqlive --data /tmp/test.db
```

If you are unsure about your queries, you can ask SQLive to list the indexes that were used for a particular query through the option --show-used-indexes.
This option is particularly useful when trying to optimize your queries.

```$ echo "select * from customer_orders where c_custkey = 889;" | sqlive --data /tmp/test.db --show-used-indexes
USING INDEX: customer_orders_c_custkey
...
```

## Connections

Virtual views can be used to maintain a query up-to-date at all times, as we have just seen, but
they can also be used to get notified when changes occurs.

For example, let's create a query that tracks all the customer with a negative balance.

```$ echo "create virtual view negative_balance as select * from customer where c_acctbal < 0.0;" | sqlive --data /tmp/test.db
```

The creation of the virtual view does not trigger notifications. We need to "connect" to that view in order to receive them.

```$ sqlive --data /tmp/test.db --connect negative_balance --stream /tmp/negative_balance
6043
```

With this command we instructed SQLive to send all the changes relative to the virtual view "negative\_balance" to the file /tmp/negative\_balance.
In return, SQLive gave us the session number "6043", which will be useful to retrieve the status of that connection.

Let's have a look at the stream:

```$ tail /tmp/negative_balance
1       875|Customer#000000875|8pQ4YUYox0d|3|13-146-810-5423|-949.27999999899998|FURNITURE|ar theodolites snooze slyly. furiously express packages cajole blithely around the carefully r
1       880|Customer#000000880|ogwHmUUFa1QB69pAoYAAoB0rjbdsVpAQ552e5Q,|8|18-763-990-8618|-77.629999999000006|FURNITURE|regular requests. regular deposits ar
1       885|Customer#000000885|nNUbC73nPBCKLg0|5|15-874-471-4903|-959.94000000000005|HOUSEHOLD|sits impress regular deposits. slyly silent excuses grow
...
```

The format is pretty straight forward. It's a key/value format (separated by a tab) where the key is the number of repetitions of a row.
That number corresponds to the total number of rows with that value. So if a row was already present 23 times, and a transaction adds an additional instance of that row, that number would become 24.
However, in practice, the number of repetition is always going to be 0 or 1 (0 for removal).
Also note that for ephemeral streams (which will be introduced later), that number is always one.

You can check the status of every connection at all times with the option "--sessions".

```$ sqlive --sessions --data /tmp/test.db
6043    /negative_balance/      CONNECTED
```

We can see that our connection is live. You can decide to disconnect a sessions with the option --disconnect, but note that sessions will automatically disconnect in case of a problem.
The option --reconnect, restarts the session where it started to fail and sends all the data that was missed since the disconnection.

Let's see what happens when the data changes.

```$ echo "delete from customer where c_custkey = 11;" | sqlive --data /tmp/test.db
```

And see the effect in /tmp/negative_balance:

```$ tail  /tmp/negative_balance
...
<-------- EMPTY LINE
<-------- EMPTY LINE
 0     11|Customer#000000011|PkWS 3HlXqwTuzrKg633BEi|23|33-464-151-3439|-272.60000000000002|BUILDING|ckages. requests sleep slyly. quickly even pinto beans promise above the slyly regular pinto beans.
```

A new line appeared notifying us that the customer 11 has been removed.
If you paid attention, you can see that two empty lines where introduced before the notification.
Those lines are there to notify that the database finished a transaction (and is starting a new one). If you are ingesting the changes, you
can safely assume that the database was in a consistent state at that point.

## Diffing

Streaming changes is fine, but the problem is that the changes are "pushed" to the user.
Sometimes, we will need to operate the other way around: the user will want to "pull" changes,
by asking periodically what has changed since the last time around.

Fortunately, SQLive has the solution: the --diff option.
Let's create a new connection, this time without the associated --stream option.

```$ sqlive --data /tmp/test.db --connect negative_balance
6058
```

And use the session number to get a "diff":

```$ sqlive --diff 6058 --since 0 --data /tmp/test.db
Time: 22
0       11|Customer#000000011|PkWS 3HlXqwTuzrKg633BEi|23|33-464-151-3439|-272.60000000000002|BUILDING|ckages. requests sleep slyly. quickly even pinto beans promise above the slyly regular pinto beans.
1       33|Customer#000000033|qFSlMuLucBmx9xnn5ib2csWUweg D|17|27-375-391-1280|-78.560000000000002|AUTOMOBILE|s. slyly regular accounts are furiously. carefully pending requests
1       37|Customer#000000037|7EV4Pwh,3SboctTWt|8|18-385-235-7162|-917.75|FURNITURE|ilent packages are carefully among the deposits. furiousl
...
```

Note that we used --diff in conjuction with --since. The --since option takes a timestamp produced by the database.
The timestamp 0 corresponds to the beginning of times. So asking a diff since time 0 will get you all the data associated
with a session.
Now pay attention to the first line that was returned: it says, "Time: 22". This is the new timestamp that you will have to keep for the next time around.

Let's try to make modifications:

```$ echo "delete from customer where c_custkey = 33;" | sqlive --data /tmp/test.db
```

And ask for the diff since time 22:

```$ sqlive --diff 6058 --since 22 --data /tmp/test.db
Time: 25
0       33|Customer#000000033|qFSlMuLucBmx9xnn5ib2csWUweg D|17|27-375-391-1280|-78.560000000000002|AUTOMOBILE|s. slyly regular accounts are furiously. carefully pending requests
```

The output gives us the next timestamp (22) plus the diff (the removal of the user 33).
You can repeat that operation as often as you want, at the rate you want, which makes
it convenient to run use cases that are polling data periodically.

## --stream vs --diff

So when should you use a --stream? And when should you use a --diff?
You should use --stream if you need your changes to be live, and when you are confident that
the process that handles the changes will be able to keep up with the write rate of the database.

## Streaming

SQLive also supports ephemeral tables called streams. They work exactly like a normal
sql table, except that they do not persist on disk.

```$ echo "create stream customer_connect_log (clog_custkey INTEGER, clog_time INTEGER);" | sqlive --data /tmp/test.db
```

We just declared an ephemeral data stream called customer\_connect\_log.
We can now use that table to log every time a customer connects to the system.
The difference with a "normal" table, is that the data is ephemeral (it will not persist on disk).
So what's the point of a stream you may ask? It comes in handy when trying to receive alerts.
For example, imagine we wanted to receive and alert every time a customer with a negative balance connects
to our system.

Step 1, we join the log with the table of customers, it's better to keep that as a separate step,
to be able to reuse the view "customer\_log":

```$ echo "create virtual view customer_log as select * from customer_connect_log, customer where c_custkey = clog_custkey;" | sqlive --data /tmp/test.db
```

Step 2, we create a virtual view tracking connection of users with a negative balance:

```$ echo "create virtual view negative_bal_connection as select * from customer_log where c_acctbal < 0.0;" | sqlive --data /tmp/test.db
```

Finally, we connect to that view:

```$ sqlive --connect negative_bal_connection --stream /tmp/negative_bal_connection --data /tmp/test.db
7083
```

Let's see what happens when we add data to the stream (using --load-csv is faster than INSERT statements when
manipulating streams):

```$ for i in {1..10000}; do echo "$i, $i"; done | sqlive --data /tmp/test.db --load-csv customer_connect_log
```

And check the result in /tmp/negative\_bal\_connection:

```$ tail -f /tmp/negative_bal_connection
1       934|934|934|Customer#000000934|UMAFCPYfCxn LhawyoEYoU9GZC7TORCX|12|22-119-576-7222|-592.69000000000005|AUTOMOBILE|fluffily requests. carefully even ideas snooze above the accounts. blithely bold platelets cajole
...
```

As expected, we got notified every time a customer with a negative balance connected.
In general, SQLive will never spawn threads or fork processes behind your back, to make the
performance more predictable. However, you should feel free to add multiple processes to speedup the ingestion of
data, including when targetting the same stream (Because SQLive supports multiple writers/readers).
In this case, we could for example get 10 processes writing on the stream customer\_log at the same time:

```$ for j in {1..10}; do (for i in {1..10000}; do echo "$i, $i"; done | sqlive --data /tmp/test.db --load-csv customer_connect_log)& done; wait
```

If you replace the '&' with a ';', you will see a dramatic slow down in the ingestion rate of
the data.

On a laptop with more than 10 cores, the sequential time is 1.632s, while only 0.319s when
using 10 processes (so roughly 5X faster).

## Windows

As mentioned earlier, streams are ephemeral. So what happens when using aggregate functions on them?

```$ echo "select count(*) from customer_connect_log;" | sqlive --data /tmp/test.db
^
|
 ----- ERROR
Error: line 1, characters 0-0:
Cannot use a stream for aggregates, use a window instead
```

We get an error. The error invites us to use a "window". A window is exactly like a stream, except that
it will persist data for a certain time. For example, let's say we want to keep the data received in the last
hour.

```$ echo "create window 3600 customer_connect_window (cw_custkey INTEGER, cw_time INTEGER);" | sqlive --data /tmp/test.db
```

The number 3600 corresponds to the number of seconds we want to persist the data.

Sometimes, instead of using the system clock, you will want to use a timestamp that was passed directly in the data.
When that's the case, annotate the field that corresponds to a timestamp as such:

```$ echo "create window 3600 customer_connect_window (cw_custkey INTEGER, cw_time INTEGER TIMESTAMP);" | sqlive --data /tmp/test.db
```

## Streams vs Windows

You should always prefer streams to windows: they are faster and require less memory.
So only use windows when you have to use an aggregate function, typically for analytics.
