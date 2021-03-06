# MssqlexV3

[![Build Status](https://travis-ci.org/findmypast-oss/mssqlex_v3.svg?branch=master)](https://travis-ci.org/findmypast-oss/mssqlex_v3)
[![Coverage Status](https://coveralls.io/repos/github/findmypast-oss/mssqlex_v3/badge.svg)](https://coveralls.io/github/findmypast-oss/mssqlex_v3)
[![Inline docs](http://inch-ci.org/github/findmypast-oss/mssqlex_v3.svg?branch=master)](http://inch-ci.org/github/findmypast-oss/mssqlex_v3)
[![Ebert](https://ebertapp.io/github/findmypast-oss/mssqlex_v3.svg)](https://ebertapp.io/github/findmypast-oss/mssqlex_v3)
[![Hex.pm Version](https://img.shields.io/hexpm/v/mssqlex_v3.svg)](https://hex.pm/packages/mssqlex_v3)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/mssqlex_v3.svg)](https://hex.pm/packages/mssqlex_v3)
[![License](https://img.shields.io/hexpm/l/mssqlex_v3.svg)](https://github.com/findmypast-oss/mssqlex_v3/blob/master/LICENSE)

Adapter to Microsoft SQL Server. Using `DBConnection` and `ODBC`.

It connects to [Ecto](https://github.com/elixir-ecto/ecto) with [MssqlEcto](https://github.com/findmypast-oss/mssql_ecto).

## WARNING!

This library was forked([Mssqlex](https://github.com/findmypast-oss/mssqlex)) and expanded in a hurried way.
It's not finished. Tests are passing, but docs are in mess. Use it with caution!

## Installation

MssqlexV3 requires the [Erlang ODBC application](http://erlang.org/doc/man/odbc.html) to be installed.
This might require the installation of an additional package depending on how you have installed
Erlang (e.g. on Ubuntu `sudo apt-get install erlang-odbc`).

MssqlexV3 depends on Microsoft's ODBC Driver for SQL Server. You can find installation
instructions for [Linux](https://docs.microsoft.com/en-us/sql/connect/odbc/linux/installing-the-microsoft-odbc-driver-for-sql-server-on-linux)
or [other platforms](https://docs.microsoft.com/en-us/sql/connect/odbc/microsoft-odbc-driver-for-sql-server)
on the official site.

This package is availabe in Hex, the package can be installed
by adding `mssqlex_v3` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:mssqlex_v3, "~> 3.0.0"}]
end
```

## Testing

Tests require an instance of SQL Server to be running on `localhost` and a valid
UID and password to be set in the `MSSQL_UID` and `MSSQL_PWD` environment
variables, respectively.

You can create `.env` file and set all required environment variables
```bash
export MSSQL_UID=sa
export MSSQL_PWD='sa_5ecretpa$$'
```

The easiest way to get an instance running is to use the SQL Server Docker image:

```sh
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=$MSSQL_PWD' -p 1433:1433 -d microsoft/mssql-server-linux:2017-latest
```

### Testing info

Maintenance DB - `master`
