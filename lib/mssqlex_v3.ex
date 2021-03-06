defmodule MssqlexV3 do
  @moduledoc """
  Interface for interacting with MS SQL Server via an ODBC driver for Elixir.

  It implements `DBConnection` behaviour, using `:odbc` to connect to the
  system's ODBC driver. Requires MS SQL Server ODBC driver, see
  [README](readme.html) for installation instructions.
  """

  alias MssqlexV3.Query

  @type conn :: DBConnection.conn

  @doc """
  Connect to a MS SQL Server using ODBC.

  `opts` expects a keyword list with zero or more of:

    * `:odbc_driver` - The driver the adapter will use.
        * environment variable: `MSSQL_DVR`
        * default value: {ODBC Driver 17 for SQL Server}
    * `:hostname` - The server hostname.
        * environment variable: `MSSQL_HST`
        * default value: localhost
    * `:instance_name` - OPTIONAL. The name of the instance, if using named instances.
        * environment variable: `MSSQL_IN`
    * `:port` - OPTIONAL. The server port number.
        * environment variable: `MSSQL_PRT`
    * `:database` - The name of the database.
        * environment variable: `MSSQL_DB`
    * `:username` - Username.
        * environment variable: `MSSQL_UID`
    * `:password` - User's password.
        * environment variable: `MSSQL_PWD`
    * `:encrypt` - Specifies whether data should be encrypted before sending it over the network.
        * environment variable: `MSSQL_ENCRYPT`
    * `:trust_server_certificate` - When used with Encrypt, enables encryption using a self-signed server certificate.
        * environment variable: `MSSQL_TRUST_SERVER_CERT`

  `MssqlexV3` uses the `DBConnection` framework and supports all `DBConnection`
  options like `:idle`, `:after_connect` etc.
  See `DBConnection.start_link/2` for more information.

  ## Examples

      iex> {:ok, pid} = MssqlexV3.start_link(database: "mr_microsoft")
      {:ok, #PID<0.70.0>}
  """
  @spec start_link(Keyword.t()) :: {:ok, pid}
  def start_link(opts) do
    DBConnection.start_link(MssqlexV3.Protocol, opts)
  end

  @doc """
  Executes a query against an MS SQL Server with ODBC.

  `conn` expects a `MssqlexV3` process identifier.

  `statement` expects a SQL query string.

  `params` expects a list of values in one of the following formats:

    * Strings with only valid ASCII characters, which will be sent to the
      database as strings.
    * Other binaries, which will be converted to UTF16 Little Endian binaries
      (which is what SQL Server expects for its unicode fields).
    * `Decimal` structs, which will be encoded as strings so they can be
      sent to the database with arbitrary precision.
    * Integers, which will be sent as-is if under 10 digits or encoded
      as strings for larger numbers.
    * Floats, which will be encoded as strings.
    * Time as `{hour, minute, sec, usec}` tuples, which will be encoded as
      strings.
    * Dates as `{year, month, day}` tuples, which will be encoded as strings.
    * Datetime as `{{hour, minute, sec, usec}, {year, month, day}}` tuples which
      will be encoded as strings. Note that attempting to insert a value with
      usec > 0 into a 'datetime' or 'smalldatetime' column is an error since
      those column types don't have enough precision to store usec data.

  `opts` expects a keyword list with zero or more of:

    * `:preserve_encoding`: If `true`, doesn't convert returned binaries from
    UTF16LE to UTF8. Default: `false`.
    * `:mode` - set to `:savepoint` to use a savepoint to rollback to before the
    query on error, otherwise set to `:transaction` (default: `:transaction`);

  Result values will be encoded according to the following conversions:

    * char and varchar: strings.
    * nchar and nvarchar: strings unless `:preserve_encoding` is set to `true`
      in which case they will be returned as UTF16 Little Endian binaries.
    * int, smallint, tinyint, decimal and numeric when precision < 10 and
      scale = 0 (i.e. effectively integers): integers.
    * float, real, double precision, decimal and numeric when precision between
      10 and 15 and/or scale between 1 and 15: `Decimal` structs.
    * bigint, money, decimal and numeric when precision > 15: strings.
    * date: `{year, month, day}`
    * smalldatetime, datetime, dateime2: `{{YY, MM, DD}, {HH, MM, SS, 0}}` (note that fractional
      second data is lost due to limitations of the ODBC adapter. To preserve it
      you can convert these columns to varchar during selection.)
    * uniqueidentifier, time, binary, varbinary, rowversion: not currently
      supported due to adapter limitations. Select statements for columns
      of these types must convert them to supported types (e.g. varchar).
  """

  @spec query(conn, iodata, list, Keyword.t()) :: {:ok, MssqlexV3.Result.t()} | {:error, Exception.t()}
  def query(conn, statement, params, opts \\ []) do
    if name = Keyword.get(opts, :cache_statement) do
      query = %Query{name: name, cache: :statement, statement: IO.iodata_to_binary(statement)}

      case DBConnection.prepare_execute(conn, query, params, opts) do
        {:ok, _, result} ->
          {:ok, result}

        {:error, %MssqlexV3.Error{mssql: %{code: :feature_not_supported}}} = error->
          with %DBConnection{} <- conn,
               :error <- DBConnection.status(conn) do
            error
          else
            _ -> query_prepare_execute(conn, query, params, opts)
          end

        {:error, _} = error ->
          error
      end
    else
      query_prepare_execute(conn, %Query{name: "", statement: statement}, params, opts)
    end
  end

  @doc """
  Runs an (extended) query and returns the result or raises `MssqlexV3.Error` if
  there was an error. See `query/3`.
  """
  @spec query!(conn, iodata, list, Keyword.t()) :: MssqlexV3.Result.t()
  def query!(conn, statement, params, opts \\ []) do
    case query(conn, statement, params, opts) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc """
  Runs an (extended) prepared query.
  It returns the result as `{:ok, %MssqlexV3.Query{}, %MssqlexV3.Result{}}` or
  `{:error, %MssqlexV3.Error{}}` if there was an error. Parameters are given as
  part of the prepared query, `%MssqlexV3.Query{}`.
  See the README for information on how MssqlexV3 encodes and decodes Elixir
  values by default. See `MssqlexV3.Query` for the query data and
  `MssqlexV3.Result` for the result data.
  ## Options
    * `:queue` - Whether to wait for connection in a queue (default: `true`);
    * `:timeout` - Execute request timeout (default: `#{@timeout}`);
    * `:decode_mapper` - Fun to map each row in the result to a term after
    decoding, (default: `fn x -> x end`);
    * `:mode` - set to `:savepoint` to use a savepoint to rollback to before the
    execute on error, otherwise set to `:transaction` (default: `:transaction`);
  ## Examples
      query = MssqlexV3.prepare!(conn, "", "CREATE TABLE posts (id serial, title text)")
      MssqlexV3.execute(conn, query, [])
      query = MssqlexV3.prepare!(conn, "", "SELECT id FROM posts WHERE title like $1")
      MssqlexV3.execute(conn, query, ["%my%"])
  """
  @spec execute(conn, MssqlexV3.Query.t, list, Keyword.t) ::
    {:ok, MssqlexV3.Query.t, MssqlexV3.Result.t} | {:error, MssqlexV3.Error.t}
  def execute(conn, query, params, opts \\ []) do
    DBConnection.execute(conn, query, params, opts)
  end

  @doc """
  Runs an (extended) prepared query and returns the result or raises
  `MssqlexV3.Error` if there was an error. See `execute/4`.
  """
  @spec execute!(conn, MssqlexV3.Query.t, list, Keyword.t) :: MssqlexV3.Result.t
  def execute!(conn, query, params, opts \\ []) do
    DBConnection.execute!(conn, query, params, opts)
  end

  defp query_prepare_execute(conn, query, params, opts) do
    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @spec prepare_execute(conn, iodata, iodata, list, Keyword.t) ::
    {:ok, MssqlexV3.Query.t, MssqlexV3.Result.t} | {:error, MssqlexV3.Error.t}
  def prepare_execute(conn, name, statement, params, opts \\ []) do
    query = %Query{name: name, statement: statement}
    DBConnection.prepare_execute(conn, query, params, opts)
  end

  @doc """
  Prepares and runs a query and returns the result or raises
  `MssqlexV3.Error` if there was an error. See `prepare_execute/5`.
  """
  @spec prepare_execute!(conn, iodata, iodata, list, Keyword.t) ::
    {MssqlexV3.Query.t, MssqlexV3.Result.t}
  def prepare_execute!(conn, name, statement, params, opts \\ []) do
    query = %Query{name: name, statement: statement}
    DBConnection.prepare_execute!(conn, query, params, opts)
  end

  @doc """
  Returns a supervisor child specification for a DBConnection pool.
  """
  @spec child_spec(Keyword.t) :: Supervisor.Spec.spec
  def child_spec(opts) do
    opts = MssqlexV3.Utils.default_opts(opts)
    DBConnection.child_spec(MssqlexV3.Protocol, opts)
  end
end
